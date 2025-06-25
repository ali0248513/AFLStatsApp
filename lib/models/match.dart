class Match {
  final String id;
  final String matchName;
  final String teamA;
  final String teamB;
  final String finalScore;
  final DateTime startTime;
  final DateTime? endTime;
  final bool isActive;

  const Match({
    required this.id,
    required this.matchName, 
    required this.teamA,
    required this.teamB,
    required this.finalScore,
    required this.startTime,
    this.endTime,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'matchName': matchName,
    'teamA': teamA,
    'teamB': teamB,
    'finalScore': finalScore,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime?.millisecondsSinceEpoch,
    'isActive': isActive,
  };

  factory Match.fromMap(Map<String, dynamic> map) => Match(
    id: map['id'] as String,
    matchName: map['matchName'] as String,
    teamA: map['teamA'] as String,
    teamB: map['teamB'] as String,
    finalScore: map['finalScore'] as String,
    startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
    endTime: map['endTime'] != null 
        ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int) 
        : null,
    isActive: map['isActive'] as bool? ?? true,
  );
} 