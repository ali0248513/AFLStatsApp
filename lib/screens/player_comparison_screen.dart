import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player.dart';
import '../models/player_stats.dart';
import '../services/firebase_service.dart';
import 'package:fl_chart/fl_chart.dart';

class PlayerComparisonScreen extends StatefulWidget {
  final String matchId;
  final String teamA;
  final String teamB;
  final String matchName;

  const PlayerComparisonScreen({
    super.key,
    required this.matchId,
    required this.teamA,
    required this.teamB,
    required this.matchName,
  });

  @override
  State<PlayerComparisonScreen> createState() => _PlayerComparisonScreenState();
}

class _PlayerComparisonScreenState extends State<PlayerComparisonScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;

  List<Player> _teamAPlayers = [];
  List<Player> _teamBPlayers = [];

  Player? _selectedPlayerA;
  Player? _selectedPlayerB;

  PlayerStats? _statsA;
  PlayerStats? _statsB;

  @override
  void initState() {
    super.initState();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      // Load Team A players
      final teamASnapshot = await _firebaseService.getPlayers(
        widget.matchId,
        widget.teamA,
      );

      final playersA =
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

      // Load Team B players
      final teamBSnapshot = await _firebaseService.getPlayers(
        widget.matchId,
        widget.teamB,
      );

      final playersB =
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

      setState(() {
        _teamAPlayers = playersA;
        _teamBPlayers = playersB;

        if (playersA.isNotEmpty) {
          _selectedPlayerA = playersA.first;
        }

        if (playersB.isNotEmpty) {
          _selectedPlayerB = playersB.first;
        }

        _isLoading = false;
      });

      // Load stats for initially selected players
      if (_selectedPlayerA != null) {
        _loadPlayerStats(widget.teamA, _selectedPlayerA!);
      }

      if (_selectedPlayerB != null) {
        _loadPlayerStats(widget.teamB, _selectedPlayerB!);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading players: $e')));
      }
    }
  }

  Future<void> _loadPlayerStats(String team, Player player) async {
    try {
      final actionsSnapshot = await _firebaseService.getPlayerActions(
        widget.matchId,
        team,
        player.id,
      );

      final actionCounts = {
        'Goal': 0,
        'Behind': 0,
        'Mark': 0,
        'Tackle': 0,
        'Kick': 0,
        'Handball': 0,
        'Foul': 0,
      };

      for (final doc in actionsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final actionType = data['type'] as String?;
        if (actionType != null && actionCounts.containsKey(actionType)) {
          actionCounts[actionType] = (actionCounts[actionType] ?? 0) + 1;
        }
      }

      final stats = PlayerStats(
        name: player.name,
        number: player.number,
        goals: actionCounts['Goal'] ?? 0,
        behinds: actionCounts['Behind'] ?? 0,
        marks: actionCounts['Mark'] ?? 0,
        tackles: actionCounts['Tackle'] ?? 0,
        kicks: actionCounts['Kick'] ?? 0,
        handballs: actionCounts['Handball'] ?? 0,
        fouls: actionCounts['Foul'] ?? 0,
      );

      setState(() {
        if (team == widget.teamA) {
          _statsA = stats;
        } else {
          _statsB = stats;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading player stats: $e')),
        );
      }
    }
  }

  List<BarChartGroupData> _getBarGroups() {
    if (_statsA == null || _statsB == null) return [];

    final stats = [
      ['Goals', _statsA!.goals, _statsB!.goals],
      ['Behinds', _statsA!.behinds, _statsB!.behinds],
      ['Kicks', _statsA!.kicks, _statsB!.kicks],
      ['Handballs', _statsA!.handballs, _statsB!.handballs],
      ['Marks', _statsA!.marks, _statsB!.marks],
      ['Tackles', _statsA!.tackles, _statsB!.tackles],
    ];

    return List.generate(stats.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (stats[i][1] as int).toDouble(),
            color: Colors.blue,
            width: 16,
          ),
          BarChartRodData(
            toY: (stats[i][2] as int).toDouble(),
            color: Colors.red,
            width: 16,
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Player Comparison'),
        backgroundColor: Colors.red[900],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Match: ${widget.matchName}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                widget.teamA,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<Player>(
                                value: _selectedPlayerA,
                                isExpanded: true,
                                hint: const Text('Select Player'),
                                onChanged: (Player? player) {
                                  if (player != null) {
                                    setState(() {
                                      _selectedPlayerA = player;
                                    });
                                    _loadPlayerStats(widget.teamA, player);
                                  }
                                },
                                items:
                                    _teamAPlayers.map((Player player) {
                                      return DropdownMenuItem<Player>(
                                        value: player,
                                        child: Text(
                                          '${player.name} (#${player.number})',
                                        ),
                                      );
                                    }).toList(),
                              ),
                              if (_selectedPlayerA?.imageBase64 != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(
                                          _selectedPlayerA!.imageBase64!,
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                widget.teamB,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[900],
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButton<Player>(
                                value: _selectedPlayerB,
                                isExpanded: true,
                                hint: const Text('Select Player'),
                                onChanged: (Player? player) {
                                  if (player != null) {
                                    setState(() {
                                      _selectedPlayerB = player;
                                    });
                                    _loadPlayerStats(widget.teamB, player);
                                  }
                                },
                                items:
                                    _teamBPlayers.map((Player player) {
                                      return DropdownMenuItem<Player>(
                                        value: player,
                                        child: Text(
                                          '${player.name} (#${player.number})',
                                        ),
                                      );
                                    }).toList(),
                              ),
                              if (_selectedPlayerB?.imageBase64 != null)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    image: DecorationImage(
                                      image: MemoryImage(
                                        base64Decode(
                                          _selectedPlayerB!.imageBase64!,
                                        ),
                                      ),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const SizedBox(height: 16),

                    if (_statsA != null && _statsB != null) ...[
                      const Text(
                        'Player Statistics Comparison',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        height: 250,
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: 10,
                            barGroups: _getBarGroups(),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const titles = [
                                      'G',
                                      'B',
                                      'K',
                                      'H',
                                      'M',
                                      'T',
                                    ];
                                    return Text(titles[value.toInt()]);
                                  },
                                  reservedSize: 30,
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: false),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 16, height: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Text(_selectedPlayerA!.name),
                          const SizedBox(width: 32),
                          Container(width: 16, height: 16, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(_selectedPlayerB!.name),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
    );
  }
}
