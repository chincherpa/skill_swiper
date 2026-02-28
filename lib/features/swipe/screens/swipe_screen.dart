import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/swipe_card_data.dart';
import '../../../services/supabase_service.dart';
import '../widgets/swipe_card.dart';

class SwipeScreen extends StatefulWidget {
  const SwipeScreen({super.key});

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final _service = SupabaseService();
  final _swiperController = CardSwiperController();

  List<SwipeCardData>? _cards;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cards = await _service.getSwipeFeed();
      setState(() {
        _cards = cards;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<bool> _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) async {
    if (_cards == null || previousIndex >= _cards!.length) return false;

    final card = _cards![previousIndex];
    final swipeDirection =
        direction == CardSwiperDirection.right ? 'right' : 'left';

    try {
      final matchId = await _service.swipe(
        swipedId: card.userId,
        direction: swipeDirection,
      );

      if (matchId != null && mounted) {
        _showMatchDialog(card, matchId);
      }
    } catch (e) {
      // Swipe failed silently - don't block the UI
    }

    return true;
  }

  void _onEnd() {
    // All cards swiped
  }

  void _showMatchDialog(SwipeCardData matchedUser, String matchId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "It's a Match! 🎉",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.background,
              child: matchedUser.avatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        matchedUser.avatarUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.person, size: 40),
            ),
            const SizedBox(height: 12),
            Text(
              matchedUser.name,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ihr könnt jetzt miteinander chatten!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Weiter swipen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/chat/$matchId');
            },
            child: const Text('Nachricht senden'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quid'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.swipeLeft),
              const SizedBox(height: 16),
              Text('Fehler: $_error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadFeed,
                child: const Text('Erneut versuchen'),
              ),
            ],
          ),
        ),
      );
    }

    if (_cards == null || _cards!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.explore_off,
                  size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              const Text(
                'Keine neuen Leute in deiner Nähe.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Versuch einen größeren Umkreis in deinem Profil!',
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadFeed,
                child: const Text('Aktualisieren'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: CardSwiper(
              controller: _swiperController,
              cardsCount: _cards!.length,
              isLoop: false,
              numberOfCardsDisplayed: _cards!.length >= 2 ? 2 : 1,
              allowedSwipeDirection: const AllowedSwipeDirection.symmetric(
                horizontal: true,
                vertical: false,
              ),
              onSwipe: _onSwipe,
              onEnd: _onEnd,
              cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                return Stack(
                  children: [
                    SwipeCard(data: _cards![index]),
                    // Swipe overlay
                    if (percentThresholdX > 20)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.swipeRight.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(Icons.check, size: 80, color: Colors.white),
                          ),
                        ),
                      ),
                    if (percentThresholdX < -20)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.swipeLeft.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: Icon(Icons.close, size: 80, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton(
                heroTag: 'swipe_left',
                onPressed: () =>
                    _swiperController.swipe(CardSwiperDirection.left),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.swipeLeft,
                child: const Icon(Icons.close, size: 32),
              ),
              FloatingActionButton(
                heroTag: 'swipe_right',
                onPressed: () =>
                    _swiperController.swipe(CardSwiperDirection.right),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.swipeRight,
                child: const Icon(Icons.check, size: 32),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
