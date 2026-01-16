import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import 'ask_me_chat_screen.dart';

/// شاشة "اسألني" - تصميم ملكي فاخر 👑
class AskMeScreen extends StatefulWidget {
  final String userId;

  const AskMeScreen({super.key, required this.userId});

  @override
  State<AskMeScreen> createState() => _AskMeScreenState();
}

class _AskMeScreenState extends State<AskMeScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ✨ الألوان الملكية
  static const Color _royalGold = Color(0xFFD4AF37);
  static const Color _royalGoldLight = Color(0xFFFFD700);
  static const Color _royalPurple = Color(0xFF6B2D7B);
  static const Color _royalPurpleLight = Color(0xFF9C4DCC);
  static const Color _royalDark = Color(0xFF0D0D12);
  static const Color _royalSurface = Color(0xFF151520);
  static const Color _royalOnline = Color(0xFF50FFB0);

  List<Map<String, dynamic>> _experts = [];
  List<Map<String, dynamic>> _filteredExperts = [];
  bool _isLoading = true;

  bool _isExpert = false;
  List<Map<String, dynamic>> _conversations = [];
  bool _isLoadingConversations = false;
  RealtimeChannel? _convsChannel;

  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialization = 'الكل';
  bool _showOnlineOnly = false;
  List<String> _specializations = ['الكل'];

  // Animation Controllers
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _crownController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Timer? _heartbeatTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _crownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );

    _loadExperts();
    _checkIfExpert();
    _searchController.addListener(_filterExperts);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopHeartbeat();
    _setExpertOffline();
    _pulseController.dispose();
    _shimmerController.dispose();
    _crownController.dispose();
    _fadeController.dispose();
    _searchController.removeListener(_filterExperts);
    _searchController.dispose();
    _unsubscribeFromConversations();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isExpert) return;
    if (state == AppLifecycleState.resumed) {
      _setExpertOnline();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _setExpertOffline();
    }
  }

  void _setExpertOnline() {
    if (!_isExpert || widget.userId == 'guest') return;
    SupabaseService.updateExpertOnlineStatus(widget.userId, true);
    _startHeartbeat();
  }

  void _setExpertOffline() {
    if (!_isExpert || widget.userId == 'guest') return;
    SupabaseService.updateExpertOnlineStatus(widget.userId, false);
    _stopHeartbeat();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (_isExpert) {
        SupabaseService.expertHeartbeat(widget.userId);
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _unsubscribeFromConversations() {
    if (_convsChannel != null) {
      SupabaseService.unsubscribeFromExpertConversations(_convsChannel!);
      _convsChannel = null;
    }
  }

  Future<void> _loadExperts() async {
    setState(() => _isLoading = true);
    try {
      final experts = await SupabaseService.getActiveExperts();
      if (mounted) {
        final specs = <String>{'الكل'};
        for (var expert in experts) {
          specs.add(expert['specialization'] as String? ?? 'عام');
        }
        setState(() {
          _experts = experts;
          _filteredExperts = experts;
          _specializations = specs.toList();
          _isLoading = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      debugPrint('❌ Error loading experts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterExperts() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredExperts = _experts.where((expert) {
        final name = (expert['display_name'] ?? '').toString().toLowerCase();
        final bio = (expert['bio'] ?? '').toString().toLowerCase();
        final spec = (expert['specialization'] ?? '').toString().toLowerCase();
        final matchesSearch =
            query.isEmpty ||
            name.contains(query) ||
            bio.contains(query) ||
            spec.contains(query);
        final matchesSpec =
            _selectedSpecialization == 'الكل' ||
            expert['specialization'] == _selectedSpecialization;
        final matchesOnline = !_showOnlineOnly || expert['is_online'] == true;
        return matchesSearch && matchesSpec && matchesOnline;
      }).toList();
    });
  }

  Future<void> _refreshAllData() async {
    HapticFeedback.mediumImpact();
    _fadeController.reset();
    await Future.wait([_loadExperts(), _checkIfExpert()]);
  }

  Future<void> _checkIfExpert() async {
    if (widget.userId == 'guest') return;
    try {
      final isExpert = await SupabaseService.checkIfExpert(widget.userId);
      if (mounted) {
        setState(() => _isExpert = isExpert);
        if (isExpert) {
          _setExpertOnline();
          _loadConversations();
          _subscribeToConversations();
        }
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  void _subscribeToConversations() {
    if (_convsChannel != null) return;
    _convsChannel = SupabaseService.subscribeToExpertConversations(
      widget.userId,
      () => _loadConversations(),
    );
  }

  Future<void> _loadConversations() async {
    setState(() => _isLoadingConversations = true);
    try {
      final conversations = await SupabaseService.getExpertConversations(
        widget.userId,
      );
      if (mounted) {
        setState(() {
          _conversations = conversations;
          _isLoadingConversations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingConversations = false);
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
            child: RefreshIndicator(
              onRefresh: _refreshAllData,
              color: _royalGold,
              backgroundColor: _royalSurface,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  _buildRoyalHeader(),
                  _buildRoyalSearchBar(),
                  _buildRoyalFilters(),
                  _buildExpertsList(),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _isExpert ? _buildRoyalFAB() : null,
    );
  }

  // 👑 الخلفية الملكية
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
                  _royalPurple.withValues(alpha: 0.15),
                  math.sin(_shimmerController.value * math.pi) * 0.5,
                )!,
                _royalDark,
              ],
            ),
          ),
          child: CustomPaint(
            painter: _RoyalPatternPainter(
              animation: _shimmerController.value,
              color: _royalGold.withValues(alpha: 0.03),
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  // 👑 الهيدر الملكي
  Widget _buildRoyalHeader() {
    final onlineCount = _experts.where((e) => e['is_online'] == true).length;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // أزرار التنقل
            Row(
              children: [
                _buildRoyalButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                const Spacer(),
                _buildRoyalButton(
                  icon: Icons.refresh_rounded,
                  onTap: _refreshAllData,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // العنوان مع التاج
            Row(
              children: [
                // التاج الملكي
                AnimatedBuilder(
                  animation: _crownController,
                  builder: (context, child) {
                    final glow =
                        0.3 +
                        (math.sin(_crownController.value * math.pi * 2) * 0.2);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_royalGold, _royalGoldLight, _royalGold],
                          stops: [
                            0.0,
                            0.3 + (_crownController.value * 0.4),
                            1.0,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: _royalGold.withValues(alpha: glow),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Text('👑', style: TextStyle(fontSize: 24)),
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
                          'المستشارون',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'نخبة من الخبراء لخدمتك',
                        style: TextStyle(
                          fontSize: 13,
                          color: _royalGold.withValues(alpha: 0.7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // بطاقة الإحصائيات الملكية
            _buildRoyalStatsCard(onlineCount),
          ],
        ),
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

  Widget _buildRoyalStatsCard(int onlineCount) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _royalGold.withValues(alpha: 0.1),
                _royalPurple.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _royalGold.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              _buildRoyalStatItem(
                '${_filteredExperts.length}',
                'مستشار',
                Icons.star_rounded,
                _royalGold,
              ),
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: _royalGold.withValues(alpha: 0.2),
              ),
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) => _buildRoyalStatItem(
                  '$onlineCount',
                  'متصل',
                  Icons.circle,
                  _royalOnline,
                  iconSize: 12,
                  glow: 0.3 + (_pulseController.value * 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoyalStatItem(
    String value,
    String label,
    IconData icon,
    Color color, {
    double iconSize = 20,
    double glow = 0,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              boxShadow: glow > 0
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: glow),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🔍 شريط البحث الملكي
  Widget _buildRoyalSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _royalGold.withValues(alpha: 0.08),
                _royalPurple.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _searchController.text.isNotEmpty
                  ? _royalGold.withValues(alpha: 0.4)
                  : _royalGold.withValues(alpha: 0.15),
            ),
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            cursorColor: _royalGold,
            decoration: InputDecoration(
              hintText: 'ابحث عن مستشار...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: _royalGold.withValues(alpha: 0.7),
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: _royalGold.withValues(alpha: 0.5),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _filterExperts();
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🏷️ الفلاتر الملكية
  Widget _buildRoyalFilters() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 6),
        child: SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildRoyalChip('🟢 متصل', _showOnlineOnly, () {
                HapticFeedback.selectionClick();
                setState(() => _showOnlineOnly = !_showOnlineOnly);
                _filterExperts();
              }),
              const SizedBox(width: 10),
              ..._specializations.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _buildRoyalChip(s, s == _selectedSpecialization, () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedSpecialization = s);
                    _filterExperts();
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoyalChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(colors: [_royalGold, _royalGoldLight])
              : null,
          color: selected ? null : _royalSurface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : _royalGold.withValues(alpha: 0.2),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: _royalGold.withValues(alpha: 0.3),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _royalDark : _royalGold.withValues(alpha: 0.8),
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // 👥 قائمة المستشارين
  Widget _buildExpertsList() {
    if (_isLoading) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 45,
                height: 45,
                child: CircularProgressIndicator(
                  color: _royalGold,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'جاري التحميل...',
                style: TextStyle(color: _royalGold.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      );
    }
    if (_filteredExperts.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (c, i) => FadeTransition(
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
                        (i / _filteredExperts.length) * 0.5,
                        1.0,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                  ),
              child: _buildRoyalExpertCard(_filteredExperts[i]),
            ),
          ),
          childCount: _filteredExperts.length,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _royalGold.withValues(alpha: 0.15),
                  _royalGold.withValues(alpha: 0.05),
                ],
              ),
            ),
            child: Icon(
              Icons.search_off_rounded,
              size: 50,
              color: _royalGold.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد نتائج',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _royalGold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'جرب البحث بكلمات أخرى',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }

  // 👑 بطاقة المستشار الملكية
  Widget _buildRoyalExpertCard(Map<String, dynamic> expert) {
    final userData = expert['users'] as Map<String, dynamic>?;
    final userName = userData?['name'] ?? expert['display_name'] ?? 'مستشار';
    final userUsername = userData?['username'] ?? '';
    final userImage = userData?['profile_image'] ?? expert['profile_image'];
    final bio = expert['bio'] ?? '';
    final specialization = expert['specialization'] ?? 'عام';
    final expertUserId = expert['user_id'];
    final isOnline = expert['is_online'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _startConversation(expertUserId, userName, userImage),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isOnline
                  ? [
                      _royalGold.withValues(alpha: 0.08),
                      _royalPurple.withValues(alpha: 0.05),
                    ]
                  : [
                      _royalSurface.withValues(alpha: 0.8),
                      _royalSurface.withValues(alpha: 0.6),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isOnline
                  ? _royalGold.withValues(alpha: 0.4)
                  : _royalGold.withValues(alpha: 0.1),
              width: isOnline ? 1.5 : 1,
            ),
            boxShadow: isOnline
                ? [
                    BoxShadow(
                      color: _royalGold.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              _buildRoyalAvatar(userName, userImage, isOnline),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isOnline ? _royalGold : Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOnline) _buildOnlineBadge(),
                      ],
                    ),
                    if (userUsername.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '@$userUsername',
                          style: TextStyle(
                            fontSize: 12,
                            color: _royalGold.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    const SizedBox(height: 6),
                    _buildSpecBadge(specialization),
                    if (bio.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        bio,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _buildChatBtn(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoyalAvatar(String name, String? image, bool isOnline) {
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: isOnline
                        ? [_royalGold, _royalGoldLight]
                        : [
                            _royalPurple.withValues(alpha: 0.5),
                            _royalPurple.withValues(alpha: 0.3),
                          ],
                  ),
                  boxShadow: isOnline
                      ? [
                          BoxShadow(
                            color: _royalGold.withValues(
                              alpha: 0.3 + (_pulseController.value * 0.15),
                            ),
                            blurRadius: 12,
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
          ),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _royalOnline,
                  shape: BoxShape.circle,
                  border: Border.all(color: _royalDark, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: _royalOnline.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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

  Widget _buildOnlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _royalOnline.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _royalOnline.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _royalOnline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'متصل',
            style: TextStyle(
              fontSize: 10,
              color: _royalOnline,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecBadge(String spec) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_royalPurple, _royalPurpleLight]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            spec,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBtn() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_royalGold, _royalGoldLight]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _royalGold.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(Icons.chat_bubble_rounded, color: _royalDark, size: 18),
    );
  }

  // 📬 زر الرسائل الملكي
  Widget _buildRoyalFAB() {
    final unreadTotal = _conversations.fold<int>(
      0,
      (sum, c) => sum + ((c['expert_unread_count'] ?? 0) as int),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: _royalGold.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          _showMessagesBottomSheet();
        },
        backgroundColor: _royalGold,
        elevation: 0,
        icon: Badge(
          isLabelVisible: unreadTotal > 0,
          label: Text('$unreadTotal'),
          backgroundColor: Colors.red,
          child: Icon(Icons.inbox_rounded, color: _royalDark),
        ),
        label: Text(
          _conversations.isEmpty
              ? 'رسائلي'
              : 'رسائلي (${_conversations.length})',
          style: TextStyle(color: _royalDark, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  void _showMessagesBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_royalSurface.withValues(alpha: 0.98), _royalDark],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                border: Border.all(color: _royalGold.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 14),
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _royalGold.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_royalGold, _royalGoldLight],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.inbox_rounded,
                            color: _royalDark,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'صندوق الوارد',
                          style: TextStyle(
                            color: _royalGold,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_conversations.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_royalGold, _royalGoldLight],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              '${_conversations.length}',
                              style: TextStyle(
                                color: _royalDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    color: _royalGold.withValues(alpha: 0.15),
                  ),
                  Expanded(
                    child: _isLoadingConversations
                        ? Center(
                            child: CircularProgressIndicator(color: _royalGold),
                          )
                        : _conversations.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 50,
                                  color: _royalGold.withValues(alpha: 0.3),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'لا توجد رسائل',
                                  style: TextStyle(
                                    color: _royalGold.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            physics: const BouncingScrollPhysics(),
                            itemCount: _conversations.length,
                            itemBuilder: (c, i) =>
                                _buildConversationItem(_conversations[i]),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConversationItem(Map<String, dynamic> conversation) {
    final userName = conversation['user_name'] ?? 'مستخدم';
    final lastMessage = conversation['last_message'] ?? '';
    final unreadCount = conversation['expert_unread_count'] ?? 0;
    final userImage = conversation['user_profile_image'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: unreadCount > 0
                ? [
                    _royalGold.withValues(alpha: 0.1),
                    _royalPurple.withValues(alpha: 0.05),
                  ]
                : [_royalSurface, _royalSurface],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unreadCount > 0
                ? _royalGold.withValues(alpha: 0.4)
                : _royalGold.withValues(alpha: 0.1),
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [
                  _royalGold.withValues(alpha: 0.3),
                  _royalPurple.withValues(alpha: 0.2),
                ],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: userImage != null
                  ? Image.network(userImage, fit: BoxFit.cover)
                  : Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                        style: TextStyle(
                          color: _royalGold,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
            ),
          ),
          title: Text(
            userName,
            style: TextStyle(
              color: unreadCount > 0 ? _royalGold : Colors.white,
              fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            lastMessage,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: unreadCount > 0
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_royalGold, _royalGoldLight],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: TextStyle(
                      color: _royalDark,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : Icon(
                  Icons.chevron_right,
                  color: _royalGold.withValues(alpha: 0.3),
                ),
          onTap: () => _openConversation(conversation),
        ),
      ),
    );
  }

  Future<void> _startConversation(
    String expertId,
    String expertName,
    String? expertImage,
  ) async {
    if (widget.userId == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: _royalGold),
              const SizedBox(width: 12),
              const Text('يرجى تسجيل الدخول'),
            ],
          ),
          backgroundColor: _royalSurface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    try {
      final conversationId = await SupabaseService.createOrGetConversation(
        userId: widget.userId,
        expertId: expertId,
      );
      if (conversationId != null && mounted) {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                AskMeChatScreen(
                  conversationId: conversationId,
                  userId: widget.userId,
                  expertId: expertId,
                  expertName: expertName,
                  expertImage: expertImage,
                ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('فشل بدء المحادثة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openConversation(Map<String, dynamic> conversation) {
    final userName =
        conversation['user']?['name'] ?? conversation['user_name'] ?? 'مستخدم';
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AskMeChatScreen(
              conversationId: conversation['id'],
              userId: widget.userId,
              expertId: widget.userId,
              expertName: userName,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// 🎨 رسم النمط الملكي
class _RoyalPatternPainter extends CustomPainter {
  final double animation;
  final Color color;

  _RoyalPatternPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const spacing = 40.0;
    final offset = animation * spacing;

    for (var x = -spacing + offset; x < size.width + spacing; x += spacing) {
      for (var y = -spacing; y < size.height + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), 3, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RoyalPatternPainter oldDelegate) =>
      animation != oldDelegate.animation;
}
