import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class ExpertManagementScreen extends StatefulWidget {
  const ExpertManagementScreen({super.key});

  @override
  State<ExpertManagementScreen> createState() => _ExpertManagementScreenState();
}

class _ExpertManagementScreenState extends State<ExpertManagementScreen> {
  List<Map<String, dynamic>> _experts = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final experts = await SupabaseService.getAllExperts();
      final users = await SupabaseService.getAllUsers();

      if (mounted) {
        setState(() {
          _experts = experts;
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0a0a),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('إدارة المستشارين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Color(0xFF4CAF50)),
            onPressed: _showAddDialog,
            tooltip: 'إضافة مستشار',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            )
          : _experts.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.question_answer_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'لا يوجد مستشارين',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _showAddDialog,
            icon: const Icon(Icons.add),
            label: const Text('إضافة أول مستشار'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _experts.length,
      itemBuilder: (context, index) => _buildCard(_experts[index]),
    );
  }

  Widget _buildCard(Map<String, dynamic> expert) {
    final displayName = expert['display_name'] ?? 'مستشار';
    final specialization = expert['specialization'] ?? 'عام';
    final bio = expert['bio'] ?? '';
    final isActive = expert['is_active'] ?? true;

    // جلب معلومات المستخدم من الجدول المرتبط
    final userData = expert['users'] as Map<String, dynamic>?;
    final userName = userData?['name'] ?? 'غير معروف';
    final username = userData?['username'] ?? '';
    final profileImage = userData?['profile_image'];

    return Card(
      color: const Color(0xFF1A1A2E),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundColor: isActive ? const Color(0xFF4CAF50) : Colors.grey,
          backgroundImage: profileImage != null && profileImage.isNotEmpty
              ? NetworkImage(profileImage)
              : null,
          child: profileImage == null || profileImage.isEmpty
              ? Text(
                  userName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : null,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            if (username.isNotEmpty)
              Text(
                '@$username',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '📚 $specialization',
              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13),
            ),
            if (bio.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                bio,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          color: const Color(0xFF1A1A2E),
          itemBuilder: (context) => [
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.edit, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('تعديل', style: TextStyle(color: Colors.white)),
                ],
              ),
              onTap: () =>
                  Future.delayed(Duration.zero, () => _showEditDialog(expert)),
            ),
            PopupMenuItem(
              child: const Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف', style: TextStyle(color: Colors.white)),
                ],
              ),
              onTap: () =>
                  Future.delayed(Duration.zero, () => _confirmDelete(expert)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog() async {
    try {
      if (_allUsers.isEmpty) await _loadData();

      final currentExpertIds = _experts.map((e) => e['user_id']).toSet();
      final available = _allUsers
          .where((u) => !currentExpertIds.contains(u['id']))
          .toList();

      if (available.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جميع المستخدمين مستشارين بالفعل'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      String? selectedId = available[0]['id'];
      final nameCtrl = TextEditingController();
      final specCtrl = TextEditingController();
      final bioCtrl = TextEditingController();

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A1A2E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'إضافة مستشار',
                style: TextStyle(color: Colors.white),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      dropdownColor: const Color(0xFF1A1A2E),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'المستخدم',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      items: available
                          .map<DropdownMenuItem<String>>(
                            (u) => DropdownMenuItem<String>(
                              value: u['id'],
                              child: Text(
                                '${u['name'] ?? 'بدون اسم'} (@${u['username'] ?? 'unknown'})',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        setDialogState(() {
                          selectedId = v;
                          final selectedUser = available.firstWhere(
                            (u) => u['id'] == v,
                          );
                          nameCtrl.text =
                              selectedUser['name'] ??
                              selectedUser['username'] ??
                              '';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'الاسم المعروض *',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: specCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'التخصص',
                        labelStyle: TextStyle(color: Colors.white70),
                        hintText: 'مثال: مستشار تربوي',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: bioCtrl,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'النبذة / الوصف الشخصي',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedId == null || nameCtrl.text.trim().isEmpty) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('الرجاء ملء الحقول المطلوبة'),
                          ),
                        );
                      }
                      return;
                    }

                    if (ctx.mounted) Navigator.pop(ctx);

                    final success = await SupabaseService.addExpert(
                      userId: selectedId!,
                      displayName: nameCtrl.text.trim(),
                      bio: bioCtrl.text.trim(),
                      specialization: specCtrl.text.trim(),
                      orderIndex: 0,
                    );

                    if (!mounted) return;
                    await _loadData();
                    if (!mounted || !context.mounted) return;

                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ تم الإضافة بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('❌ فشل في إضافة المستشار'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                  ),
                  child: const Text('إضافة'),
                ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showEditDialog(Map<String, dynamic> expert) async {
    final nameCtrl = TextEditingController(text: expert['display_name']);
    final specCtrl = TextEditingController(text: expert['specialization']);
    final bioCtrl = TextEditingController(text: expert['bio']);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تعديل مستشار',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الاسم',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: specCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'التخصص',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: bioCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'النبذة',
                labelStyle: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await SupabaseService.updateExpert(
                expertId: expert['id'],
                displayName: nameCtrl.text.trim(),
                bio: bioCtrl.text.trim(),
                specialization: specCtrl.text.trim(),
              );
              if (!mounted) return;
              await _loadData();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? '✅ تم التحديث' : '❌ فشل'),
                  backgroundColor: success ? Colors.green : Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> expert) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل تريد حذف "${expert['display_name']}"؟',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final success = await SupabaseService.deleteExpert(expert['id']);
      if (!mounted) return;
      await _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ تم الحذف' : '❌ فشل'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }
}
