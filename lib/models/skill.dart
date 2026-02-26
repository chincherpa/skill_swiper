class Skill {
  final String id;
  final String name;
  final String category;
  final DateTime createdAt;

  const Skill({
    required this.id,
    required this.name,
    required this.category,
    required this.createdAt,
  });

  factory Skill.fromJson(Map<String, dynamic> json) {
    return Skill(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
