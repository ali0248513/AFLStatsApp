import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_service.dart';
import '../models/player_stats.dart';

class TeamStatsScreen extends StatefulWidget {
  final String matchId;
  final String teamA;
  final String teamB;
  final String matchName;

  const TeamStatsScreen({
    super.key,
    required this.matchId,
    required this.teamA,
    required this.teamB,
    required this.matchName,
  });

  @override
  State<TeamStatsScreen> createState() => _TeamStatsScreenState();
}

class _TeamStatsScreenState extends State<TeamStatsScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = true;
  List<PlayerStats> _playerStats = [];

  @override
  void initState() {
    super.initState();
    _loadTeamStats();
  }

  Future<void> _loadTeamStats() async {
    try {
      final stats = await _firebaseService.getPlayerStats(
        widget.matchId,
        widget.teamA,
      );

      final playerStats =
          stats.map((data) {
            final statsData = data['stats'] as Map<String, dynamic>;
            return PlayerStats(
              name: data['name'] ?? 'Unknown',
              number: data['number'] ?? '0',
              goals: statsData['goals'] ?? 0,
              behinds: statsData['behinds'] ?? 0,
              kicks: statsData['kicks'] ?? 0,
              handballs: statsData['handballs'] ?? 0,
              marks: statsData['marks'] ?? 0,
              tackles: statsData['tackles'] ?? 0,
            );
          }).toList();

      setState(() {
        _playerStats = playerStats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading team stats: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.teamA} Stats'),
        backgroundColor: Colors.red[900],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _playerStats.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.sports_kabaddi,
                      size: 80,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No player stats available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              )
              : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Player')),
                    DataColumn(label: Text('#')),
                    DataColumn(label: Text('Goals')),
                    DataColumn(label: Text('Behinds')),
                    DataColumn(label: Text('Kicks')),
                    DataColumn(label: Text('Handballs')),
                    DataColumn(label: Text('Marks')),
                    DataColumn(label: Text('Tackles')),
                  ],
                  rows:
                      _playerStats.map((stats) {
                        return DataRow(
                          cells: [
                            DataCell(Text(stats.name)),
                            DataCell(Text(stats.number)),
                            DataCell(Text(stats.goals.toString())),
                            DataCell(Text(stats.behinds.toString())),
                            DataCell(Text(stats.kicks.toString())),
                            DataCell(Text(stats.handballs.toString())),
                            DataCell(Text(stats.marks.toString())),
                            DataCell(Text(stats.tackles.toString())),
                          ],
                        );
                      }).toList(),
                ),
              ),
    );
  }
}
