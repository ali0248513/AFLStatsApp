class PlayerAction {
  final String id;
  final String playerId;
  final String playerName;
  final String type;
  final int timestamp;
  final int quarter;
  final String teamId;

  const PlayerAction({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.type,
    required this.timestamp,
    required this.quarter,
    required this.teamId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'playerId': playerId,
    'playerName': playerName,
    'type': type,
    'timestamp': timestamp,
    'quarter': quarter,
    'teamId': teamId,
  };

  factory PlayerAction.fromMap(Map<String, dynamic> map) => PlayerAction(
    id: map['id'] as String,
    playerId: map['playerId'] as String,
    playerName: map['playerName'] as String,
    type: map['type'] as String,
    timestamp: map['timestamp'] as int,
    quarter: map['quarter'] as int,
    teamId: map['teamId'] as String,
  );

  // Action types
  static const String kick = 'Kick';
  static const String handball = 'Handball';
  static const String mark = 'Mark';
  static const String tackle = 'Tackle';
  static const String goal = 'Goal';
  static const String behind = 'Behind';
} 