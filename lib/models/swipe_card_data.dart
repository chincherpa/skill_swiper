import 'user_skill.dart';

class SwipeCardData {
  final String userId;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final double distanceKm;
  final List<UserSkill> skills;

  const SwipeCardData({
    required this.userId,
    required this.name,
    this.bio,
    this.avatarUrl,
    required this.distanceKm,
    required this.skills,
  });

  factory SwipeCardData.fromJson(Map<String, dynamic> json) {
    return SwipeCardData(
      userId: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      distanceKm: ((json['distance'] as num?) ?? 0).toDouble() / 1000,
      skills: (json['skills'] as List<dynamic>?)
              ?.map((s) => UserSkill.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
