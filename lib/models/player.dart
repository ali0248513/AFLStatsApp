class Player {
  final String id;
  final String name;
  final String number;
  final String? imageBase64;
  final int goals;
  final int behinds;
  final int kicks;
  final int handballs;
  final int marks;
  final int tackles;

  Player({
    required this.id,
    required this.name,
    required this.number,
    this.imageBase64,
    this.goals = 0,
    this.behinds = 0,
    this.kicks = 0,
    this.handballs = 0,
    this.marks = 0,
    this.tackles = 0,
  });

  factory Player.fromMap(Map<String, dynamic> map, String docId) {
    final stats = map['stats'] as Map<String, dynamic>? ?? {};
    return Player(
      id: docId,
      name: map['name'] ?? 'Unknown',
      number: map['number']?.toString() ?? '0',
      imageBase64: map['imageBase64'],
      goals: stats['goals'] ?? 0,
      behinds: stats['behinds'] ?? 0,
      kicks: stats['kicks'] ?? 0,
      handballs: stats['handballs'] ?? 0,
      marks: stats['marks'] ?? 0,
      tackles: stats['tackles'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'number': number,
    'imageBase64': imageBase64,
    'stats': {
      'goals': goals,
      'behinds': behinds,
      'kicks': kicks,
      'handballs': handballs,
      'marks': marks,
      'tackles': tackles,
    },
  };
} 