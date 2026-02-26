import 'profile.dart';

class Match {
  final String id;
  final String userA;
  final String userB;
  final DateTime createdAt;
  final Profile? otherUser;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  const Match({
    required this.id,
    required this.userA,
    required this.userB,
    required this.createdAt,
    this.otherUser,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  factory Match.fromJson(Map<String, dynamic> json, {Profile? otherUser}) {
    return Match(
      id: json['id'] as String,
      userA: json['user_a'] as String,
      userB: json['user_b'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      otherUser: otherUser,
      lastMessage: json['last_message'] as String?,
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'] as String)
          : null,
      unreadCount: (json['unread_count'] as int?) ?? 0,
    );
  }
}
