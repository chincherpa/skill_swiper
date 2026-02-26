import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/match.dart';
import '../../../services/supabase_service.dart';

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

class _MatchesScreenState extends State<MatchesScreen> {
  final _service = SupabaseService();
  List<Match>? _matches;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() => _loading = true);
    try {
      final matches = await _service.getMatches();
      if (mounted) {
        setState(() {
        _matches = matches;
        _loading = false;
      });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMatches,
              child: _buildContent(),
            ),
    );
  }

  Widget _buildContent() {
    if (_matches == null || _matches!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Noch keine Matches.\nSwipe weiter, um Leute zu entdecken!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Split into new matches (no messages) and chats (with messages)
    final newMatches =
        _matches!.where((m) => m.lastMessage == null).toList();
    final chats =
        _matches!.where((m) => m.lastMessage != null).toList();

    return ListView(
      children: [
        // New Matches section
        if (newMatches.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Neue Matches',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: newMatches.length,
              itemBuilder: (context, index) {
                final match = newMatches[index];
                final other = match.otherUser;
                return GestureDetector(
                  onTap: () => context.go('/chat/${match.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: AppColors.background,
                          backgroundImage: other?.avatarUrl != null
                              ? NetworkImage(other!.avatarUrl!)
                              : null,
                          child: other?.avatarUrl == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 68,
                          child: Text(
                            other?.name ?? 'User',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(),
        ],

        // Chats section
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            'Chats',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        if (chats.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text(
                'Noch keine Unterhaltungen',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else
          ...chats.map((match) {
            final other = match.otherUser;
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.background,
                backgroundImage: other?.avatarUrl != null
                    ? NetworkImage(other!.avatarUrl!)
                    : null,
                child: other?.avatarUrl == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(other?.name ?? 'User'),
              subtitle: Text(
                match.lastMessage ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: match.lastMessageAt != null
                  ? Text(
                      _formatTime(match.lastMessageAt!),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    )
                  : null,
              onTap: () => context.go('/chat/${match.id}'),
            );
          }),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return 'Jetzt';
    if (diff.inHours < 1) return 'vor ${diff.inMinutes}m';
    if (diff.inDays < 1) return 'vor ${diff.inHours}h';
    if (diff.inDays < 7) return 'vor ${diff.inDays}d';
    return '${time.day}.${time.month}.';
  }
}
