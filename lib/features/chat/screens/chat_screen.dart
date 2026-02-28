import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../models/message.dart';
import '../../../models/match.dart' as app;
import '../../../services/supabase_service.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;

  const ChatScreen({super.key, required this.matchId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _service = SupabaseService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  List<Message> _messages = [];
  bool _loading = true;
  RealtimeChannel? _channel;
  RealtimeChannel? _presenceChannel;
  String? _partnerName;
  String? _partnerAvatarUrl;
  bool _partnerIsTyping = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_onTextChanged);
    _loadMessages();
    _loadPartnerInfo();
    _subscribeToMessages();
    _markAsRead();
  }

  @override
  void dispose() {
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _channel?.unsubscribe();
    _presenceChannel?.unsubscribe();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {});
    if (_messageController.text.trim().isNotEmpty) {
      _sendTypingIndicator();
    }
  }

  void _sendTypingIndicator() {
    _presenceChannel?.track({'typing': true});
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _presenceChannel?.untrack();
    });
  }

  void _setupPresence() {
    final currentUserId = _service.currentUserId;
    if (currentUserId == null) return;

    _presenceChannel = Supabase.instance.client
        .channel('typing:${widget.matchId}')
        .onPresenceSync((payload) {
      if (!mounted) return;
      final presences = _presenceChannel?.presenceState() ?? [];

      bool typing = false;
      for (final state in presences) {
        for (final presence in state.presences) {
          if (presence.payload['user_id'] != currentUserId &&
              presence.payload['typing'] == true) {
            typing = true;
          }
        }
      }
      if (_partnerIsTyping != typing) {
        setState(() => _partnerIsTyping = typing);
      }
    })
        .subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _presenceChannel?.track({
          'user_id': currentUserId,
          'typing': false,
        });
      }
    });
  }

  Future<void> _markAsRead() async {
    try {
      await _service.markMessagesAsRead(widget.matchId);
    } catch (_) {}
  }

  Future<void> _loadPartnerInfo() async {
    try {
      final matches = await _service.getMatches();
      final match = matches.cast<app.Match?>().firstWhere(
            (m) => m!.id == widget.matchId,
            orElse: () => null,
          );
      if (match?.otherUser != null && mounted) {
        setState(() {
          _partnerName = match!.otherUser!.name;
          _partnerAvatarUrl = match.otherUser!.avatarUrl;
        });
        _setupPresence();
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final messages = await _service.getMessages(widget.matchId);
      if (mounted) {
        setState(() {
          _messages = messages.reversed.toList();
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _subscribeToMessages() {
    _channel = _service.subscribeToMessages(
      widget.matchId,
      (message) {
        if (_messages.any((m) => m.id == message.id)) return;
        setState(() => _messages.add(message));
        _scrollToBottom();
        // Mark incoming messages as read immediately
        if (message.senderId != _service.currentUserId) {
          _markAsRead();
        }
      },
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    _presenceChannel?.untrack();
    _typingTimer?.cancel();

    try {
      await _service.sendMessage(
        matchId: widget.matchId,
        content: text,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nachricht konnte nicht gesendet werden: $e')),
        );
      }
    }
  }

  bool _shouldShowDateSeparator(int index) {
    if (index == 0) return true;
    final current = _messages[index].createdAt;
    final previous = _messages[index - 1].createdAt;
    return current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
  }

  String _formatDateSeparator(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(messageDay).inDays;

    if (diff == 0) return 'Heute';
    if (diff == 1) return 'Gestern';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _service.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (_partnerAvatarUrl != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundImage: NetworkImage(_partnerAvatarUrl!),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.background,
                  child: Icon(Icons.person, size: 18),
                ),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _partnerName ?? 'Chat',
                  style: const TextStyle(fontSize: 16),
                ),
                if (_partnerIsTyping)
                  const Text(
                    'tippt...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text(
                          'Starte eine Konversation!',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isOwn = msg.senderId == currentUserId;
                          return Column(
                            children: [
                              if (_shouldShowDateSeparator(index))
                                _buildDateSeparator(msg.createdAt),
                              _buildMessageBubble(msg, isOwn),
                            ],
                          );
                        },
                      ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Nachricht schreiben...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _messageController.text.trim().isNotEmpty
                        ? _sendMessage
                        : null,
                    icon: const Icon(Icons.send),
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDateSeparator(date),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isOwn) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isOwn ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOwn ? 16 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              msg.content,
              style: TextStyle(
                color: isOwn ? Colors.white : AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isOwn
                        ? Colors.white.withValues(alpha: 0.7)
                        : AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                if (isOwn) ...[
                  const SizedBox(width: 4),
                  Icon(
                    msg.readAt != null ? Icons.done_all : Icons.done,
                    size: 14,
                    color: msg.readAt != null
                        ? Colors.lightBlueAccent
                        : Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
