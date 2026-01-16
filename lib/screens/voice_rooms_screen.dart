import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import 'voice_room_active_screen.dart';
import 'create_voice_room_screen.dart';
import 'dart:ui';
import 'dart:async'; // ✅ لـ unawaited

class VoiceRoomsScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const VoiceRoomsScreen({super.key, required this.user});

  @override
  State<VoiceRoomsScreen> createState() => _VoiceRoomsScreenState();
}

class _VoiceRoomsScreenState extends State<VoiceRoomsScreen>
    with TickerProviderStateMixin {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _rooms = [];
  bool _isLoading = true;
  RealtimeChannel? _subscription;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _debounceTimer; // ✅ لتقليل التحديثات الزائدة

  @override
  void initState() {
    super.initState();
    _initAnimations();
    // ✅ FIX #8: استخدام unawaited للـ async calls
    unawaited(_cleanupGhostParticipants());
    unawaited(_cleanupEmptyRooms());
    unawaited(_loadRooms());
    _subscribeToRooms();
  }

  Future<void> _cleanupEmptyRooms() async {
    try {
      // حذف الغرف التي مر عليها أكثر من 30 دقيقة ولا يوجد بها مشاركين
      final threshold = DateTime.now()
          .subtract(const Duration(minutes: 30))
          .toIso8601String();

      await _client
          .from('voice_rooms')
          .delete()
          .eq('participants_count', 0)
          .lt('created_at', threshold);

      debugPrint('🧹 Old empty rooms cleaned up');
    } catch (e) {
      debugPrint('⚠️ Error cleaning empty rooms: $e');
    }
  }

  Future<void> _cleanupGhostParticipants() async {
    try {
      // حذف المشاركين الذين لم يرسلوا Heartbeat منذ أكثر من دقيقتين
      final threshold = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toIso8601String();

      await _client
          .from('voice_room_participants')
          .delete()
          .lt('last_seen', threshold);

      debugPrint('🧹 Ghost participants cleaned up');
    } catch (e) {
      debugPrint('⚠️ Error cleaning ghost participants: $e');
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _debounceTimer?.cancel(); // ✅ إلغاء timer
    if (_subscription != null) {
      _client.removeChannel(_subscription!);
      _subscription = null;
    }
    super.dispose();
  }

  Future<void> _loadRooms() async {
    try {
      final response = await _client
          .from('voice_rooms')
          .select('*, users:created_by(id, name, username, profile_image)')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(50); // ✅ تحديد عدد الغرف لتحسين الأداء

      if (mounted) {
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading voice rooms: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToRooms() {
    try {
      _subscription = _client
          .channel('voice_rooms_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'voice_rooms',
            callback: (payload) {
              // ✅ تقليل التحديثات باستخدام debounce
              _debounceTimer?.cancel();
              _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                if (mounted) {
                  debugPrint('🔄 Voice rooms changed, reloading...');
                  _loadRooms();
                }
              });
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('❌ Error subscribing to voice rooms: $e');
    }
  }

  void _createRoom() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateVoiceRoomScreen(user: widget.user),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        // ✅ تم إرجاع بيانات الغرفة → الانضمام مباشرة
        _loadRooms(); // تحديث القائمة
        _joinRoom(result); // الدخول للغرفة
      }
    });
  }

  void _joinRoom(Map<String, dynamic> room) async {
    try {
      // ✅ FIX #12: جلب العداد الحالي من DB (real-time) لمنع race condition
      final freshData = await _client
          .from('voice_rooms')
          .select('participants_count, max_participants, is_private, password')
          .eq('room_name', room['room_name'])
          .single()
          .timeout(const Duration(seconds: 5));

      final currentCount = freshData['participants_count'] as int? ?? 0;
      final maxParticipants = freshData['max_participants'] as int?;
      final isPrivate = freshData['is_private'] == true;
      final roomPassword = freshData['password'] as String?;

      // ✅ التحقق من كلمة السر للغرف الخاصة المحمية
      if (isPrivate && roomPassword != null && roomPassword.trim().isNotEmpty) {
        final enteredPassword = await _showPasswordDialog();

        if (enteredPassword == null) {
          // المستخدم ألغى
          return;
        }

        if (enteredPassword.trim() != roomPassword.trim()) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.lock_rounded, color: Colors.white),
                    SizedBox(width: 12),
                    Text('❌ كلمة السر غير صحيحة'),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          }
          return;
        }
      }

      // التحقق من الحد الأقصى مع البيانات الحديثة
      if (maxParticipants != null && currentCount >= maxParticipants) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.block_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'الغرفة ممتلئة! الحد الأقصى: $maxParticipants مشاركين',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // الانضمام للغرفة
      if (!mounted) return; // ✅ التحقق من mounted قبل استخدام context

      await Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              VoiceRoomActiveScreen(room: room, user: widget.user),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.1),
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
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
      _loadRooms(); // تحديث بعد العودة
    } catch (e) {
      debugPrint('❌ Error joining room: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الانضمام: ${e.toString().contains('timeout') ? 'انتهت المهلة' : 'خطأ في الاتصال'}',
            ),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // تم تفعيل الويب للاختبار ✅
    // ملاحظة: قد يكون هناك مشاكل في الصوت على الويب

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A1A), Color(0xFF0D0D25), Color(0xFF0A0A1A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoadingState()
                    : RefreshIndicator(
                        onRefresh: _loadRooms,
                        color: AppTheme.accentPurple,
                        backgroundColor: const Color(0xFF1A1A2E),
                        child: _rooms.isEmpty
                            ? _buildEmptyState()
                            : _buildRoomsList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildCreateButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // أيقونة مع تأثير توهج
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accentPurple.withAlpha(80),
                  AppTheme.accentViolet.withAlpha(40),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentPurple.withAlpha(60),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.headset_mic_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'الغرف الصوتية',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_rooms.length} غرفة نشطة',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          // زر التحديث
          IconButton(
            onPressed: _loadRooms,
            icon: Icon(
              Icons.refresh_rounded,
              color: Colors.white.withAlpha(180),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentPurple.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              color: AppTheme.accentPurple,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'جاري تحميل الغرف...',
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.15),
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة متحركة
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value * 0.9 + 0.1,
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.accentPurple.withAlpha(40),
                          AppTheme.accentPurple.withAlpha(10),
                          Colors.transparent,
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.record_voice_over_rounded,
                      size: 80,
                      color: AppTheme.accentPurple.withAlpha(180),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'لا توجد غرف نشطة حالياً',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'كن أول من ينشئ غرفة صوتية ويتحدث مع أصدقائه!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              // زر إنشاء غرفة
              GestureDetector(
                onTap: _createRoom,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.accentPurple, AppTheme.accentViolet],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.accentPurple.withAlpha(100),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'إنشاء غرفة جديدة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoomsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const BouncingScrollPhysics(), // ✅ سلاسة أفضل
      cacheExtent: 1000, // ✅ تحسين الأداء
      addAutomaticKeepAlives: true, // ✅ الحفاظ على حالة الـ widgets
      itemCount: _rooms.length,
      itemBuilder: (context, index) {
        final room = _rooms[index];
        // ✅ تبسيط الأنيميشن لتقليل استهلاك المعالج
        return RepaintBoundary(child: _buildRoomCard(room));
      },
    );
  }

  Widget _buildRoomCard(Map<String, dynamic> room) {
    final creator = room['users'] as Map<String, dynamic>?;
    final participantsCount = room['participants_count'] ?? 0;
    final title = room['title'] ?? 'غرفة محادثة';
    final description = room['description'] ?? '';
    final roomColor = _getRoomColor(room['room_color']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  roomColor.withAlpha(40),
                  roomColor.withAlpha(20),
                  Colors.white.withAlpha(8),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: roomColor.withAlpha(80), width: 1.5),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _joinRoom(room),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // العنوان وعدد المشاركين
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // أيقونة الغرفة
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: roomColor.withAlpha(50),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              _getRoomIcon(room['room_icon']),
                              color: roomColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          // العنوان والوصف
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    // 🔒 مؤشر الغرفة الخاصة
                                    if (room['is_private'] == true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.withAlpha(30),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.amber.withAlpha(150),
                                          ),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.lock_rounded,
                                              size: 14,
                                              color: Colors.amber,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                              'خاصة',
                                              style: TextStyle(
                                                color: Colors.amber,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (description.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 13,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // شارة المشاركين
                          _buildParticipantsBadge(
                            participantsCount,
                            maxParticipants: room['max_participants'] as int?,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // المنشئ وزر الانضمام
                      Row(
                        children: [
                          // صورة المنشئ
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: roomColor.withAlpha(80),
                            backgroundImage: creator?['profile_image'] != null
                                ? NetworkImage(creator!['profile_image'])
                                : null,
                            child: creator?['profile_image'] == null
                                ? const Icon(
                                    Icons.person,
                                    size: 14,
                                    color: Colors.white70,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              creator?['name'] ?? 'مستخدم',
                              style: TextStyle(
                                color: Colors.white.withAlpha(180),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          // زر الانضمام
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [roomColor, roomColor.withAlpha(180)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: roomColor.withAlpha(80),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.login_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'انضم',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsBadge(int count, {int? maxParticipants}) {
    final isFull = maxParticipants != null && count >= maxParticipants;
    final badgeColor = isFull ? Colors.red : const Color(0xFF22C55E);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withAlpha(100)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // مؤشر نبض (فقط إذا لم تكن ممتلئة)
          if (!isFull)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: badgeColor.withAlpha(
                        (100 * _pulseAnimation.value).toInt(),
                      ),
                      blurRadius: 6 * _pulseAnimation.value,
                      spreadRadius: 2 * _pulseAnimation.value,
                    ),
                  ],
                ),
              ),
            )
          else
            Icon(Icons.block_rounded, size: 12, color: badgeColor),
          const SizedBox(width: 8),
          // عرض العدد مع الحد الأقصى
          Text(
            maxParticipants != null ? '$count/$maxParticipants' : '$count',
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  /// 🔒 Dialog لطلب كلمة سر الغرفة الخاصة
  Future<String?> _showPasswordDialog() async {
    final controller = TextEditingController();
    bool showPassword = false;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(
              color: AppTheme.accentPurple.withAlpha(80),
              width: 2,
            ),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentPurple.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppTheme.accentPurple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'غرفة محمية',
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'هذه الغرفة محمية بكلمة سر',
                style: TextStyle(
                  color: Colors.white.withAlpha(180),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.accentPurple.withAlpha(60),
                  ),
                ),
                child: TextField(
                  controller: controller,
                  obscureText: !showPassword,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'أدخل كلمة السر',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                    prefixIcon: const Icon(
                      Icons.vpn_key_rounded,
                      color: AppTheme.accentPurple,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.white54,
                      ),
                      onPressed: () =>
                          setState(() => showPassword = !showPassword),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(color: Colors.white.withAlpha(180)),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accentPurple, AppTheme.accentViolet],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    return;
                  }
                  Navigator.pop(context, controller.text.trim());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                ),
                child: const Text(
                  'انضم',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.accentPurple, AppTheme.accentViolet],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPurple.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _createRoom,
        backgroundColor: Colors.transparent,
        elevation: 0,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'غرفة جديدة',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Color _getRoomColor(String? colorName) {
    switch (colorName) {
      case 'purple':
        return AppTheme.accentPurple;
      case 'pink':
        return AppTheme.accentPink;
      case 'cyan':
        return AppTheme.accentCyan;
      case 'green':
        return AppTheme.accentGreen;
      case 'gold':
        return AppTheme.accentGold;
      default:
        return AppTheme.accentPurple;
    }
  }

  IconData _getRoomIcon(String? iconName) {
    switch (iconName) {
      case 'music':
        return Icons.music_note_rounded;
      case 'game':
        return Icons.sports_esports_rounded;
      case 'chat':
        return Icons.chat_rounded;
      case 'study':
        return Icons.school_rounded;
      case 'podcast':
        return Icons.podcasts_rounded;
      default:
        return Icons.headset_mic_rounded;
    }
  }
}
