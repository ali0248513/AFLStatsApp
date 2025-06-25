class PlayerStats {
  final String name;
  final String number;
  final int goals;
  final int behinds;
  final int kicks;
  final int handballs;
  final int marks;
  final int tackles;
  final int fouls;

  const PlayerStats({
    required this.name,
    required this.number,
    this.goals = 0,
    this.behinds = 0,
    this.kicks = 0,
    this.handballs = 0,
    this.marks = 0,
    this.tackles = 0,
    this.fouls = 0,
  });

  int get disposals => kicks + handballs;
  int get totalScore => (goals * 6) + behinds;

  Map<String, dynamic> toMap() => {
    'name': name,
    'number': number,
    'goals': goals,
    'behinds': behinds,
    'marks': marks,
    'kicks': kicks,
    'handballs': handballs,
    'tackles': tackles,
    'fouls': fouls,
  };

  factory PlayerStats.fromMap(Map<String, dynamic> map) {
    return PlayerStats(
      name: map['name'] ?? 'Unknown',
      number: map['number']?.toString() ?? '0',
      goals: map['stats']?['goals'] ?? 0,
      behinds: map['stats']?['behinds'] ?? 0,
      kicks: map['stats']?['kicks'] ?? 0,
      handballs: map['stats']?['handballs'] ?? 0,
      marks: map['stats']?['marks'] ?? 0,
      tackles: map['stats']?['tackles'] ?? 0,
      fouls: map['stats']?['fouls'] ?? 0,
    );
  }

  PlayerStats copyWith({
    String? name,
    String? number,
    int? goals,
    int? behinds,
    int? kicks,
    int? handballs,
    int? marks,
    int? tackles,
    int? fouls,
  }) {
    return PlayerStats(
      name: name ?? this.name,
      number: number ?? this.number,
      goals: goals ?? this.goals,
      behinds: behinds ?? this.behinds,
      kicks: kicks ?? this.kicks,
      handballs: handballs ?? this.handballs,
      marks: marks ?? this.marks,
      tackles: tackles ?? this.tackles,
      fouls: fouls ?? this.fouls,
    );
  }
} 