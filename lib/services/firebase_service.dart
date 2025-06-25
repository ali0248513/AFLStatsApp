import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/player.dart';
import '../models/player_action.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Public getter for db
  FirebaseFirestore get db => _db;

  // Match Operations
  Future<DocumentReference> createMatch({
    required String matchName,
    required String teamA,
    required String teamB,
    required List<Player> teamAPlayers,
    required List<Player> teamBPlayers,
  }) async {
    final matchRef = _db.collection('matches').doc();
    final batch = _db.batch();

    // Create main match document
    batch.set(matchRef, {
      'matchName': matchName,
      'teamA': teamA,
      'teamB': teamB,
      'startTime': DateTime.now().millisecondsSinceEpoch,
      'isActive': false,
      'finalScore': '0 : 0',
      '${teamA}_score': 0,
      '${teamB}_score': 0,
    });

    // Add team A players
    for (final player in teamAPlayers) {
      final playerRef = matchRef.collection('teamA').doc(player.id);
      batch.set(playerRef, {
        'name': player.name,
        'number': player.number,
        'imageBase64': player.imageBase64,
        'stats': {
          'goals': 0,
          'behinds': 0,
          'kicks': 0,
          'handballs': 0,
          'marks': 0,
          'tackles': 0,
        },
      });
    }

    // Add team B players
    for (final player in teamBPlayers) {
      final playerRef = matchRef.collection('teamB').doc(player.id);
      batch.set(playerRef, {
        'name': player.name,
        'number': player.number,
        'imageBase64': player.imageBase64,
        'stats': {
          'goals': 0,
          'behinds': 0,
          'kicks': 0,
          'handballs': 0,
          'marks': 0,
          'tackles': 0,
        },
      });
    }

    await batch.commit();
    return matchRef;
  }

  // Match Actions
  Future<void> startMatch(String matchId) async {
    final now = DateTime.now();
    await _db.collection('matches').doc(matchId).update({
      'isActive': true,
      'startTime': now.millisecondsSinceEpoch,
    });

    // Create first quarter
    await _db
        .collection('matches')
        .doc(matchId)
        .collection('quarters')
        .doc('quarter_1')
        .set({
          'quarter': 1,
          'startTime': now.millisecondsSinceEpoch,
          'endTime': null,
          'stats': {},
        });
  }

  Future<void> endQuarter(
    String matchId,
    int currentQuarter,
    String teamA,
    String teamB,
  ) async {
    final now = DateTime.now();
    final batch = _db.batch();

    // End current quarter
    batch.update(
      _db
          .collection('matches')
          .doc(matchId)
          .collection('quarters')
          .doc('quarter_$currentQuarter'),
      {'endTime': now.millisecondsSinceEpoch},
    );

    // Start next quarter if not last
    if (currentQuarter < 4) {
      batch.set(
        _db
            .collection('matches')
            .doc(matchId)
            .collection('quarters')
            .doc('quarter_${currentQuarter + 1}'),
        {
          'quarter': currentQuarter + 1,
          'startTime': now.millisecondsSinceEpoch,
          'endTime': null,
          'stats': {},
        },
      );
    }

    await batch.commit();
  }

  Future<void> endMatch(String matchId, Map<String, dynamic> finalStats) async {
    await _db.collection('matches').doc(matchId).update({
      'isActive': false,
      'endTime': DateTime.now().millisecondsSinceEpoch,
      ...finalStats,
    });
  }

  // Player Actions
  Future<void> recordPlayerAction({
    required String matchId,
    required String playerId,
    required String playerTeam,
    required String actionType,
    required int quarter,
    required Map<String, dynamic> stats,
  }) async {
    try {
      // First get the player document to ensure it exists
      final playerRef = _db
          .collection('matches')
          .doc(matchId)
          .collection(playerTeam)
          .doc(playerId);

      final playerDoc = await playerRef.get();
      if (!playerDoc.exists) {
        throw Exception('Player document not found');
      }

      final batch = _db.batch();
      final now = DateTime.now();

      // Record the action
      final actionRef =
          _db.collection('matches').doc(matchId).collection('actions').doc();

      batch.set(actionRef, {
        'playerId': playerId,
        'team': playerTeam,
        'type': actionType,
        'quarter': quarter,
        'timestamp': now.millisecondsSinceEpoch,
        ...stats,
      });

      // Map action type to stats field
      String statsField;
      switch (actionType.toLowerCase()) {
        case 'goal':
          statsField = 'goals';
          break;
        case 'behind':
          statsField = 'behinds';
          break;
        case 'kick':
          statsField = 'kicks';
          break;
        case 'handball':
          statsField = 'handballs';
          break;
        case 'mark':
          statsField = 'marks';
          break;
        case 'tackle':
          statsField = 'tackles';
          break;
        default:
          throw Exception('Unknown action type: $actionType');
      }

      // Get current stats
      final currentStats =
          playerDoc.data()?['stats'] as Map<String, dynamic>? ??
          {
            'goals': 0,
            'behinds': 0,
            'kicks': 0,
            'handballs': 0,
            'marks': 0,
            'tackles': 0,
          };

      // Update the specific stat
      currentStats[statsField] = (currentStats[statsField] ?? 0) + 1;

      // Update the entire stats object
      batch.update(playerRef, {'stats': currentStats});

      await batch.commit();
    } catch (e) {
      print('Error recording action: $e');
      rethrow;
    }
  }

  // Stats Retrieval
  Stream<DocumentSnapshot> matchStream(String matchId) {
    return _db.collection('matches').doc(matchId).snapshots();
  }

  Stream<QuerySnapshot> quarterStatsStream(String matchId) {
    return _db
        .collection('matches')
        .doc(matchId)
        .collection('quarters')
        .orderBy('quarter')
        .snapshots();
  }

  Stream<QuerySnapshot> playerActionsStream(String matchId) {
    return _db
        .collection('matches')
        .doc(matchId)
        .collection('actions')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<Map<String, dynamic>> getMatchStats(String matchId) async {
    final matchDoc = await _db.collection('matches').doc(matchId).get();
    final quartersSnapshot =
        await _db
            .collection('matches')
            .doc(matchId)
            .collection('quarters')
            .orderBy('quarter')
            .get();

    return {
      'match': matchDoc.data(),
      'quarters': quartersSnapshot.docs.map((doc) => doc.data()).toList(),
    };
  }

  Future<List<Map<String, dynamic>>> getPlayerStats(
    String matchId,
    String team,
  ) async {
    final playersSnapshot =
        await _db.collection('matches').doc(matchId).collection(team).get();

    return playersSnapshot.docs.map((doc) => doc.data()).toList();
  }

  // Match History
  Stream<QuerySnapshot> getMatchHistory() {
    return _db
        .collection('matches')
        .orderBy('startTime', descending: true)
        .snapshots();
  }

  // Team Comparison
  Future<Map<String, dynamic>> getTeamComparison(String matchId) async {
    final match = await _db.collection('matches').doc(matchId).get();
    final teamAStats = await getPlayerStats(matchId, 'teamA');
    final teamBStats = await getPlayerStats(matchId, 'teamB');

    return {
      'match': match.data(),
      'teamAStats': teamAStats,
      'teamBStats': teamBStats,
    };
  }

  Future<QuerySnapshot> getPlayers(String matchId, String teamName) async {
    return _db.collection('matches').doc(matchId).collection(teamName).get();
  }

  Future<QuerySnapshot> getPlayerActions(
    String matchId,
    String teamName,
    String playerId,
  ) async {
    return _db
        .collection('matches')
        .doc(matchId)
        .collection('actions')
        .where('playerId', isEqualTo: playerId)
        .where('team', isEqualTo: teamName)
        .get();
  }

  // Add missing methods
  Future<void> updateMatchStatus(String matchId, bool isActive) async {
    await _db.collection('matches').doc(matchId).update({'isActive': isActive});
  }

  Future<void> deleteMatch(String matchId) async {
    // Delete all subcollections first
    final batch = _db.batch();

    // Delete teamA players
    final teamASnapshot =
        await _db.collection('matches').doc(matchId).collection('teamA').get();
    for (var doc in teamASnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete teamB players
    final teamBSnapshot =
        await _db.collection('matches').doc(matchId).collection('teamB').get();
    for (var doc in teamBSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete actions
    final actionsSnapshot =
        await _db
            .collection('matches')
            .doc(matchId)
            .collection('actions')
            .get();
    for (var doc in actionsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete quarters
    final quartersSnapshot =
        await _db
            .collection('matches')
            .doc(matchId)
            .collection('quarters')
            .get();
    for (var doc in quartersSnapshot.docs) {
      batch.delete(doc.reference);
    }

    // Delete the match document
    batch.delete(_db.collection('matches').doc(matchId));

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getAllMatchActions(String matchId) async {
    final actionsSnapshot =
        await _db
            .collection('matches')
            .doc(matchId)
            .collection('actions')
            .orderBy('timestamp')
            .get();

    return actionsSnapshot.docs.map((doc) => doc.data()).toList();
  }
}
