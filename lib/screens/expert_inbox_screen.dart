import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'ask_me_chat_screen.dart';

/// صندوق رسائل المستشار - تصميم ملكي 👑
class ExpertInboxScreen extends StatefulWidget {
  final String expertId;

  const ExpertInboxScreen({super.key, required this.expertId});

  @override
  State<ExpertInboxScreen> createState() => _ExpertInboxScreenState();
}

class _ExpertInboxScreenState extends State<ExpertInboxScreen>
    with TickerProviderStateMixin {
  // ✨ الألوان الملكية
  static const Color _royalGold = Color(0xFFD4AF37);
  static const Color _royalGoldLight = Color(0xFFFFD700);
  static const Color _royalPurple = Color(0xFF6B2D7B);
  static const Color _royalDark = Color(0xFF0D0D12);
  static const Color _royalSurface = Color(0xFF151520);
  static const Color _royalOnline = Color(0xFF50FFB0);

  List<Map<String, dynamic>> _conversations = [];
  bool _isLoading = true;

  RealtimeChannel? _realtimeChannel;

  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _loadConversations();
    _subscribeToConversations();
  }

  @override
  void dispose() {
    if (_realtimeChannel != null) {
      Supabase.instance.client.removeChannel(_realtimeChannel!);
    }
    _pulseController.dispose();
    _shimmerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _subscribeToConversations() {
    _realtimeChannel = Supabase.instance.client
        .channel('expert_inbox_${widget.expertId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'ask_me_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'expert_id',
            value: widget.expertId,
          ),
          callback: (payload) => _loadConversations(),
        )
        .subscribe();
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoading = true);
    try {
      final conversations = await SupabaseService.getExpertConversations(
        widget.expertId,
      );
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _royalDark,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildRoyalBackground(),
          SafeArea(
            child: Column(
              children: [
                _buildRoyalHeader(),
                Expanded(
                  child: _isLoading
                      ? _buildLoadingState()
                      : _conversations.isEmpty
                      ? _buildEmptyState()
                      : _buildConversationsList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoyalBackground() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _royalDark,
                Color.lerp(
                  _royalDark,
                  _royalPurple.withValues(alpha: 0.12),
                  math.sin(_shimmerController.value * math.pi) * 0.5,
                )!,
                _royalDark,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRoyalHeader() {
    final unreadCount = _conversations
        .where((c) => (c['expert_unread_count'] ?? 0) > 0)
        .length;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_royalGold.withValues(alpha: 0.08), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildRoyalButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
              const Spacer(),
              _buildRoyalButton(
                icon: Icons.refresh_rounded,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _fadeController.reset();
                  _loadConversations();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  final glow =
                      0.3 + (math.sin(_pulseController.value * math.pi) * 0.2);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_royalGold, _royalGoldLight],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _royalGold.withValues(alpha: glow),
                          blurRadius: 16,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.inbox_rounded,
                      color: _royalDark,
                      size: 26,
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [_royalGold, _royalGoldLight, _royalGold],
                      ).createShader(bounds),
                      child: const Text(
                        'صندوق الرسائل',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (unreadCount > 0) ...[
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) => Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _royalOnline,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _royalOnline.withValues(
                                      alpha:
                                          0.5 + (_pulseController.value * 0.3),
                                    ),
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$unreadCount محادثة جديدة',
                            style: TextStyle(
                              fontSize: 13,
                              color: _royalOnline,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else
                          Text(
                            'لا توجد رسائل جديدة',
                            style: TextStyle(
                              fontSize: 13,
                              color: _royalGold.withValues(alpha: 0.6),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoyalButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _royalGold.withValues(alpha: 0.15),
              _royalGold.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _royalGold.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: _royalGold, size: 20),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 45,
            height: 45,
            child: CircularProgressIndicator(color: _royalGold, strokeWidth: 3),
          ),
          const SizedBox(height: 16),
          Text(
            'جاري التحميل...',
            style: TextStyle(color: _royalGold.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) => Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _royalGold.withValues(alpha: 0.12),
                    _royalGold.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(
                  color: _royalGold.withValues(
                    alpha: 0.2 + (_pulseController.value * 0.1),
                  ),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.inbox_outlined,
                size: 60,
                color: _royalGold.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'لا توجد محادثات',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _royalGold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'سيتم عرض المحادثات هنا',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationsList() {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        _fadeController.reset();
        await _loadConversations();
      },
      color: _royalGold,
      backgroundColor: _royalSurface,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        itemCount: _conversations.length,
        itemBuilder: (context, index) {
          return FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: _fadeController,
                      curve: Interval(
                        (index / _conversations.length) * 0.5,
                        1.0,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
              child: _buildRoyalConversationCard(_conversations[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoyalConversationCard(Map<String, dynamic> conversation) {
    final userName = conversation['user_name'] ?? 'مستخدم';
    final lastMessage = conversation['last_message'] ?? '';
    final unreadCount = conversation['expert_unread_count'] ?? 0;
    final updatedAt = conversation['updated_at'];
    final userProfileImage = conversation['user_profile_image'];

    String timeText = '';
    if (updatedAt != null) {
      try {
        final date = DateTime.parse(updatedAt);
        final now = DateTime.now();
        if (date.day == now.day &&
            date.month == now.month &&
            date.year == now.year) {
          timeText = DateFormat('HH:mm').format(date);
        } else {
          timeText = DateFormat('dd/MM').format(date);
        }
      } catch (_) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _openConversation(conversation),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: unreadCount > 0
                  ? [
                      _royalGold.withValues(alpha: 0.1),
                      _royalPurple.withValues(alpha: 0.05),
                    ]
                  : [
                      _royalSurface.withValues(alpha: 0.8),
                      _royalSurface.withValues(alpha: 0.6),
                    ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unreadCount > 0
                  ? _royalGold.withValues(alpha: 0.5)
                  : _royalGold.withValues(alpha: 0.1),
              width: unreadCount > 0 ? 1.5 : 1,
            ),
            boxShadow: unreadCount > 0
                ? [
                    BoxShadow(
                      color: _royalGold.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _buildUserAvatar(userName, userProfileImage, unreadCount > 0),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: unreadCount > 0
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: unreadCount > 0
                                  ? _royalGold
                                  : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (timeText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: unreadCount > 0
                                  ? _royalGold.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              timeText,
                              style: TextStyle(
                                fontSize: 11,
                                color: unreadCount > 0
                                    ? _royalGold
                                    : Colors.white.withValues(alpha: 0.5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lastMessage.isEmpty ? 'محادثة جديدة' : lastMessage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (unreadCount > 0) ...[
                          const SizedBox(width: 10),
                          _buildUnreadBadge(unreadCount),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                color: unreadCount > 0
                    ? _royalGold
                    : Colors.white.withValues(alpha: 0.3),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String name, String? image, bool hasUnread) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: hasUnread
                  ? [_royalGold, _royalGoldLight]
                  : [
                      _royalPurple.withValues(alpha: 0.5),
                      _royalPurple.withValues(alpha: 0.3),
                    ],
            ),
            boxShadow: hasUnread
                ? [
                    BoxShadow(
                      color: _royalGold.withValues(
                        alpha: 0.25 + (_pulseController.value * 0.1),
                      ),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              color: _royalDark,
              child: image != null && image.isNotEmpty
                  ? Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _avatarText(name),
                    )
                  : _avatarText(name),
            ),
          ),
        );
      },
    );
  }

  Widget _avatarText(String name) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _royalGold.withValues(alpha: 0.2),
            _royalPurple.withValues(alpha: 0.2),
          ],
        ),
      ),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: _royalGold,
        ),
      ),
    );
  }

  Widget _buildUnreadBadge(int count) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_royalGold, _royalGoldLight]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: _royalGold.withValues(
                  alpha: 0.3 + (_pulseController.value * 0.15),
                ),
                blurRadius: 8,
              ),
            ],
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _royalDark,
            ),
          ),
        );
      },
    );
  }

  void _openConversation(Map<String, dynamic> conversation) {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AskMeChatScreen(
              conversationId: conversation['id'],
              userId: widget.expertId,
              expertId: widget.expertId,
              expertName: conversation['user_name'] ?? 'مستخدم',
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.08, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    ).then((_) {
      _fadeController.reset();
      _loadConversations();
    });
  }
}
