import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/quarter_score.dart';
import '../services/firebase_service.dart';
import 'player_comparison_screen.dart';
import 'team_stats_screen.dart';
import 'package:flutter/foundation.dart';
import '../utils/share_helper.dart';

class MatchDetailScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String teamA;
  final String teamB;
  final String finalScore;

  const MatchDetailScreen({
    super.key,
    required this.matchId,
    required this.matchName,
    required this.teamA,
    required this.teamB,
    required this.finalScore,
  });

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _quarterScoresRaw = [];
  List<Map<String, dynamic>> _playerActions = [];
  String _winner = "Unknown";
  StreamSubscription<QuerySnapshot>? _quarterStatsSubscription;
  late String _teamAName = widget.teamA;
  late String _teamBName = widget.teamB;

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  @override
  void dispose() {
    _quarterStatsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMatchData() async {
    try {
      print('Loading match data for match: ${widget.matchId}');

      // Get match data
      final matchDoc =
          await _firebaseService.db
              .collection('matches')
              .doc(widget.matchId)
              .get();
      final matchData = matchDoc.data() ?? {};

      // Set up real-time listener for quarter stats
      _quarterStatsSubscription = _firebaseService.db
          .collection('matches')
          .doc(widget.matchId)
          .collection('quarters')
          .orderBy('quarter')
          .snapshots()
          .listen((snapshot) {
            final quarters =
                snapshot.docs.map((doc) {
                  final data = doc.data();
                  print('\nQuarter ${data['quarter']} raw data:');
                  print(data);

                  // Extract and log team stats
                  final stats = data['stats'] as Map<String, dynamic>? ?? {};
                  final teamAStats =
                      stats[widget.teamA] as Map<String, dynamic>? ?? {};
                  final teamBStats =
                      stats[widget.teamB] as Map<String, dynamic>? ?? {};

                  print('Team ${widget.teamA} stats for Q${data['quarter']}:');
                  print(
                    'Goals: ${teamAStats['goals']}, Behinds: ${teamAStats['behinds']}',
                  );
                  print('Team ${widget.teamB} stats for Q${data['quarter']}:');
                  print(
                    'Goals: ${teamBStats['goals']}, Behinds: ${teamBStats['behinds']}',
                  );

                  return {
                    'quarter': data['quarter'] as int? ?? 0,
                    'stats': stats,
                  };
                }).toList();

            if (mounted) {
              setState(() {
                _quarterScoresRaw = quarters;
              });
            }
          });

      // Get all player actions for this match
      final actionsSnapshot = await _firebaseService.getAllMatchActions(
        widget.matchId,
      );
      final actions =
          actionsSnapshot.map((data) {
            print('Loaded action: $data');
            // Fallback for player and team fields
            String player = data['playerName'] ?? data['player'] ?? '';
            String team = data['team'] ?? data['teamA'] ?? data['teamB'] ?? '';
            return {
              'player': player,
              'type': data['type'] ?? '',
              'team': team,
              'elapsedTime': data['elapsedTime'] ?? 0,
            };
          }).toList();

      if (mounted) {
        setState(() {
          _playerActions = actions;
          _winner = _calculateWinner(matchData, widget.teamA, widget.teamB);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading match data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading match data: $e')));
      }
    }
  }

  String _calculateWinner(
    Map<String, dynamic> matchData,
    String teamA,
    String teamB,
  ) {
    final teamAScore = matchData['${teamA}_score'] as int? ?? 0;
    final teamBScore = matchData['${teamB}_score'] as int? ?? 0;
    if (teamAScore > teamBScore) return teamA;
    if (teamBScore > teamAScore) return teamB;
    return "Draw";
  }

  Future<void> _shareMatchDetails() async {
    try {
      // Build CSV content
      StringBuffer csv = StringBuffer();
      csv.writeln('Match: ${widget.matchName}');
      csv.writeln('Teams: ${widget.teamA} vs ${widget.teamB}');
      // Calculate total scores
      int teamATotalGoals = 0;
      int teamATotalBehinds = 0;
      int teamBTotalGoals = 0;
      int teamBTotalBehinds = 0;
      for (var quarter in _quarterScoresRaw) {
        final stats = quarter['stats'] as Map<String, dynamic>? ?? {};
        final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
        final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};
        teamATotalGoals += teamAStats['goals'] as int? ?? 0;
        teamATotalBehinds += teamAStats['behinds'] as int? ?? 0;
        teamBTotalGoals += teamBStats['goals'] as int? ?? 0;
        teamBTotalBehinds += teamBStats['behinds'] as int? ?? 0;
      }
      final teamATotal = teamATotalGoals * 6 + teamATotalBehinds;
      final teamBTotal = teamBTotalGoals * 6 + teamBTotalBehinds;
      csv.writeln(
        'Final Score: (${teamATotalGoals}.${teamATotalBehinds}) $teamATotal : (${teamBTotalGoals}.${teamBTotalBehinds}) $teamBTotal',
      );
      csv.writeln(
        'Winner: ${teamATotal > teamBTotal
            ? widget.teamA
            : teamBTotal > teamATotal
            ? widget.teamB
            : "Draw"}',
      );
      csv.writeln();
      // Quarter scores
      csv.writeln(
        'Quarter,${widget.teamA} (goals.behinds),${widget.teamA} Points,${widget.teamB} (goals.behinds),${widget.teamB} Points',
      );
      int teamACumGoals = 0,
          teamACumBehinds = 0,
          teamBCumGoals = 0,
          teamBCumBehinds = 0;
      for (int i = 0; i < 4; i++) {
        int teamAGoals = 0, teamABehinds = 0, teamBGoals = 0, teamBBehinds = 0;
        if (i < _quarterScoresRaw.length) {
          final stats =
              _quarterScoresRaw[i]['stats'] as Map<String, dynamic>? ?? {};
          final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
          final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};
          teamAGoals = teamAStats['goals'] as int? ?? 0;
          teamABehinds = teamAStats['behinds'] as int? ?? 0;
          teamBGoals = teamBStats['goals'] as int? ?? 0;
          teamBBehinds = teamBStats['behinds'] as int? ?? 0;
        }
        teamACumGoals += teamAGoals;
        teamACumBehinds += teamABehinds;
        teamBCumGoals += teamBGoals;
        teamBCumBehinds += teamBBehinds;
        csv.writeln(
          'Q${i + 1},($teamAGoals.$teamABehinds),${teamAGoals * 6 + teamABehinds},($teamBGoals.$teamBBehinds),${teamBGoals * 6 + teamBBehinds}',
        );
      }
      csv.writeln(
        'Final,($teamACumGoals.$teamACumBehinds),${teamACumGoals * 6 + teamACumBehinds},($teamBCumGoals.$teamBCumBehinds),${teamBCumGoals * 6 + teamBCumBehinds}',
      );
      csv.writeln();
      // Player actions
      csv.writeln('Player,Action,Team,Elapsed Time (mm:ss)');
      for (final action in _playerActions) {
        csv.writeln(
          '${action['player']},${action['type']},${action['team']},${_formatElapsedTime(action['elapsedTime'])}',
        );
      }
      final csvString = csv.toString();
      final fileName = '${widget.matchName}_match.csv';
      await shareCsvFile(
        fileName,
        csvString,
        shareText: 'Match Summary: ${widget.matchName}',
        context: context,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing match data: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculate total scores for the summary card
    int teamATotalGoals = 0;
    int teamATotalBehinds = 0;
    int teamBTotalGoals = 0;
    int teamBTotalBehinds = 0;

    for (var quarter in _quarterScoresRaw) {
      final stats = quarter['stats'] as Map<String, dynamic>? ?? {};
      final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
      final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};

      teamATotalGoals += teamAStats['goals'] as int? ?? 0;
      teamATotalBehinds += teamAStats['behinds'] as int? ?? 0;
      teamBTotalGoals += teamBStats['goals'] as int? ?? 0;
      teamBTotalBehinds += teamBStats['behinds'] as int? ?? 0;
    }

    final teamATotal = teamATotalGoals * 6 + teamATotalBehinds;
    final teamBTotal = teamBTotalGoals * 6 + teamBTotalBehinds;

    Widget wrapWebCenter(Widget child) {
      if (kIsWeb) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: child,
          ),
        );
      } else {
        return child;
      }
    }

    Widget sectionTitle(String text) {
      if (kIsWeb) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
        );
      } else {
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        );
      }
    }

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        wrapWebCenter(
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.matchName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.teamA} vs ${widget.teamB}',
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score: ($teamATotalGoals.$teamATotalBehinds) $teamATotal : ($teamBTotalGoals.$teamBTotalBehinds) $teamBTotal',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Winner: ${teamATotal > teamBTotal
                        ? widget.teamA
                        : teamBTotal > teamATotal
                        ? widget.teamB
                        : "Draw"}',
                    style: TextStyle(
                      fontSize: 18,
                      color:
                          teamATotal == teamBTotal
                              ? Colors.orange
                              : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        sectionTitle('Players Stats'),
        wrapWebCenter(
          Card(
            elevation: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child:
                  _playerActions.isEmpty
                      ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('No player actions recorded'),
                      )
                      : SizedBox(
                        height: 250,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                columns: const [
                                  DataColumn(
                                    label: Text(
                                      'Player',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Action',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Team',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  DataColumn(
                                    label: Text(
                                      'Time',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                                rows:
                                    _playerActions
                                        .map(
                                          (action) => DataRow(
                                            cells: [
                                              DataCell(
                                                Text(action['player'] ?? ''),
                                              ),
                                              DataCell(
                                                Text(action['type'] ?? ''),
                                              ),
                                              DataCell(
                                                Text(action['team'] ?? ''),
                                              ),
                                              DataCell(
                                                Text(
                                                  _formatElapsedTime(
                                                    action['elapsedTime'],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ),
                        ),
                      ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        sectionTitle('Quarter Scores'),
        wrapWebCenter(
          Card(
            elevation: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: _buildQuarterScoresTable(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Row for Share and Player Comparison buttons
        wrapWebCenter(
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Flexible(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _shareMatchDetails,
                    icon: const Icon(Icons.share),
                    label: const Text(
                      'Share',
                      overflow: TextOverflow.visible,
                      softWrap: true,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => PlayerComparisonScreen(
                                matchId: widget.matchId,
                                teamA: widget.teamA,
                                teamB: widget.teamB,
                                matchName: widget.matchName,
                              ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.compare_arrows),
                    label: const Text('Player Comparison'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[900],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(240, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Centered Home button
        wrapWebCenter(
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  icon: const Icon(Icons.home),
                  label: const Text(
                    'Home',
                    overflow: TextOverflow.visible,
                    softWrap: true,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Details'),
        backgroundColor: Colors.red[900],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: content,
              ),
    );
  }

  String _formatElapsedTime(dynamic elapsed) {
    if (elapsed == null) return '';
    int seconds = 0;
    if (elapsed is int) {
      seconds = elapsed;
    } else if (elapsed is String) {
      seconds = int.tryParse(elapsed) ?? 0;
    }
    final mm = (seconds ~/ 60).toString().padLeft(2, '0');
    final ss = (seconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  Widget _buildQuarterScoresTable() {
    final quarters = _quarterScoresRaw;
    print('Building quarter stats with ${quarters.length} quarters');

    // Cumulative scores per team
    int teamACumGoals = 0;
    int teamACumBehinds = 0;
    int teamBCumGoals = 0;
    int teamBCumBehinds = 0;

    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: [
              DataColumn(label: Text(widget.teamA)),
              const DataColumn(label: Text('Quarter')),
              DataColumn(label: Text(widget.teamB)),
            ],
            rows: [
              ...List.generate(4, (index) {
                int teamAGoals = 0;
                int teamABehinds = 0;
                int teamBGoals = 0;
                int teamBBehinds = 0;

                if (index < quarters.length) {
                  final quarterData = quarters[index];
                  final stats =
                      quarterData['stats'] as Map<String, dynamic>? ?? {};
                  final teamAStats =
                      stats[widget.teamA] as Map<String, dynamic>? ?? {};
                  final teamBStats =
                      stats[widget.teamB] as Map<String, dynamic>? ?? {};

                  teamAGoals = teamAStats['goals'] as int? ?? 0;
                  teamABehinds = teamAStats['behinds'] as int? ?? 0;
                  teamBGoals = teamBStats['goals'] as int? ?? 0;
                  teamBBehinds = teamBStats['behinds'] as int? ?? 0;
                }

                teamACumGoals += teamAGoals;
                teamACumBehinds += teamABehinds;
                teamBCumGoals += teamBGoals;
                teamBCumBehinds += teamBBehinds;

                final teamATotal = teamACumGoals * 6 + teamACumBehinds;
                final teamBTotal = teamBCumGoals * 6 + teamBCumBehinds;

                return DataRow(
                  cells: [
                    DataCell(
                      Text(
                        '($teamAGoals.$teamABehinds) : ${teamAGoals * 6 + teamABehinds}',
                      ),
                    ),
                    DataCell(Text('Q${index + 1}')),
                    DataCell(
                      Text(
                        '($teamBGoals.$teamBBehinds) : ${teamBGoals * 6 + teamBBehinds}',
                      ),
                    ),
                  ],
                );
              }),
              // Final row
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      '($teamACumGoals.$teamACumBehinds) : ${teamACumGoals * 6 + teamACumBehinds}',
                    ),
                  ),
                  const DataCell(Text('Final')),
                  DataCell(
                    Text(
                      '($teamBCumGoals.$teamBCumBehinds) : ${teamBCumGoals * 6 + teamBCumBehinds}',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<pw.TableRow> _buildQuarterScoresPdfRows() {
    final quarters = _quarterScoresRaw;
    List<String> quarterLabels = ['Q1', 'Q2', 'Q3', 'Q4', 'Final'];
    List<pw.TableRow> rows = [];
    int teamAGoals = 0, teamABehinds = 0, teamBGoals = 0, teamBBehinds = 0;
    for (int i = 0; i < 4; i++) {
      String teamA = '(0.0) : 0', teamB = '(0.0) : 0';
      if (i < quarters.length) {
        final stats = quarters[i]['stats'] as Map<String, dynamic>? ?? {};
        final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
        final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};
        teamAGoals += teamAStats['goals'] as int? ?? 0;
        teamABehinds += teamAStats['behinds'] as int? ?? 0;
        teamBGoals += teamBStats['goals'] as int? ?? 0;
        teamBBehinds += teamBStats['behinds'] as int? ?? 0;
        teamA =
            '(${teamAGoals}.${teamABehinds}) : ${teamAGoals * 6 + teamABehinds}';
        teamB =
            '(${teamBGoals}.${teamBBehinds}) : ${teamBGoals * 6 + teamBBehinds}';
      }
      rows.add(
        pw.TableRow(
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(teamA),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(quarterLabels[i]),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(teamB),
            ),
          ],
        ),
      );
    }
    // Final row
    rows.add(
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              '(${teamAGoals}.${teamABehinds}) : ${teamAGoals * 6 + teamABehinds}',
            ),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text('Final'),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(5),
            child: pw.Text(
              '(${teamBGoals}.${teamBBehinds}) : ${teamBGoals * 6 + teamBBehinds}',
            ),
          ),
        ],
      ),
    );
    return rows;
  }
}
