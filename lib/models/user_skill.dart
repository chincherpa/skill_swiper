class UserSkill {
  final String id;
  final String userId;
  final String description;
  final bool isRemote;
  final DateTime createdAt;

  const UserSkill({
    required this.id,
    required this.userId,
    required this.description,
    this.isRemote = false,
    required this.createdAt,
  });

  factory UserSkill.fromJson(Map<String, dynamic> json) {
    return UserSkill(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      description: json['description'] as String,
      isRemote: json['is_remote'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'description': description,
      'is_remote': isRemote,
    };
  }
}
