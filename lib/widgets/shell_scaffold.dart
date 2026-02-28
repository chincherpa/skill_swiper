import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';

class ShellScaffold extends StatefulWidget {
  final Widget child;

  const ShellScaffold({super.key, required this.child});

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  final _service = SupabaseService();
  int _unreadCount = 0;
  int _matchCount = 0;
  RealtimeChannel? _matchChannel;
  RealtimeChannel? _messageChannel;

  @override
  void initState() {
    super.initState();
    _loadUnreadCount();
    _loadMatchCount();
    _subscribeToMatches();
    _subscribeToMessages();
  }

  @override
  void dispose() {
    _matchChannel?.unsubscribe();
    _messageChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _service.getTotalUnreadCount();
      if (mounted) {
        setState(() => _unreadCount = count);
      }
    } catch (_) {}
  }

  Future<void> _loadMatchCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final count = await Supabase.instance.client
          .from('matches')
          .select()
          .or('user_a.eq.$userId,user_b.eq.$userId')
          .count(CountOption.exact);
      if (mounted) {
        setState(() => _matchCount = count.count);
      }
    } catch (_) {}
  }

  void _subscribeToMatches() {
    _matchChannel = Supabase.instance.client
        .channel('matches_badge')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'matches',
          callback: (_) {
            _loadMatchCount();
            _loadUnreadCount();
          },
        )
        .subscribe();
  }

  void _subscribeToMessages() {
    _messageChannel = _service.subscribeToAllMessages(() {
      _loadUnreadCount();
    });
  }

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/profile') return 0;
    if (location == '/swipe') return 1;
    if (location == '/matches') return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          switch (i) {
            case 0:
              context.go('/profile');
            case 1:
              context.go('/swipe');
            case 2:
              context.go('/matches');
          }
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profil',
          ),
          const NavigationDestination(
            icon: Icon(Icons.style_outlined),
            selectedIcon: Icon(Icons.style),
            label: 'Swipe',
          ),
          NavigationDestination(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                Badge(
                  isLabelVisible: _unreadCount > 0,
                  label: Text('$_unreadCount'),
                  child: const Icon(Icons.chat_bubble_outline),
                ),
                if (_matchCount > 0)
                  Positioned(
                    left: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_matchCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            selectedIcon: Stack(
              clipBehavior: Clip.none,
              children: [
                Badge(
                  isLabelVisible: _unreadCount > 0,
                  label: Text('$_unreadCount'),
                  child: const Icon(Icons.chat_bubble),
                ),
                if (_matchCount > 0)
                  Positioned(
                    left: -6,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_matchCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            label: 'Matches',
          ),
        ],
      ),
    );
  }
}
