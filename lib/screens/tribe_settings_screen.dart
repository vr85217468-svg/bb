import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

/// شاشة إعدادات القبيلة - للقائد فقط 👑⚙️
class TribeSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> tribe;
  final Map<String, dynamic> user;

  const TribeSettingsScreen({
    super.key,
    required this.tribe,
    required this.user,
  });

  @override
  State<TribeSettingsScreen> createState() => _TribeSettingsScreenState();
}

class _TribeSettingsScreenState extends State<TribeSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _bannedUsers = [];
  bool _isLoading = true;
  RealtimeChannel? _settingsChannel; // للتحديثات الفورية

  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedIcon = '⚔️';
  bool _isPrivate = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
    _loadData();
    _subscribeToChanges(); // الاستماع للتغييرات
  }

  void _initializeData() {
    _nameController.text = widget.tribe['name'] ?? '';
    _nameEnController.text = widget.tribe['name_en'] ?? '';
    _descriptionController.text = widget.tribe['description'] ?? '';
    _selectedIcon = widget.tribe['icon'] ?? '⚔️';
    _isPrivate = widget.tribe['is_private'] ?? false;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    _settingsChannel?.unsubscribe(); // إلغاء الاشتراك في التحديثات الفورية
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final members = await SupabaseService.getTribeMembers(widget.tribe['id']);
    final requests = await SupabaseService.getPendingRequests(
      widget.tribe['id'],
    );
    final banned = await SupabaseService.getBannedUsers(widget.tribe['id']);

    if (mounted) {
      setState(() {
        _members = members;
        _pendingRequests = requests;
        _bannedUsers = banned;
        _isLoading = false;
      });
    }
  }

  /// الاستماع لتغييرات الأعضاء والطلبات والملكية
  void _subscribeToChanges() {
    final tribeId = widget.tribe['id'];
    final userId = widget.user['id'];

    _settingsChannel = Supabase.instance.client
        .channel('tribe_settings_$tribeId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribe_members',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tribe_id',
            value: tribeId,
          ),
          callback: (payload) async {
            if (!mounted) return;

            // إذا تغير القائد، وأنا لست القائد الجديد، اخرج من الإعدادات
            final isStillLeader = await SupabaseService.isUserLeader(
              tribeId,
              userId,
            );
            if (!isStillLeader && mounted) {
              Navigator.of(context).pop(true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '👑 تم نقل الملكية، لم تعد قائداً لهذه القبيلة',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
              return;
            }

            _loadData(); // تحديث القائمة فوراً
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tribe_bans',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tribe_id',
            value: tribeId,
          ),
          callback: (payload) {
            if (mounted) _loadData(); // تحديث قائمة المحظورين فوراً
          },
        )
        .subscribe();
  }

  Future<void> _updateTribeInfo() async {
    try {
      final updates = {
        'name': _nameController.text.trim(),
        'name_en': _nameEnController.text.trim().isEmpty
            ? null
            : _nameEnController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'icon': _selectedIcon,
        'is_private': _isPrivate,
      };

      final success = await SupabaseService.updateTribe(
        widget.tribe['id'],
        updates,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تحديث معلومات القبيلة'),
            backgroundColor: Color(0xFF00CC33),
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('فشل التحديث');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _kickMemberDialog(Map<String, dynamic> member) async {
    final user = member['user'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: const Row(
          children: [
            Text('⚠️', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Text('طرد عضو', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'هل تريد طرد ${user['name']} من القبيلة؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('طرد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _kickMember(member['user_id']);
    }
  }

  Future<void> _kickMember(String userId) async {
    try {
      debugPrint('⚠️ [UI] Starting kick process for user: $userId');

      // استخدام kickMemberAndBan لطرد + حظر تلقائي
      final success = await SupabaseService.kickMemberAndBan(
        tribeId: widget.tribe['id'],
        userId: userId,
        leaderId: widget.user['id'],
        reason: 'تم الطرد من القبيلة',
      );

      debugPrint('⚠️ [UI] Kick result: $success');

      if (!mounted) return;

      if (success) {
        debugPrint('✅ [UI] Showing success message');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم طرد العضو وإضافته للقائمة السوداء'),
            backgroundColor: Color(0xFF00CC33),
          ),
        );
        debugPrint('🔄 [UI] Reloading data...');
        _loadData();
      } else {
        debugPrint('❌ [UI] Kick failed - success was false');
        throw Exception('فشل الطرد');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [UI] Exception in _kickMember: $e');
      debugPrint('❌ [UI] Stack trace: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _unbanUser(String userId) async {
    try {
      final success = await SupabaseService.unbanUserFromTribe(
        widget.tribe['id'],
        userId,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم فك الحظر'),
            backgroundColor: Color(0xFF00CC33),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _transferLeadershipDialog(Map<String, dynamic> member) async {
    final user = member['user'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: Row(
          children: [
            const Text('👑', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            const Text('نقل الملكية', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل تريد نقل ملكية القبيلة إلى:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFD700)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Color(0xFFFFD700)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      user['name'] ?? 'مستخدم',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سيصبح هذا الشخص القائد الجديد وستصبح أنت عضو عادي',
                      style: TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: const Color(0xFF0A0E27),
            ),
            icon: const Icon(Icons.star, size: 18),
            label: const Text('نقل الملكية'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _transferLeadership(member['user_id']);
    }
  }

  Future<void> _transferLeadership(String newLeaderId) async {
    try {
      final success = await SupabaseService.transferLeadership(
        tribeId: widget.tribe['id'],
        currentLeaderId: widget.user['id'],
        newLeaderId: newLeaderId,
      );

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Text('👑 ', style: TextStyle(fontSize: 20)),
                Expanded(child: Text('تم نقل الملكية بنجاح')),
              ],
            ),
            backgroundColor: Color(0xFF00CC33),
          ),
        );
        // العودة للصفحة الرئيسية
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        throw Exception('فشل نقل الملكية');
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _approveRequest(String requestId) async {
    try {
      final success = await SupabaseService.approveJoinRequest(requestId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم قبول الطلب'),
            backgroundColor: Color(0xFF00CC33),
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectRequest(String requestId) async {
    try {
      final success = await SupabaseService.rejectJoinRequest(requestId);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ تم رفض الطلب'),
            backgroundColor: Colors.orange,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteTribeDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFD4AF37), width: 2),
        ),
        title: const Row(
          children: [
            Text('🚨', style: TextStyle(fontSize: 24)),
            SizedBox(width: 12),
            Text('حذف القبيلة', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'هل أنت متأكد من حذف القبيلة؟\nهذا الإجراء لا يمكن التراجع عنه!',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              'حذف نهائياً',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteTribe();
    }
  }

  Future<void> _deleteTribe() async {
    try {
      final success = await SupabaseService.deleteTribe(widget.tribe['id']);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🗑️ تم حذف القبيلة'),
            backgroundColor: Color(0xFF00CC33),
          ),
        );
        // العودة للصفحة الرئيسية
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B0000).withValues(alpha: 0.3),
                Colors.black,
                const Color(0xFFD4AF37).withValues(alpha: 0.2),
              ],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Text('⚙️', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            const Text(
              'إدارة القبيلة',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFD4AF37),
          indicatorWeight: 3,
          labelColor: const Color(0xFFD4AF37),
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
          isScrollable: true,
          tabs: const [
            Tab(text: '📋 المعلومات'),
            Tab(text: '👥 الأعضاء'),
            Tab(text: '📬 الطلبات'),
            Tab(text: '🚫 المحظورين'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFFD700)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                _buildMembersTab(),
                _buildRequestsTab(),
                _buildBannedTab(),
              ],
            ),
    );
  }

  Widget _buildInfoTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(), // ✅ تمرير سلس
      cacheExtent: 1000, // ✅ تحسين الأداء
      children: [
        // تعديل الاسم
        _buildTextField(
          controller: _nameController,
          label: 'اسم القبيلة (عربي)',
          icon: Icons.edit,
        ),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _nameEnController,
          label: 'الاسم (English) - اختياري',
          icon: Icons.language,
        ),
        const SizedBox(height: 16),

        _buildTextField(
          controller: _descriptionController,
          label: 'الوصف',
          icon: Icons.description,
          maxLines: 3,
        ),
        const SizedBox(height: 24),

        // اختيار الشعار
        const Text(
          'تغيير الشعار',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildIconGrid(),
        const SizedBox(height: 24),

        // نوع القبيلة
        _buildPrivacySwitch(),
        const SizedBox(height: 32),

        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF00CC33), Color(0xFF00FF41)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00CC33).withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _updateTribeInfo,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.save, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text(
                  'حفظ التغييرات',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // زر الحذف
        Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.withValues(alpha: 0.3), Colors.black],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: OutlinedButton(
            onPressed: _deleteTribeDialog,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.transparent,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete_forever, color: Colors.red, size: 24),
                SizedBox(width: 12),
                Text(
                  'حذف القبيلة نهائياً',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMembersTab() {
    // إزالة القائد من القائمة
    final nonLeaderMembers = _members
        .where((m) => m['is_leader'] != true)
        .toList();

    if (nonLeaderMembers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👥', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'لا يوجد أعضاء بعد',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(), // ✅ تمرير سلس
      cacheExtent: 1000, // ✅ تحسين الأداء
      itemCount: nonLeaderMembers.length,
      itemBuilder: (context, index) {
        final member = nonLeaderMembers[index];
        final user = member['user'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF1a1a1a), Colors.black],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                image: user['profile_image'] != null
                    ? DecorationImage(
                        image: NetworkImage(user['profile_image']),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: user['profile_image'] == null
                    ? const Color(0xFF6B5CE7)
                    : null,
              ),
              child: user['profile_image'] == null
                  ? const Icon(Icons.person, color: Colors.white, size: 24)
                  : null,
            ),
            title: Text(
              user['name'] ?? 'مستخدم',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '@${user['username'] ?? ''}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // زر نقل الملكية
                IconButton(
                  icon: const Icon(Icons.star, color: Color(0xFFFFD700)),
                  onPressed: () => _transferLeadershipDialog(member),
                  tooltip: 'نقل الملكية',
                ),
                // زر الطرد
                IconButton(
                  icon: const Icon(Icons.person_remove, color: Colors.red),
                  onPressed: () => _kickMemberDialog(member),
                  tooltip: 'طرد',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📭', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'لا توجد طلبات انضمام',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(), // ✅ تمرير سلس
      cacheExtent: 1000, // ✅ تحسين الأداء
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) {
        final request = _pendingRequests[index];
        final user = request['user'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF8B0000).withValues(alpha: 0.2),
                Colors.black,
                const Color(0xFFD4AF37).withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: user['profile_image'] != null
                        ? DecorationImage(
                            image: NetworkImage(user['profile_image']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: user['profile_image'] == null
                        ? const Color(0xFF6B5CE7)
                        : null,
                  ),
                  child: user['profile_image'] == null
                      ? const Icon(Icons.person, color: Colors.white, size: 24)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'] ?? 'مستخدم',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '@${user['username'] ?? ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => _rejectRequest(request['id']),
                  tooltip: 'رفض',
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.check, color: Color(0xFF00CC33)),
                  onPressed: () => _approveRequest(request['id']),
                  tooltip: 'قبول',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFFD4AF37)),
            filled: true,
            fillColor: const Color(0xFF1a1a1a),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD4AF37), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconGrid() {
    const icons = [
      '⚔️',
      '🛡️',
      '👑',
      '🏰',
      '🐉',
      '🦅',
      '🦁',
      '🐺',
      '🌟',
      '⭐',
      '💫',
      '✨',
      '🔥',
      '⚡',
      '🌙',
      '☀️',
      '🌊',
      '🏔️',
      '🌳',
      '🌹',
      '💎',
      '🎯',
      '🎪',
      '🎭',
      '🎨',
      '📚',
      '⚖️',
      '🕌',
      '🕋',
      '📿',
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a1a),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: icons.length,
        itemBuilder: (context, index) {
          final icon = icons[index];
          final isSelected = icon == _selectedIcon;

          return GestureDetector(
            onTap: () => setState(() => _selectedIcon = icon),
            child: Container(
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [Color(0xFFD4AF37), Color(0xFFFFD700)],
                      )
                    : null,
                color: isSelected ? null : Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFFD4AF37)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 24)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrivacySwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isPrivate
              ? [const Color(0xFF8B0000).withValues(alpha: 0.3), Colors.black]
              : [const Color(0xFF00CC33).withValues(alpha: 0.2), Colors.black],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isPrivate
              ? const Color(0xFFDC143C).withValues(alpha: 0.6)
              : const Color(0xFF00CC33).withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color:
                (_isPrivate ? const Color(0xFFDC143C) : const Color(0xFF00CC33))
                    .withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isPrivate
                    ? [
                        const Color(0xFFDC143C).withValues(alpha: 0.3),
                        const Color(0xFFFF1744).withValues(alpha: 0.2),
                      ]
                    : [
                        const Color(0xFF00CC33).withValues(alpha: 0.3),
                        const Color(0xFF00FF41).withValues(alpha: 0.2),
                      ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isPrivate ? Icons.lock : Icons.public,
              color: _isPrivate
                  ? const Color(0xFFDC143C)
                  : const Color(0xFF00CC33),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isPrivate ? 'قبيلة مقفلة 🔒' : 'قبيلة مفتوحة 🌍',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPrivate
                      ? 'يحتاج الأعضاء موافقتك للانضمام'
                      : 'يمكن لأي شخص الانضمام مباشرة',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
            activeThumbColor: const Color(0xFFDC143C),
            inactiveThumbColor: const Color(0xFF00CC33),
            inactiveTrackColor: const Color(0xFF00CC33).withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildBannedTab() {
    if (_bannedUsers.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✅', style: TextStyle(fontSize: 64)),
            SizedBox(height: 16),
            Text(
              'لا يوجد محظورين',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'جميع الأعضاء مرحب بهم!',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(), // ✅ تمرير سلس
      cacheExtent: 1000, // ✅ تحسين الأداء
      itemCount: _bannedUsers.length,
      itemBuilder: (context, index) {
        final ban = _bannedUsers[index];
        final user = ban['user'];
        final bannedBy = ban['banned_by_user'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.red.withValues(alpha: 0.2), Colors.black],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        image: user['profile_image'] != null
                            ? DecorationImage(
                                image: NetworkImage(user['profile_image']),
                                fit: BoxFit.cover,
                              )
                            : null,
                        color: user['profile_image'] == null
                            ? Colors.red
                            : null,
                      ),
                      child: user['profile_image'] == null
                          ? const Icon(
                              Icons.person,
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
                            user['name'] ?? 'مستخدم',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '@${user['username'] ?? ''}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _unbanUser(ban['user_id']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00CC33),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('فك الحظر'),
                    ),
                  ],
                ),
                if (ban['reason'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'السبب: ${ban['reason']}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (bannedBy != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'تم الحظر بواسطة: ${bannedBy['name']}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
