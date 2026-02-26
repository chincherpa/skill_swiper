class Profile {
  final String id;
  final String name;
  final String? bio;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final int radiusKm;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Profile({
    required this.id,
    required this.name,
    this.bio,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.radiusKm = 10,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      name: json['name'] as String,
      bio: json['bio'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      radiusKm: (json['radius_km'] as int?) ?? 10,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'avatar_url': avatarUrl,
      'latitude': latitude,
      'longitude': longitude,
      'radius_km': radiusKm,
    };
  }

  Profile copyWith({
    String? name,
    String? bio,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    int? radiusKm,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusKm: radiusKm ?? this.radiusKm,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
