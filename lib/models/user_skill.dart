class UserSkill {
  final String id;
  final String userId;
  final String skillId;
  final String description;
  final String? skillName;
  final String? skillCategory;
  final DateTime createdAt;

  const UserSkill({
    required this.id,
    required this.userId,
    required this.skillId,
    required this.description,
    this.skillName,
    this.skillCategory,
    required this.createdAt,
  });

  factory UserSkill.fromJson(Map<String, dynamic> json) {
    final skills = json['skills'] as Map<String, dynamic>?;
    return UserSkill(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      skillId: json['skill_id'] as String,
      description: json['description'] as String,
      skillName: skills?['name'] as String? ?? json['skill_name'] as String?,
      skillCategory:
          skills?['category'] as String? ?? json['skill_category'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'skill_id': skillId,
      'description': description,
    };
  }
}
