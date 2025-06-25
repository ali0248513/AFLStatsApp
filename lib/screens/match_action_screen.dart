import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/player.dart';
import '../models/player_action.dart';
import '../services/firebase_service.dart';
import '../screens/match_summary_screen.dart';
import 'package:flutter/foundation.dart';

class MatchActionScreen extends StatefulWidget {
  final String matchId;
  final String teamA;
  final String teamB;
  final String matchName;
  final List<Player> teamAPlayers;
  final List<Player> teamBPlayers;

  const MatchActionScreen({
    super.key,
    required this.matchId,
    required this.teamA,
    required this.teamB,
    required this.matchName,
    required this.teamAPlayers,
    required this.teamBPlayers,
  });

  @override
  State<MatchActionScreen> createState() => _MatchActionScreenState();
}

class _MatchActionScreenState extends State<MatchActionScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  // Current match state
  bool _isMatchStarted = false;
  bool _isMatchEnded = false;
  int _currentQuarter = 1;
  DateTime? _matchStartTime;
  DateTime? _currentQuarterStartTime;

  // Match duration (in minutes)
  int _matchDurationMinutes = 20;
  final TextEditingController _durationController = TextEditingController(
    text: '20',
  );
  int _quarterDurationSeconds = 300; // default 5 min per quarter
  int _totalMatchSeconds = 20 * 60;
  int _elapsedSeconds = 0;
  bool _showEndMatchButton = false;

  // Selected team and player
  String _selectedTeam = '';
  Player? _selectedPlayer;

  // Last action tracking (for game logic)
  String? _lastActionType;
  String? _lastActionPlayerTeam;
  String? _lastActionPlayerId;

  // Track last action per player for rules enforcement
  final Map<String, String> _playerLastAction = {};

  // Score tracking
  int _teamAGoals = 0;
  int _teamABehinds = 0;
  int _teamBGoals = 0;
  int _teamBBehinds = 0;

  // Per-quarter score tracking
  Map<int, Map<String, int>> _teamAQuarterScores = {
    1: {'goals': 0, 'behinds': 0},
    2: {'goals': 0, 'behinds': 0},
    3: {'goals': 0, 'behinds': 0},
    4: {'goals': 0, 'behinds': 0},
  };
  Map<int, Map<String, int>> _teamBQuarterScores = {
    1: {'goals': 0, 'behinds': 0},
    2: {'goals': 0, 'behinds': 0},
    3: {'goals': 0, 'behinds': 0},
    4: {'goals': 0, 'behinds': 0},
  };

  // Timer for match time
  late Timer _matchTimer;
  String _elapsedTime = '00:00';

  // Stream subscriptions
  late StreamSubscription<DocumentSnapshot> _matchSubscription;
  late StreamSubscription<QuerySnapshot> _actionsSubscription;

  // Add state for quarter stats from Firestore
  List<Map<String, dynamic>> _quarterStats = [];

  @override
  void initState() {
    super.initState();
    _selectedTeam = widget.teamA;
    _setupMatchTimer();
    _setupStreams();
    _fetchQuarterStats();
  }

  @override
  void dispose() {
    _matchTimer.cancel();
    _matchSubscription.cancel();
    _actionsSubscription.cancel();
    _durationController.dispose();
    super.dispose();
  }

  void _setupStreams() {
    // Listen to match updates
    _matchSubscription = _firebaseService.matchStream(widget.matchId).listen((
      snapshot,
    ) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      setState(() {
        _isMatchStarted = data['isActive'] ?? false;
        _isMatchEnded = data['endTime'] != null;
      });
    });

    // Listen to player actions
    _actionsSubscription = _firebaseService
        .playerActionsStream(widget.matchId)
        .listen((snapshot) {
          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final action = change.doc.data() as Map<String, dynamic>;
              _updateScores(action);
            }
          }
        });
  }

  void _setupMatchTimer() {
    _matchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isMatchStarted && !_isMatchEnded) {
        setState(() {
          _elapsedSeconds++;
          final minutes = (_elapsedSeconds ~/ 60).toString().padLeft(2, '0');
          final seconds = (_elapsedSeconds % 60).toString().padLeft(2, '0');
          _elapsedTime = '$minutes:$seconds';

          // Calculate current quarter
          int quarter = (_elapsedSeconds ~/ _quarterDurationSeconds) + 1;
          if (quarter > 4) quarter = 4;
          _currentQuarter = quarter;

          // Auto end match after total duration
          if (_elapsedSeconds >= _totalMatchSeconds) {
            _isMatchEnded = true;
            _showEndMatchButton = true;
            _matchTimer.cancel();
          }
        });
      }
    });
  }

  void _updateScores(Map<String, dynamic> action) {
    final team = action['team'] as String;
    final type = action['type'] as String;

    setState(() {
      if (team == widget.teamA) {
        if (type == PlayerAction.goal) {
          _teamAGoals++;
          _teamAQuarterScores[_currentQuarter]!['goals'] =
              _teamAQuarterScores[_currentQuarter]!['goals']! + 1;
        }
        if (type == PlayerAction.behind) {
          _teamABehinds++;
          _teamAQuarterScores[_currentQuarter]!['behinds'] =
              _teamAQuarterScores[_currentQuarter]!['behinds']! + 1;
        }
      } else {
        if (type == PlayerAction.goal) {
          _teamBGoals++;
          _teamBQuarterScores[_currentQuarter]!['goals'] =
              _teamBQuarterScores[_currentQuarter]!['goals']! + 1;
        }
        if (type == PlayerAction.behind) {
          _teamBBehinds++;
          _teamBQuarterScores[_currentQuarter]!['behinds'] =
              _teamBQuarterScores[_currentQuarter]!['behinds']! + 1;
        }
      }
    });

    // Update current quarter stats
    _updateQuarterStats();
  }

  Future<void> _updateQuarterStats() async {
    try {
      final currentQuarterRef = _firebaseService.db
          .collection('matches')
          .doc(widget.matchId)
          .collection('quarters')
          .doc('quarter_$_currentQuarter');

      final quarterStats = {
        'quarter': _currentQuarter,
        'stats': {
          widget.teamA: {
            'goals': _teamAQuarterScores[_currentQuarter]!['goals'],
            'behinds': _teamAQuarterScores[_currentQuarter]!['behinds'],
          },
          widget.teamB: {
            'goals': _teamBQuarterScores[_currentQuarter]!['goals'],
            'behinds': _teamBQuarterScores[_currentQuarter]!['behinds'],
          },
        },
      };

      print('Updating quarter $_currentQuarter stats: $quarterStats');
      await currentQuarterRef.set(quarterStats);
      print('Quarter stats updated successfully');
    } catch (e) {
      print('Error updating quarter stats: $e');
    }
  }

  Future<void> _startMatch() async {
    try {
      print('Starting match: ${widget.matchId}');
      final now = DateTime.now();
      // Set durations
      _totalMatchSeconds = _matchDurationMinutes * 60;
      _quarterDurationSeconds = (_totalMatchSeconds / 4).ceil();
      _elapsedSeconds = 0;
      _showEndMatchButton = false;
      // Update match status to started
      await _firebaseService.updateMatchStatus(widget.matchId, true);
      // Initialize first quarter
      final quarterRef = _firebaseService.db
          .collection('matches')
          .doc(widget.matchId)
          .collection('quarters')
          .doc('quarter_1');
      await quarterRef.set({
        'quarter': 1,
        'startTime': now.millisecondsSinceEpoch,
        'endTime': null,
        'stats': {
          'goals': 0,
          'behinds': 0,
          widget.teamA: {'goals': 0, 'behinds': 0},
          widget.teamB: {'goals': 0, 'behinds': 0},
        },
      });
      setState(() {
        _isMatchStarted = true;
        _matchStartTime = now;
        _currentQuarterStartTime = now;
        _currentQuarter = 1;
        _teamAGoals = 0;
        _teamABehinds = 0;
        _teamBGoals = 0;
        _teamBBehinds = 0;
        _elapsedSeconds = 0;
        _showEndMatchButton = false;
      });
      print('Match started successfully');
      print('First quarter initialized');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Match started successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error starting match: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error starting match: $e')));
    }
  }

  Future<void> _endMatch() async {
    try {
      // Calculate final score from quarter stats in Firestore for consistency
      final quarterDocs =
          await _firebaseService.db
              .collection('matches')
              .doc(widget.matchId)
              .collection('quarters')
              .orderBy('quarter')
              .get();
      int teamAGoals = 0, teamABehinds = 0, teamBGoals = 0, teamBBehinds = 0;
      for (var doc in quarterDocs.docs) {
        final stats = doc['stats'] ?? {};
        final teamAStats = stats[widget.teamA] ?? {};
        final teamBStats = stats[widget.teamB] ?? {};
        teamAGoals += (teamAStats['goals'] as num?)?.toInt() ?? 0;
        teamABehinds += (teamAStats['behinds'] as num?)?.toInt() ?? 0;
        teamBGoals += (teamBStats['goals'] as num?)?.toInt() ?? 0;
        teamBBehinds += (teamBStats['behinds'] as num?)?.toInt() ?? 0;
      }
      final finalStats = {
        '${widget.teamA}_score': (teamAGoals * 6) + teamABehinds,
        '${widget.teamB}_score': (teamBGoals * 6) + teamBBehinds,
        'finalScore':
            '${(teamAGoals * 6) + teamABehinds} : ${(teamBGoals * 6) + teamBBehinds}',
      };

      await _firebaseService.endMatch(widget.matchId, finalStats);
      setState(() {
        _isMatchEnded = true;
      });
      await _fetchQuarterStats();
      if (!mounted) return;
      // Navigate to match summary screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => MatchSummaryScreen(
                matchId: widget.matchId,
                matchName: widget.matchName,
                teamA: widget.teamA,
                teamB: widget.teamB,
                finalScore:
                    '${(teamAGoals * 6) + teamABehinds} : ${(teamBGoals * 6) + teamBBehinds}',
              ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error ending match: $e')));
    }
  }

  Future<void> _recordAction(String actionType) async {
    if (_selectedPlayer == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a player')));
      return;
    }

    final playerId = _selectedPlayer!.id;
    final lastAction = _playerLastAction[playerId];
    // Enforce AFL rules for scoring actions
    if (actionType == PlayerAction.goal) {
      if (lastAction != PlayerAction.kick) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goal can only be recorded directly after a Kick.'),
          ),
        );
        return;
      }
    } else if (actionType == PlayerAction.behind) {
      if (lastAction != PlayerAction.kick &&
          lastAction != PlayerAction.handball) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Behind can only be recorded after a Kick or Handball.',
            ),
          ),
        );
        return;
      }
    }

    try {
      print('Recording action: $actionType for team: $_selectedTeam');
      // Record the action in Firebase first
      await _firebaseService.recordPlayerAction(
        matchId: widget.matchId,
        playerId: _selectedPlayer!.id,
        playerTeam: _selectedTeam,
        actionType: actionType,
        quarter: _currentQuarter,
        stats: {
          'elapsedTime': _elapsedSeconds,
          'playerName': _selectedPlayer!.name,
        },
      );

      // DO NOT update local scores or quarter stats here!
      // Only update last action for this player (for rules enforcement)
      setState(() {
        _lastActionType = actionType;
        _lastActionPlayerTeam = _selectedTeam;
        _lastActionPlayerId = _selectedPlayer!.id;
        _playerLastAction[playerId] = actionType;
      });
      await _fetchQuarterStats(); // Optionally refresh quarter stats
      // UI will update when Firestore stream triggers _updateScores
      print('Action recorded successfully');
      print('Quarter $_currentQuarter stats will update from Firestore stream');
    } catch (e) {
      print('Error recording action: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error recording action: $e')));
    }
  }

  Widget _buildScoreDisplay() {
    final teamAScore = (_teamAGoals * 6) + _teamABehinds;
    final teamBScore = (_teamBGoals * 6) + _teamBBehinds;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Quarter $_currentQuarter',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Time: $_elapsedTime', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
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
                    Text(
                      '$_teamAGoals.$_teamABehinds ($teamAScore)',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(width: 2, height: 50, color: Colors.grey),
                Column(
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
                    Text(
                      '$_teamBGoals.$_teamBBehinds ($teamBScore)',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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

  Widget _buildTeamSelector() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedTeam = widget.teamA;
                _selectedPlayer = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _selectedTeam == widget.teamA
                      ? Colors.red[900]
                      : Colors.grey[300],
              foregroundColor:
                  _selectedTeam == widget.teamA
                      ? Colors.white
                      : Colors.blue[900],
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            child: Text(widget.teamA),
          ),
        ),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedTeam = widget.teamB;
                _selectedPlayer = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _selectedTeam == widget.teamB
                      ? Colors.blue[900]
                      : Colors.grey[300],
              foregroundColor:
                  _selectedTeam == widget.teamB
                      ? Colors.white
                      : Colors.blue[900],
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
            child: Text(widget.teamB),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerSelector() {
    final players =
        _selectedTeam == widget.teamA
            ? widget.teamAPlayers
            : widget.teamBPlayers;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Player - $_selectedTeam',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: players.length,
                itemBuilder: (context, index) {
                  final player = players[index];
                  final isSelected = _selectedPlayer?.id == player.id;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedPlayer = player;
                      });
                    },
                    child: Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? Colors.blue.withOpacity(0.2)
                                : Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                        border:
                            isSelected
                                ? Border.all(color: Colors.blue, width: 2)
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '#${player.number}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            player.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    Widget grid = GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _buildActionButton(PlayerAction.kick, Icons.sports_soccer),
        _buildActionButton(PlayerAction.handball, Icons.sports_handball),
        _buildActionButton(PlayerAction.mark, Icons.catching_pokemon),
        _buildActionButton(PlayerAction.tackle, Icons.sports_kabaddi),
        _buildActionButton(PlayerAction.goal, Icons.sports_score),
        _buildActionButton(PlayerAction.behind, Icons.flag),
      ],
    );
    // On web/desktop or wide screens, constrain the grid width
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = kIsWeb || constraints.maxWidth > 700;
        if (isWide) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: grid,
            ),
          );
        } else {
          return grid;
        }
      },
    );
  }

  Widget _buildActionButton(String actionType, IconData icon) {
    final isEnabled =
        _selectedPlayer != null && _isMatchStarted && !_isMatchEnded;
    Color color;
    if (_selectedTeam == widget.teamA && isEnabled) {
      color = Colors.red[900]!;
    } else if (_selectedTeam == widget.teamB && isEnabled) {
      color = Colors.blue[900]!;
    } else {
      color = Colors.blueGrey;
    }
    return ElevatedButton(
      onPressed: isEnabled ? () => _recordAction(actionType) : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        foregroundColor: color,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            actionType,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // Add this getter to calculate the winner
  String get _winner {
    final teamAScore = (_teamAGoals * 6) + _teamABehinds;
    final teamBScore = (_teamBGoals * 6) + _teamBBehinds;
    if (teamAScore > teamBScore) return widget.teamA;
    if (teamBScore > teamAScore) return widget.teamB;
    return "Draw";
  }

  // Fetch quarter stats from Firestore
  Future<void> _fetchQuarterStats() async {
    final quartersSnapshot =
        await _firebaseService.db
            .collection('matches')
            .doc(widget.matchId)
            .collection('quarters')
            .orderBy('quarter')
            .get();
    setState(() {
      _quarterStats =
          quartersSnapshot.docs
              .map((doc) => doc.data() as Map<String, dynamic>)
              .toList();
    });
  }

  // Helper to calculate total goals, behinds, and points from Firestore stats
  Map<String, int> _getFirestoreTotals() {
    int teamAGoals = 0, teamABehinds = 0, teamBGoals = 0, teamBBehinds = 0;
    for (var quarter in _quarterStats) {
      final stats = quarter['stats'] as Map<String, dynamic>? ?? {};
      final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
      final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};
      teamAGoals += (teamAStats['goals'] as num?)?.toInt() ?? 0;
      teamABehinds += (teamAStats['behinds'] as num?)?.toInt() ?? 0;
      teamBGoals += (teamBStats['goals'] as num?)?.toInt() ?? 0;
      teamBBehinds += (teamBStats['behinds'] as num?)?.toInt() ?? 0;
    }
    return {
      'teamAGoals': teamAGoals,
      'teamABehinds': teamABehinds,
      'teamBGoals': teamBGoals,
      'teamBBehinds': teamBBehinds,
      'teamAScore': (teamAGoals * 6) + teamABehinds,
      'teamBScore': (teamBGoals * 6) + teamBBehinds,
    };
  }

  // Update summary card to use Firestore stats
  Widget _buildFirestoreScoreSummary() {
    final totals = _getFirestoreTotals();
    String winner;
    if (totals['teamAScore']! > totals['teamBScore']!) {
      winner = widget.teamA;
    } else if (totals['teamBScore']! > totals['teamAScore']!) {
      winner = widget.teamB;
    } else {
      winner = 'Draw';
    }
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Match Summary',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.teamA} vs ${widget.teamB}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Score (${totals['teamAGoals']}.${totals['teamABehinds']}) ${totals['teamAScore']} : (${totals['teamBGoals']}.${totals['teamBBehinds']}) ${totals['teamBScore']}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'Winner: $winner',
              style: TextStyle(
                fontSize: 16,
                color: winner == "Draw" ? Colors.orange : Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update quarter display to use Firestore stats for current quarter
  Widget _buildFirestoreQuarterDisplay() {
    final currentQuarter = _currentQuarter;
    final quarter =
        _quarterStats.length >= currentQuarter
            ? _quarterStats[currentQuarter - 1]
            : null;
    int teamAGoals = 0, teamABehinds = 0, teamBGoals = 0, teamBBehinds = 0;
    if (quarter != null) {
      final stats = quarter['stats'] as Map<String, dynamic>? ?? {};
      final teamAStats = stats[widget.teamA] as Map<String, dynamic>? ?? {};
      final teamBStats = stats[widget.teamB] as Map<String, dynamic>? ?? {};
      teamAGoals = (teamAStats['goals'] as num?)?.toInt() ?? 0;
      teamABehinds = (teamAStats['behinds'] as num?)?.toInt() ?? 0;
      teamBGoals = (teamBStats['goals'] as num?)?.toInt() ?? 0;
      teamBBehinds = (teamBStats['behinds'] as num?)?.toInt() ?? 0;
    }
    final teamAScore = (teamAGoals * 6) + teamABehinds;
    final teamBScore = (teamBGoals * 6) + teamBBehinds;
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Quarter $currentQuarter',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text('Time: $_elapsedTime', style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
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
                    Text(
                      '$teamAGoals.$teamABehinds ($teamAScore)',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Container(width: 2, height: 50, color: Colors.grey),
                Column(
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
                    Text(
                      '$teamBGoals.$teamBBehinds ($teamBScore)',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Match: ${widget.matchName}'),
        backgroundColor: Colors.red[900],
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            // If match hasn't started, delete it when going back
            if (!_isMatchStarted) {
              try {
                await _firebaseService.deleteMatch(widget.matchId);
              } catch (e) {
                print('Error cleaning up match: $e');
              }
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!_isMatchStarted)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Ready to start ${widget.matchName}?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Game Instructions Card
                      Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Instructions of the Game:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                '• Only a Goal scored directly after a Kick is valid.',
                              ),
                              Text(
                                '• Behind can follow either Kick or Handball.',
                              ),
                              Text(
                                '• Kicks, Handballs, Marks, and Tackles can be recorded anytime.',
                              ),
                              Text(
                                '• Scoring Actions (Goal or Behind) will only be recorded if game rules are followed.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Match duration input
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Match Duration: ',
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Minutes',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                  horizontal: 8,
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = int.tryParse(val);
                                if (parsed != null && parsed > 0) {
                                  setState(() {
                                    _matchDurationMinutes = parsed;
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('min', style: TextStyle(fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _startMatch,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Match'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          textStyle: const TextStyle(fontSize: 18),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFirestoreScoreSummary(),
                      _buildFirestoreQuarterDisplay(),
                      const SizedBox(height: 16),
                      _buildTeamSelector(),
                      const SizedBox(height: 16),
                      _buildPlayerSelector(),
                      const SizedBox(height: 16),
                      const Text(
                        'Record Action',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildActionButtons(),
                      const SizedBox(height: 24),
                      if (_showEndMatchButton)
                        ElevatedButton.icon(
                          onPressed: _endMatch,
                          icon: const Icon(Icons.flag),
                          label: const Text('End Match & View Summary'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
