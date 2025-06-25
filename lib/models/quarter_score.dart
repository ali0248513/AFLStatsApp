class QuarterScore {
  final int quarter;
  final int teamAGoals;
  final int teamABehinds;
  final int teamBGoals;
  final int teamBBehinds;

  const QuarterScore({
    required this.quarter,
    this.teamAGoals = 0,
    this.teamABehinds = 0,
    this.teamBGoals = 0,
    this.teamBBehinds = 0,
  });

  int get teamAScore => (teamAGoals * 6) + teamABehinds;
  int get teamBScore => (teamBGoals * 6) + teamBBehinds;

  String get teamAFormatted => "$teamAGoals.$teamABehinds ($teamAScore)";
  String get teamBFormatted => "$teamBGoals.$teamBBehinds ($teamBScore)";

  Map<String, dynamic> toMap() => {
    'quarter': quarter,
    'teamAGoals': teamAGoals,
    'teamABehinds': teamABehinds,
    'teamBGoals': teamBGoals,
    'teamBBehinds': teamBBehinds,
  };

  factory QuarterScore.fromMap(Map<String, dynamic> map, String teamA, String teamB) {
    return QuarterScore(
      quarter: map['quarter'] as int? ?? 1,
      teamAGoals: map['${teamA}_goals'] as int? ?? 0,
      teamABehinds: map['${teamA}_behinds'] as int? ?? 0,
      teamBGoals: map['${teamB}_goals'] as int? ?? 0,
      teamBBehinds: map['${teamB}_behinds'] as int? ?? 0,
    );
  }

  QuarterScore copyWith({
    int? quarter,
    int? teamAGoals,
    int? teamABehinds,
    int? teamBGoals,
    int? teamBBehinds,
  }) {
    return QuarterScore(
      quarter: quarter ?? this.quarter,
      teamAGoals: teamAGoals ?? this.teamAGoals,
      teamABehinds: teamABehinds ?? this.teamABehinds,
      teamBGoals: teamBGoals ?? this.teamBGoals,
      teamBBehinds: teamBBehinds ?? this.teamBBehinds,
    );
  }
} 