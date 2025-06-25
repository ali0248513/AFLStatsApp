import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/match.dart';
import '../services/firebase_service.dart';
import 'match_detail_screen.dart';

class MatchHistoryScreen extends StatefulWidget {
  const MatchHistoryScreen({super.key});

  @override
  State<MatchHistoryScreen> createState() => _MatchHistoryScreenState();
}

class _MatchHistoryScreenState extends State<MatchHistoryScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final List<Match> _matches = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  void _loadMatches() {
    _firebaseService.getMatchHistory().listen(
      (snapshot) {
        setState(() {
          _matches.clear();
          for (final doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final match = Match(
              id: doc.id,
              matchName: data['matchName'] ?? 'Unknown Match',
              teamA: data['teamA'] ?? 'Team A',
              teamB: data['teamB'] ?? 'Team B',
              finalScore: data['finalScore'] ?? '0 : 0',
              startTime: data['startTime'] is Timestamp 
                ? (data['startTime'] as Timestamp).toDate()
                : DateTime.fromMillisecondsSinceEpoch(data['startTime'] as int),
              endTime: data['endTime'] != null
                ? (data['endTime'] is Timestamp 
                    ? (data['endTime'] as Timestamp).toDate()
                    : DateTime.fromMillisecondsSinceEpoch(data['endTime'] as int))
                : null,
              isActive: data['isActive'] ?? false,
            );
            _matches.add(match);
          }
          _isLoading = false;
        });
      },
      onError: (error) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading matches: $error')),
        );
      }
    );
  }

  // Helper to get calculated score for a match
  Future<String> _getCalculatedScore(String matchId, String teamA, String teamB) async {
    final quartersSnapshot = await FirebaseFirestore.instance
        .collection('matches')
        .doc(matchId)
        .collection('quarters')
        .orderBy('quarter')
        .get();
    int teamAGoals = 0, teamABehinds = 0, teamBGoals = 0, teamBBehinds = 0;
    for (var doc in quartersSnapshot.docs) {
      final stats = doc['stats'] ?? {};
      final teamAStats = stats[teamA] ?? {};
      final teamBStats = stats[teamB] ?? {};
      teamAGoals += (teamAStats['goals'] as num?)?.toInt() ?? 0;
      teamABehinds += (teamAStats['behinds'] as num?)?.toInt() ?? 0;
      teamBGoals += (teamBStats['goals'] as num?)?.toInt() ?? 0;
      teamBBehinds += (teamBStats['behinds'] as num?)?.toInt() ?? 0;
    }
    final teamAScore = teamAGoals * 6 + teamABehinds;
    final teamBScore = teamBGoals * 6 + teamBBehinds;
    return '($teamAGoals.$teamABehinds) $teamAScore : ($teamBGoals.$teamBBehinds) $teamBScore';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Match History'),
        backgroundColor: Colors.red[900],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _matches.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No match history yet',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text('Create a new match to get started'),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _matches.length,
                  itemBuilder: (context, index) {
                    final match = _matches[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              match.matchName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${match.teamA} vs ${match.teamB}',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Score: ',
                            ),
                            FutureBuilder<String>(
                              future: _getCalculatedScore(match.id, match.teamA, match.teamB),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Text('Calculating...');
                                }
                                if (snapshot.hasError) {
                                  return const Text('Error loading score');
                                }
                                return Text('Score: ${snapshot.data}', style: const TextStyle(fontSize: 16));
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MatchDetailScreen(
                                          matchId: match.id,
                                          matchName: match.matchName,
                                          teamA: match.teamA,
                                          teamB: match.teamB,
                                          finalScore: match.finalScore,
                                        ),
                                      ),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue[900],
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('View Details'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pop(context);
        },
        backgroundColor: Colors.red[900],
        child: const Icon(Icons.home),
      ),
    );
  }
} 