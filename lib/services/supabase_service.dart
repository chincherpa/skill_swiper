import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/match.dart';
import '../models/message.dart';
import '../models/profile.dart';
import '../models/swipe_card_data.dart';
import '../models/user_skill.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  String? get currentUserId => _client.auth.currentUser?.id;

  // ── Auth ──────────────────────────────────────────────

  /// Returns `true` if the session is immediately active (no email confirmation needed).
  Future<bool> signUp({required String email, required String password}) async {
    final response = await _client.auth.signUp(email: email, password: password);
    return response.session != null;
  }

  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ── Profile ───────────────────────────────────────────

  Future<Profile?> getProfile(String userId) async {
    final data =
        await _client.from('profiles').select().eq('id', userId).maybeSingle();
    if (data == null) return null;
    return Profile.fromJson(data);
  }

  Future<void> upsertProfile(Profile profile) async {
    await _client.from('profiles').upsert(profile.toJson());
  }

  Future<String> uploadAvatar(String userId, Uint8List bytes) async {
    final path = '$userId/profile.jpg';
    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from('avatars').getPublicUrl(path);
  }

  // ── Skills ────────────────────────────────────────────

  Future<List<UserSkill>> getUserSkills(String userId) async {
    final data = await _client
        .from('user_skills')
        .select()
        .eq('user_id', userId);
    return data.map((json) => UserSkill.fromJson(json)).toList();
  }

  Future<void> addUserSkill({
    required String description,
    bool isRemote = false,
  }) async {
    await _client.from('user_skills').insert({
      'user_id': currentUserId,
      'description': description,
      'is_remote': isRemote,
    });
  }

  Future<void> removeUserSkill(String userSkillId) async {
    await _client.from('user_skills').delete().eq('id', userSkillId);
  }

  // ── Swipe Feed ────────────────────────────────────────

  Future<List<SwipeCardData>> getSwipeFeed() async {
    final data = await _client.rpc('get_swipe_feed', params: {
      'current_user_id': currentUserId,
    });
    final list = data is List ? data : (data as List<dynamic>?) ?? [];
    return list
        .map((json) => SwipeCardData.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<String?> swipe({
    required String swipedId,
    required String direction,
  }) async {
    final result = await _client.rpc('handle_swipe', params: {
      'p_swiper_id': currentUserId,
      'p_swiped_id': swipedId,
      'p_direction': direction,
    });
    return result as String?;
  }

  // ── Matches ───────────────────────────────────────────

  Future<List<Match>> getMatches() async {
    final data = await _client.rpc('get_matches_with_last_message', params: {
      'current_user_id': currentUserId,
    });
    final list = data is List ? data : (data as List<dynamic>?) ?? [];
    return list.map((json) {
      final map = json as Map<String, dynamic>;
      Profile? otherUser;
      if (map['other_user'] != null) {
        otherUser = Profile.fromJson(map['other_user'] as Map<String, dynamic>);
      }
      return Match.fromJson(map, otherUser: otherUser);
    }).toList();
  }

  // ── Messages ──────────────────────────────────────────

  Future<List<Message>> getMessages(String matchId, {int limit = 50}) async {
    final data = await _client
        .from('messages')
        .select()
        .eq('match_id', matchId)
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map((json) => Message.fromJson(json)).toList();
  }

  Future<void> sendMessage({
    required String matchId,
    required String content,
  }) async {
    await _client.from('messages').insert({
      'match_id': matchId,
      'sender_id': currentUserId,
      'content': content,
    });
  }

  RealtimeChannel subscribeToMessages(
    String matchId,
    void Function(Message) onMessage,
  ) {
    return _client
        .channel('messages:$matchId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: matchId,
          ),
          callback: (payload) {
            onMessage(Message.fromJson(payload.newRecord));
          },
        )
        .subscribe();
  }

  Future<void> markMessagesAsRead(String matchId) async {
    await _client.rpc('mark_messages_read', params: {
      'p_match_id': matchId,
      'p_user_id': currentUserId,
    });
  }

  Future<int> getTotalUnreadCount() async {
    final result = await _client.rpc('get_total_unread_count', params: {
      'current_user_id': currentUserId,
    });
    return (result as int?) ?? 0;
  }

  RealtimeChannel subscribeToAllMessages(void Function() onNewMessage) {
    return _client
        .channel('all_messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => onNewMessage(),
        )
        .subscribe();
  }
}
