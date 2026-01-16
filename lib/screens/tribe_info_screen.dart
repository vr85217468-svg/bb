import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'tribe_chat_screen.dart';
import 'tribe_settings_screen.dart';

/// شاشة معلومات القبيلة - تصميم "نور على سواد" 🎙️✨🖤👑
class TribeInfoScreen extends StatefulWidget {
  final String tribeId;
  final Map<String, dynamic> user;
  final VoidCallback? onBack;
  final void Function(Map<String, dynamic> tribe)? onJoined;

  const TribeInfoScreen({
    super.key,
    required this.tribeId,
    required this.user,
    this.onBack,
    this.onJoined,
  });

  @override
  State<TribeInfoScreen> createState() => _TribeInfoScreenState();
}

class _TribeInfoScreenState extends State<TribeInfoScreen> {
  Map<String, dynamic>? _tribe;
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isMember = false;
  bool _isLeader = false;
  bool _isJoining = false;
  String? _requestStatus;
  RealtimeChannel? _tribeChannel;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToTribeChanges();
  }

  @override
  void dispose() {
    _tribeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.getTribeById(widget.tribeId), // 1. تفاصيل القبيلة
        SupabaseService.getTribeMembers(
          widget.tribeId,
        ), // 2. الأعضاء (نشتق منهم الحالة)
        SupabaseService.getJoinRequestStatus(
          widget.tribeId,
          widget.user['id'],
        ), // 3. حالة الطلب
      ]);

      final Map<String, dynamic>? tribe = results[0] as Map<String, dynamic>?;
      final List<Map<String, dynamic>> members =
          results[1] as List<Map<String, dynamic>>;
      final String? requestStatus = results[2] as String?;

      // اشتقاق الحالة محلياً 🚀
      final currentUserId = widget.user['id'];
      final userMembership = members.firstWhere(
        (m) => m['user_id'] == currentUserId,
        orElse: () => {},
      );

      final bool isMember =
          userMembership.isNotEmpty && userMembership['status'] == 'active';
      final bool isLeader =
          userMembership.isNotEmpty && userMembership['is_leader'] == true;

      if (mounted) {
        setState(() {
          _tribe = tribe;
          _members = members;
          _isMember = isMember;
          _isLeader = isLeader;
          _requestStatus = requestStatus;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ TribeInfoScreen _loadData error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToTribeChanges() {
    _tribeChannel = Supabase.instance.client
        .channel('tribe_info_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.tribeId,
          ),
          callback: (payload) {
            if (mounted) _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribe_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tribe_id',
            value: widget.tribeId,
          ),
          callback: (payload) {
            if (mounted) _loadData();
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black, // أسود حالك
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.accentSilverGold,
          ), // نور ذهبي
        ),
      );
    }

    if (_tribe == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.white24, size: 64),
              const SizedBox(height: 16),
              const Text(
                'القبيلة تلاشت في غياهب النسيان',
                style: TextStyle(color: Colors.white60, fontSize: 16),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'العودة للأثر',
                  style: TextStyle(color: AppTheme.accentSilverGold),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black, // الخلفية: سواد
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildTribeInfo(),
                _buildMembersSection(),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: Colors.black,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.2),
            ),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFFFFD700),
            size: 18,
          ),
        ),
        onPressed: () =>
            widget.onBack != null ? widget.onBack!() : Navigator.pop(context),
      ),
      actions: [
        if (_isLeader)
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.settings_suggest_rounded,
                color: Color(0xFFFFD700),
                size: 20,
              ),
            ),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TribeSettingsScreen(tribe: _tribe!, user: widget.user),
                ),
              );
              if (result == true) _loadData();
            },
          ),
        const SizedBox(width: 12),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          children: [
            // Rich Gradient Background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF4A0000),
                      Color(0xFF1A0000),
                      Colors.black,
                    ],
                  ),
                ),
              ),
            ),
            // Glowing Aura
            Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [const SizedBox(height: 50), _buildLargeTribeIcon()],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeTribeIcon() {
    return Hero(
      tag: 'tribe_icon_${widget.tribeId}',
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(
            color: const Color(0xFFFFD700).withValues(alpha: 0.5),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withValues(alpha: 0.25),
              blurRadius: 40,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Center(
          child: Text(
            _tribe!['icon'] ?? '⚔️',
            style: const TextStyle(fontSize: 65),
          ),
        ),
      ),
    );
  }

  Widget _buildTribeInfo() {
    final memberCount = _members.length;
    final maxMembers = _tribe!['max_members'] ?? 12;
    final isPrivate = _tribe!['is_private'] == true;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 25),
      child: Column(
        children: [
          // Name with Premium Gradient
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFFFFF), Color(0xFFFFD700)],
            ).createShader(bounds),
            child: Text(
              (_tribe!['name'] ?? '').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                fontFamily: 'Tajawal',
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_tribe!['name_en'] != null) ...[
            const SizedBox(height: 8),
            Text(
              _tribe!['name_en'].toUpperCase(),
              style: TextStyle(
                color: const Color(0xFFFFD700).withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
          ],
          const SizedBox(height: 30),

          // Badges Row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBadge(
                _tribe!['tribe_code'] ?? '',
                Icons.stars_rounded,
                const Color(0xFFFFD700),
              ),
              const SizedBox(width: 15),
              _buildBadge(
                isPrivate ? 'مجلس مغلق' : 'مجلس عام',
                isPrivate ? Icons.lock_person_rounded : Icons.public_rounded,
                isPrivate ? const Color(0xFFFF4D4D) : const Color(0xFF00E676),
              ),
            ],
          ),

          if (_tribe!['description'] != null) ...[
            const SizedBox(height: 35),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                _tribe!['description'],
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 15,
                  height: 1.8,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],

          const SizedBox(height: 45),

          // Stats Card
          _buildStatsCard(memberCount, maxMembers),

          const SizedBox(height: 30),
          if (_isMember || _isLeader) _buildLeaveButton(),
        ],
      ),
    );
  }

  Widget _buildStatsCard(int count, int max) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF151515),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildStatItem(
            'فرسان القبيلة',
            '$count / $max',
            Icons.groups_3_rounded,
          ),
          const Spacer(),
          Container(
            height: 40,
            width: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const Spacer(),
          _buildStatItem('المستوى', 'قريباً', Icons.workspace_premium_rounded),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: const Color(0xFFFFD700).withValues(alpha: 0.6),
          size: 20,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'Tajawal',
          ),
        ),
      ],
    );
  }

  Widget _buildBadge(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(150), width: 1), // حدود مضيئة
        boxShadow: [
          BoxShadow(color: color.withAlpha(30), blurRadius: 8), // توهج خفيف
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveButton() {
    return InkWell(
      onTap: _isJoining ? null : _leaveTribe,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'مغادرة حِمى القَبِيلَة',
          style: TextStyle(
            color: Colors.redAccent.withAlpha(200),
            fontSize: 12,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            shadows: [
              Shadow(color: Colors.redAccent.withAlpha(100), blurRadius: 5),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _leaveTribe() async {
    // الخروج فوراً من الشاشة لإعطاء شعور بالاستجابة السريعة
    if (mounted) {
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.pop(context, true);
      }
    }

    try {
      // تنفيذ عملية المغادرة في الخلفية
      await SupabaseService.leaveTribe(widget.tribeId, widget.user['id']);
    } catch (e) {
      debugPrint('❌ _leaveTribe error: $e');
    }
  }

  Widget _buildMembersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(32, 40, 32, 20),
          child: Text(
            'الأعضاء الحلوين',
            style: TextStyle(
              color: AppTheme.accentSilverGold,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final memberData = _members[index];
            final user = memberData['user'];
            final isLeader = memberData['is_leader'] == true;
            return _buildMemberCard(user, isLeader);
          },
        ),
      ],
    );
  }

  Widget _buildMemberCard(Map<String, dynamic>? user, bool isLeader) {
    if (user == null) {
      return const SizedBox.shrink(); // أو عرض بطاقة "مستخدم غير موجود"
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isLeader
            ? LinearGradient(
                colors: [
                  const Color(0xFF8B0000).withValues(alpha: 0.2),
                  const Color(0xFF1a1a1a),
                  const Color(0xFFD4AF37).withValues(alpha: 0.15),
                ],
              )
            : null,
        color: isLeader ? null : const Color(0xFF080808),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLeader
              ? const Color(0xFFD4AF37)
              : Colors.white.withAlpha(10),
          width: isLeader ? 2 : 0.8,
        ),
        boxShadow: [
          if (isLeader)
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isLeader ? AppTheme.accentSilverGold : Colors.white54,
                width: 1.5,
              ),
              image: user['profile_image'] != null
                  ? DecorationImage(
                      image: NetworkImage(user['profile_image']),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: user['profile_image'] == null
                  ? const Color(0xFF151515)
                  : null,
            ),
            child: user['profile_image'] == null
                ? const Icon(
                    Icons.person_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'] ?? 'مجهول',
                  style: TextStyle(
                    color: isLeader ? const Color(0xFFD4AF37) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    shadows: isLeader
                        ? [
                            const Shadow(
                              color: Color(0xFFD4AF37),
                              blurRadius: 8,
                            ),
                          ]
                        : null,
                  ),
                ),
                if (isLeader)
                  Text(
                    'سَيِّدُ القَبِيلَة',
                    style: TextStyle(
                      color: AppTheme.accentSilverGold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      shadows: [
                        Shadow(color: AppTheme.accentSilverGold, blurRadius: 8),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (user['id'] == widget.user['id'])
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'أنت',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar() {
    if (_tribe == null) return null;
    final isFull = _members.length >= (_tribe!['max_members'] ?? 12);
    final isPrivate = _tribe!['is_private'] == true;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.black, // أسود
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: SafeArea(
        child: (_isMember || _isLeader)
            ? _buildMemberActions()
            : _buildGuestActions(isFull, isPrivate),
      ),
    );
  }

  Widget _buildMemberActions() {
    return Container(
      width: double.infinity,
      height: 68,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B0000), Color(0xFFFF0000), Color(0xFF8B0000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(34),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0000).withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    TribeChatScreen(tribe: _tribe!, user: widget.user),
              ),
            );
          },
          borderRadius: BorderRadius.circular(34),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'وُلُوجُ مَجْلِسِ القَبِيلَة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontFamily: 'Tajawal',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuestActions(bool isFull, bool isPrivate) {
    if (isFull) {
      return Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_rounded, color: Colors.white38, size: 20),
            SizedBox(width: 8),
            Text(
              'اكْتَمَلَ نِصَابُ الفُرْسَان',
              style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isJoining ? null : _joinTribe,
      child: Container(
        width: double.infinity,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withAlpha(60),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: AppTheme.accentSilverGold,
            width: 2,
          ), // حواف ذهبية
        ),
        child: Center(
          child: _isJoining
              ? const CircularProgressIndicator(color: Colors.black)
              : _buildButtonContent(isPrivate),
        ),
      ),
    );
  }

  Widget _buildButtonContent(bool isPrivate) {
    if (!isPrivate) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.how_to_reg_rounded, color: Colors.black, size: 26),
          const SizedBox(width: 12),
          const Text(
            'الانضمام',
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      );
    }

    // حالات القبيلة الخاصة
    if (_requestStatus == 'pending') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_empty_rounded,
            color: Colors.black54,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Text(
            'طلبك قيد المراجعة...',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    if (_requestStatus == 'rejected') {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.block_flipped, color: Colors.redAccent, size: 24),
          const SizedBox(width: 12),
          const Text(
            'تم رفض طلبك',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.mark_email_unread_rounded,
          color: Colors.black,
          size: 26,
        ),
        const SizedBox(width: 12),
        const Text(
          'إرسال طلب انضمام',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Future<void> _joinTribe() async {
    if (_requestStatus == 'pending') return;

    setState(() => _isJoining = true);
    try {
      final tribeId = widget.tribeId;
      final userId = widget.user['id'];

      await SupabaseService.joinTribe(tribeId, userId);

      if (mounted) {
        final isPrivate = _tribe!['is_private'] == true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isPrivate
                  ? '✅ تم إرسال طلب الانضمام للقائد'
                  : '✅ تم الانضمام للقبيلة بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // تحديث الحالة لعرض الشريط السفلي

        // إذا كانت القبيلة عامة، نقله مباشرة للدردشة لتوفير تجربة سلسة
        if (!isPrivate) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _tribe != null) {
              if (widget.onJoined != null) {
                widget.onJoined!(_tribe!);
              } else {
                // FALLBACK: إذا لم يتم توفير callback، نستخدم الطريقة القديمة
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        TribeChatScreen(tribe: _tribe!, user: widget.user),
                  ),
                );
              }
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('عذراً: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }
}
