import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/player.dart';
import '../services/firebase_service.dart';
import 'match_history_screen.dart';
import 'package:flutter/foundation.dart';
import '../utils/share_helper.dart';

class MatchSummaryScreen extends StatefulWidget {
  final String matchId;
  final String matchName;
  final String teamA;
  final String teamB;
  final String finalScore;

  const MatchSummaryScreen({
    super.key,
    required this.matchId,
    required this.matchName,
    required this.teamA,
    required this.teamB,
    required this.finalScore,
  });

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  List<Player> _teamAPlayers = [];
  List<Player> _teamBPlayers = [];
  Player? _selectedPlayer;
  Map<String, dynamic> _quarterStats = {};
  List<Map<String, dynamic>> _playerActions = [];

  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  Future<void> _loadMatchData() async {
    try {
      print('Loading match data for match: ${widget.matchId}');

      // Load players and their stats
      final teamASnapshot = await _firebaseService.getPlayers(
        widget.matchId,
        widget.teamA,
      );
      final teamBSnapshot = await _firebaseService.getPlayers(
        widget.matchId,
        widget.teamB,
      );

      // Load quarter stats
      print('\n=== Loading Quarter Stats ===');
      final quarterDocs =
          await _firebaseService.db
              .collection('matches')
              .doc(widget.matchId)
              .collection('quarters')
              .orderBy('quarter')
              .get();

      print('Found ${quarterDocs.docs.length} quarters');

      final quarters =
          quarterDocs.docs.map((doc) {
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

            return {'quarter': data['quarter'] as int? ?? 0, 'stats': stats};
          }).toList();

      print('\nProcessed quarter data:');
      quarters.forEach((q) => print(q));

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

      setState(() {
        _teamAPlayers =
            teamASnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final stats = data['stats'] as Map<String, dynamic>? ?? {};
              return Player(
                id: doc.id,
                name: data['name'] as String? ?? 'Unknown',
                number: (data['number'] ?? '0').toString(),
                imageBase64: data['imageBase64'] as String?,
                goals: stats['goals'] as int? ?? 0,
                behinds: stats['behinds'] as int? ?? 0,
                kicks: stats['kicks'] as int? ?? 0,
                handballs: stats['handballs'] as int? ?? 0,
                marks: stats['marks'] as int? ?? 0,
                tackles: stats['tackles'] as int? ?? 0,
              );
            }).toList();

        _teamBPlayers =
            teamBSnapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final stats = data['stats'] as Map<String, dynamic>? ?? {};
              return Player(
                id: doc.id,
                name: data['name'] as String? ?? 'Unknown',
                number: (data['number'] ?? '0').toString(),
                imageBase64: data['imageBase64'] as String?,
                goals: stats['goals'] as int? ?? 0,
                behinds: stats['behinds'] as int? ?? 0,
                kicks: stats['kicks'] as int? ?? 0,
                handballs: stats['handballs'] as int? ?? 0,
                marks: stats['marks'] as int? ?? 0,
                tackles: stats['tackles'] as int? ?? 0,
              );
            }).toList();

        _quarterStats = {'quarters': quarters};
        _playerActions = actions;
        _isLoading = false;
      });

      print('\nTeam A Players with stats:');
      _teamAPlayers.forEach(
        (p) => print('${p.name}: Goals=${p.goals}, Behinds=${p.behinds}'),
      );
      print('\nTeam B Players with stats:');
      _teamBPlayers.forEach(
        (p) => print('${p.name}: Goals=${p.goals}, Behinds=${p.behinds}'),
      );
    } catch (e) {
      print('Error loading match data: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading match data: $e')));
    }
  }

  Future<void> _shareMatchData() async {
    try {
      // Create CSV content
      String csv = 'Type,Player,Team,Timestamp\n';
      for (final action in _playerActions) {
        csv +=
            '${action['Type']},${action['Player']},${action['Team']},${action['Timestamp']}\n';
      }
      final fileName = '${widget.matchName}_actions.csv';
      await shareCsvFile(
        fileName,
        csv,
        shareText: 'Match Summary: ${widget.matchName}',
        context: context,
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sharing match data: $e')));
    }
  }

  Widget _buildQuarterScores() {
    final quarters = _quarterStats['quarters'] as List<dynamic>? ?? [];
    print('Building quarter scores with ${quarters.length} quarters');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quarter Scores',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Quarter'),
                    ),
                    Padding(padding: EdgeInsets.all(8.0), child: Text('Goals')),
                    Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Behinds'),
                    ),
                  ],
                ),
                ...List.generate(4, (index) {
                  int teamAGoals = 0;
                  int teamABehinds = 0;
                  int teamBGoals = 0;
                  int teamBBehinds = 0;
                  if (index < quarters.length) {
                    final quarterData = quarters[index] as Map<String, dynamic>;
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
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Q${index + 1}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${teamAGoals + teamBGoals}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('${teamABehinds + teamBBehinds}'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuarterStats() {
    final quarters = _quarterStats['quarters'] as List<dynamic>? ?? [];
    print('Building quarter stats with ${quarters.length} quarters');
    // Cumulative per team
    int teamACumGoals = 0;
    int teamACumBehinds = 0;
    int teamBCumGoals = 0;
    int teamBCumBehinds = 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quarter Stats',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(widget.teamA),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Quarter'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(widget.teamB),
                    ),
                  ],
                ),
                ...List.generate(4, (index) {
                  int teamAGoals = 0;
                  int teamABehinds = 0;
                  int teamBGoals = 0;
                  int teamBBehinds = 0;
                  if (index < quarters.length) {
                    final quarterData = quarters[index] as Map<String, dynamic>;
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
                  return TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '($teamAGoals.$teamABehinds) : ${teamAGoals * 6 + teamABehinds}',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text('Q${index + 1}'),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '($teamBGoals.$teamBBehinds) : ${teamBGoals * 6 + teamBBehinds}',
                        ),
                      ),
                    ],
                  );
                }),
                // Final row
                TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '($teamACumGoals.$teamACumBehinds) : ${teamACumGoals * 6 + teamACumBehinds}',
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('Final'),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        '($teamBCumGoals.$teamBCumBehinds) : ${teamBCumGoals * 6 + teamBCumBehinds}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Select a Player:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<Player>(
                    value: _selectedPlayer,
                    isExpanded: true,
                    hint: const Text('Select Player'),
                    items:
                        [..._teamAPlayers, ..._teamBPlayers].map((player) {
                          return DropdownMenuItem<Player>(
                            value: player,
                            child: Text('${player.name} (#${player.number})'),
                          );
                        }).toList(),
                    onChanged: (Player? player) {
                      setState(() {
                        _selectedPlayer = player;
                      });
                    },
                  ),
                ),
              ],
            ),
            if (_selectedPlayer != null) ...[
              const SizedBox(height: 16),
              Text('Goals: ${_selectedPlayer!.goals}'),
              Text('Score Behind: ${_selectedPlayer!.behinds}'),
              Text('Marks: ${_selectedPlayer!.marks}'),
              Text('Tackles: ${_selectedPlayer!.tackles}'),
              Text('Kicks: ${_selectedPlayer!.kicks}'),
              Text('Handballs: ${_selectedPlayer!.handballs}'),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quarters = _quarterStats['quarters'] as List<dynamic>? ?? [];
    int teamACumGoals = 0;
    int teamACumBehinds = 0;
    int teamBCumGoals = 0;
    int teamBCumBehinds = 0;
    for (var quarterData in quarters) {
      final stats = quarterData['stats'] as Map<String, dynamic>? ?? {};
      final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
      final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};
      teamACumGoals += teamAStats['goals'] as int? ?? 0;
      teamACumBehinds += teamAStats['behinds'] as int? ?? 0;
      teamBCumGoals += teamBStats['goals'] as int? ?? 0;
      teamBCumBehinds += teamBStats['behinds'] as int? ?? 0;
    }
    final teamATotal = teamACumGoals * 6 + teamACumBehinds;
    final teamBTotal = teamBCumGoals * 6 + teamBCumBehinds;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Summary'),
        backgroundColor: Colors.red[900],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            Text(
                              '${widget.teamA} vs ${widget.teamB}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Score: ($teamACumGoals.$teamACumBehinds) $teamATotal : ($teamBCumGoals.$teamBCumBehinds) $teamBTotal',
                              style: const TextStyle(fontSize: 18),
                            ),
                            Text(
                              'Winner: ${teamACumGoals * 6 + teamACumBehinds > teamBCumGoals * 6 + teamBCumBehinds
                                  ? widget.teamA
                                  : teamBCumGoals * 6 + teamBCumBehinds > teamACumGoals * 6 + teamACumBehinds
                                  ? widget.teamB
                                  : "Draw"}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildQuarterScores(),
                    const SizedBox(height: 16),
                    _buildQuarterStats(),
                    const SizedBox(height: 16),
                    _buildPlayerStats(),
                    const SizedBox(height: 24),
                    // Centered Share button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _shareMatchData,
                        icon: const Icon(Icons.share, color: Colors.white),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(color: Colors.white),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst);
                          },
                          icon: const Icon(Icons.home, color: Colors.white),
                          label: const Text('Home'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => const MatchHistoryScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, color: Colors.white),
                          label: const Text('View History'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            textStyle: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
    );
  }
}
