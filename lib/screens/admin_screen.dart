import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'category_editor_screen.dart';
import 'quiz_admin_screen.dart';
import 'support_conversations_tab.dart';
import 'notifications_tab.dart';
import 'expert_management_screen.dart';
import '../services/quiz_data_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _dailyTips = [];
  List<Map<String, dynamic>> _tribes = []; // للقبائل الجديدة
  bool _isLoading = true;
  late TabController _tabController;
  String _currentAppName = ''; // اسم التطبيق الحالي

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'القرآن', 'icon': 'book'},
    {'name': 'أذكار الصباح', 'icon': 'wb_sunny'},
    {'name': 'أذكار المساء', 'icon': 'nights_stay'},
    {'name': 'المسجد', 'icon': 'mosque'},
    {'name': 'الحرمين', 'icon': 'favorite'},
    {'name': 'التسبيح', 'icon': 'pan_tool'},
    {'name': 'النوم', 'icon': 'bedtime'},
    {'name': 'الدعاء', 'icon': 'star'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 9, vsync: this); // عدد التبويبات 9
    _religiousQuestions = QuizDataService.generateAllQuestions()..shuffle();
    _loadData();
    _loadAppName(); // تحميل اسم التطبيق
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAppName() async {
    final name = await SupabaseService.getAppName();
    if (mounted) {
      setState(() {
        _currentAppName = name;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await SupabaseService.getAllUsers();
    final categories = await SupabaseService.getAdhkarCategories();
    final tips = await SupabaseService.getDailyTips();
    final tribes = await SupabaseService.getAllTribesForAdmin(); // جلب القبائل
    if (mounted) {
      setState(() {
        _users = users;
        _categories = categories;
        _dailyTips = tips;
        _tribes = tribes; // تخزين القبائل
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBan(String userId, bool currentlyBanned) async {
    final success = currentlyBanned
        ? await SupabaseService.unbanUser(userId)
        : await SupabaseService.banUser(userId);

    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyBanned
                  ? 'تم إلغاء حظر المستخدم بنجاح'
                  : 'تم حظر المستخدم بنجاح',
            ),
            backgroundColor: currentlyBanned ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleChatBan(String userId, bool currentlyChatBanned) async {
    final success = currentlyChatBanned
        ? await SupabaseService.chatUnbanUser(userId)
        : await SupabaseService.chatBanUser(userId);

    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlyChatBanned
                  ? 'تم إلغاء حظر المحادثة للمستخدم'
                  : 'تم حظر المستخدم من المحادثة',
            ),
            backgroundColor: currentlyChatBanned ? Colors.green : Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    String selectedIcon = 'star';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'إضافة فئة جديدة',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اسم الفئة',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'اختر الأيقونة:',
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.map((item) {
                  final isSelected = selectedIcon == item['icon'];
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = item['icon']),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        _getIconData(item['icon']),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  final result = await SupabaseService.addAdhkarCategory(
                    name: nameController.text.trim(),
                    icon: selectedIcon,
                  );
                  if (result != null) {
                    await _loadData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تمت الإضافة بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(String categoryId) async {
    final success = await SupabaseService.deleteAdhkarCategory(categoryId);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الفئة'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final nameController = TextEditingController(text: category['name'] ?? '');
    String selectedIcon = category['icon'] ?? 'star';

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (dialogContext) {
        String dialogIcon = selectedIcon;
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            backgroundColor: const Color(0xFF1a1a2e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'تعديل الفئة',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'اسم الفئة',
                    hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'اختيار الأيقونة:',
                  style: TextStyle(color: Colors.white.withAlpha(150)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.map((item) {
                    final isSelected = dialogIcon == item['icon'];
                    return GestureDetector(
                      onTap: () => setState(() => dialogIcon = item['icon']),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF6366F1)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          _getIconData(item['icon']),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: Text(
                  'إلغاء',
                  style: TextStyle(color: Colors.white.withAlpha(150)),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    Navigator.pop(dialogContext, {
                      'name': nameController.text.trim(),
                      'icon': dialogIcon,
                    });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    if (result != null) {
      final success = await SupabaseService.updateAdhkarCategory(
        category['id'],
        name: result['name'],
        icon: result['icon'],
      );
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث الفئة بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل في تحديث الفئة'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'book':
        return Icons.menu_book;
      case 'wb_sunny':
        return Icons.wb_sunny;
      case 'nights_stay':
        return Icons.nights_stay;
      case 'mosque':
        return Icons.mosque;
      case 'favorite':
        return Icons.favorite;
      case 'pan_tool':
        return Icons.pan_tool;
      case 'bedtime':
        return Icons.bedtime;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black,
              const Color(0xFF0a0a0a),
              const Color(0xFF8B0000).withValues(alpha: 0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildUsersList(),
                          _buildCategoriesList(),
                          _buildQuizzesTab(),
                          _buildDailyTipsTab(),
                          _buildTribesManagementTab(),
                          const SupportConversationsTab(),
                          const NotificationsTab(),
                          const ExpertManagementScreen(),
                          _buildSettingsTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF8B0000), Color(0xFFD4AF37)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  blurRadius: 15,
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'لوحة الإدارة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.refresh, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF1a1a1a), const Color(0xFF0a0a0a)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B0000), Color(0xFFD4AF37)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
              blurRadius: 10,
            ),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white.withAlpha(150),
        dividerColor: Colors.transparent,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
        tabs: const [
          Tab(text: 'المستخدمين', icon: Icon(Icons.people, size: 20)),
          Tab(text: 'الفئات', icon: Icon(Icons.category, size: 20)),
          Tab(text: 'الأسئلة', icon: Icon(Icons.quiz, size: 20)),
          Tab(text: 'الشارات', icon: Icon(Icons.tips_and_updates, size: 20)),
          Tab(text: 'القبائل', icon: Icon(Icons.groups, size: 20)),
          Tab(
            text: 'الأسئلة الذكية',
            icon: Icon(Icons.support_agent, size: 20),
          ),
          Tab(text: 'الإشعارات', icon: Icon(Icons.notifications, size: 20)),
          Tab(text: 'المستشارين', icon: Icon(Icons.question_answer, size: 20)),
          Tab(text: 'الإعدادات', icon: Icon(Icons.settings, size: 20)),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.white.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد مستخدمين حالياً',
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 18,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      itemBuilder: (context, index) => _buildUserCard(_users[index]),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isBanned = user['is_banned'] == true;
    final isChatBanned = user['is_chat_banned'] == true;
    final profileImage = user['profile_image'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a1a1a),
            Colors.black,
            isBanned
                ? const Color(0xFF8B0000).withValues(alpha: 0.2)
                : const Color(0xFFD4AF37).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isBanned
              ? const Color(0xFFFF0000).withValues(alpha: 0.5)
              : const Color(0xFFD4AF37).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isBanned
                ? const Color(0xFFFF0000).withValues(alpha: 0.2)
                : const Color(0xFFD4AF37).withValues(alpha: 0.1),
            blurRadius: 10,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [const Color(0xFF1a1a1a), Colors.black],
                ),
                border: Border.all(
                  color: isBanned
                      ? const Color(0xFFFF0000)
                      : const Color(0xFFD4AF37),
                  width: 2,
                ),
                image: profileImage != null
                    ? DecorationImage(
                        image: NetworkImage(profileImage),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profileImage == null
                  ? Icon(
                      Icons.person,
                      color: Colors.white.withAlpha(150),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['name'] ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isBanned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(50),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'محظور',
                            style: TextStyle(color: Colors.red, fontSize: 10),
                          ),
                        ),
                      if (isChatBanned && !isBanned) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(50),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'كتم',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    '@${user['username'] ?? ''}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.lock,
                        size: 12,
                        color: Colors.amber.withAlpha(150),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        user['password'] ?? '',
                        style: TextStyle(
                          color: Colors.amber.withAlpha(200),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              children: [
                GestureDetector(
                  onTap: () => _toggleBan(user['id'], isBanned),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isBanned
                          ? const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF10B981)],
                            )
                          : const LinearGradient(
                              colors: [Color(0xFF8B0000), Color(0xFFFF0000)],
                            ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: isBanned
                              ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                              : const Color(0xFFFF0000).withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      isBanned ? 'إلغاء الحظر' : 'حظر',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () => _toggleChatBan(user['id'], isChatBanned),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: isChatBanned
                          ? const LinearGradient(
                              colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                            )
                          : LinearGradient(
                              colors: [
                                Colors.orange.shade600,
                                Colors.orange.shade800,
                              ],
                            ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isChatBanned ? Icons.volume_up : Icons.volume_off,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isChatBanned ? 'إلغاء الكتم' : 'كتم',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: _addCategory,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B0000), Color(0xFFD4AF37)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'إضافة فئة جديدة',
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
        ),
        Expanded(
          child: _categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 80,
                        color: Colors.white.withAlpha(50),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد فئات حالياً',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) =>
                      _buildCategoryCard(_categories[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getIconData(category['icon'] ?? 'star'),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          category['name'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.amber),
              onPressed: () => _editCategory(category),
            ),
            IconButton(
              icon: const Icon(Icons.folder_open, color: Color(0xFF6366F1)),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryEditorScreen(category: category),
                ),
              ).then((_) => _loadData()),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteCategory(category['id']),
            ),
          ],
        ),
      ),
    );
  }

  // مصدر الأسئلة الدينية (قاعدة بيانات مدمجة)
  late final List<String> _religiousQuestions;

  // إعدادات جلب الأسئلة الذكية
  final Set<int> _usedQuestionIndices = {};

  Widget _buildQuizzesTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // فئات الاختبارات المتاحة
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // زر إضافة سؤال يدوي جديد
                  GestureDetector(
                    onTap: _showFullQuestionFlow,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withAlpha(150),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, color: Colors.white, size: 50),
                          SizedBox(height: 8),
                          Text(
                            'إضافة يدوية',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // زر مساعد الأسئلة الذكي (البوت)
                  GestureDetector(
                    onTap: _showQuizBotFlow,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF059669), Color(0xFF10B981)],
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF059669).withAlpha(150),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('🤖', style: TextStyle(fontSize: 40)),
                          SizedBox(height: 8),
                          Text(
                            'بوت الأسئلة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'يمكنك إدارة الأسئلة والأذكار بشكل متقدم من هنا',
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 40),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const QuizAdminScreen()),
                ).then((_) => _loadData()),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(30)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.folder_open, color: Color(0xFF6366F1)),
                      SizedBox(width: 12),
                      Text(
                        'إدارة الأسئلة والاختبارات',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// دالة لبدء جلسة البوت الذكي لتوليد الأسئلة بشكل آلي
  void _showQuizBotFlow() async {
    // تبدأ جلسة المساعد الذكي - اختيار عدد الأسئلة
    // قائمة الأسئلة الدينية المتاحة
    final remainingCount =
        _religiousQuestions.length - _usedQuestionIndices.length;

    if (remainingCount <= 0) {
      if (!mounted) return;
      // عرض ديالوج اكتمال جميع الأسئلة
      final reset = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Text('🎓', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'اكتملت جميع الأسئلة!',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Text(
            'لقد قمت بعرض كافة الأسئلة الـ ${_religiousQuestions.length} المتاحة.\n\nهل تريد إعادة ضبط السجل للبدء من جديد؟',
            style: TextStyle(color: Colors.white.withAlpha(200)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'إعادة ضبط',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (reset == true) {
        _usedQuestionIndices.clear();
      } else {
        return;
      }
    }

    if (!mounted) return;
    // سحب عدد الأسئلة من المستخدم
    final questionCount = await _showQuestionCountDialog(
      remainingCount: _religiousQuestions.length - _usedQuestionIndices.length,
      startingFrom: _usedQuestionIndices.length + 1,
    );
    if (questionCount == null || questionCount <= 0) return;

    // التأكد من وجود فئات اختبارات (على غرار _showFullQuestionFlow)
    var categories = await SupabaseService.getQuizCategories();

    if (categories.isEmpty) {
      if (!mounted) return;
      final newCategory = await _showCreateCategoryDialog();
      if (newCategory == null) return;
      categories = await SupabaseService.getQuizCategories();
      if (categories.isEmpty) return;
    }

    if (!mounted) return;
    final selectedCategory = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('??', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Text(
                    'اختر فئة السؤال',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length + 1,
                itemBuilder: (context, index) {
                  if (index == categories.length) {
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Colors.green),
                      ),
                      title: const Text(
                        '+ إضافة فئة جديدة',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () =>
                          Navigator.pop(context, {'_create_new': true}),
                    );
                  }
                  final cat = categories[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder, color: Color(0xFF059669)),
                    ),
                    title: Text(
                      cat['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (selectedCategory == null) return;

    Map<String, dynamic> finalCategory = selectedCategory;
    if (selectedCategory['_create_new'] == true) {
      if (!mounted) return;
      final newCategory = await _showCreateCategoryDialog();
      if (newCategory == null) return;
      finalCategory = newCategory;
    }

    var quizzes = await SupabaseService.getQuizzes(finalCategory['id']);

    if (quizzes.isEmpty) {
      if (!mounted) return;
      final newQuiz = await _showCreateQuizDialog(finalCategory);
      if (newQuiz == null) return;
      quizzes = await SupabaseService.getQuizzes(finalCategory['id']);
      if (quizzes.isEmpty) return;
    }

    if (!mounted) return;
    final selectedQuiz = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('??', style: TextStyle(fontSize: 24)),
                  SizedBox(width: 10),
                  Text(
                    'اختر الاختبار',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: quizzes.length + 1,
                itemBuilder: (context, index) {
                  if (index == quizzes.length) {
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Colors.green),
                      ),
                      title: const Text(
                        '+ إنشاء اختبار جديد',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () =>
                          Navigator.pop(context, {'_create_new': true}),
                    );
                  }
                  final quiz = quizzes[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.assignment,
                        color: Color(0xFF059669),
                      ),
                    ),
                    title: Text(
                      quiz['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, quiz),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (selectedQuiz == null) return;

    Map<String, dynamic> finalQuiz = selectedQuiz;
    if (selectedQuiz['_create_new'] == true) {
      if (!mounted) return;
      final newQuiz = await _showCreateQuizDialog(finalCategory);
      if (newQuiz == null) return;
      finalQuiz = newQuiz;
    }

    // بدء جلسة البوت مع الفئة والاختبار المختارين
    if (!mounted) return;
    await _startBotSession(finalQuiz, maxQuestions: questionCount);
  }

  /// دالة لسؤال المستخدم عن عدد الأسئلة
  Future<int?> _showQuestionCountDialog({
    required int remainingCount,
    required int startingFrom,
  }) async {
    int selectedCount = remainingCount > 10 ? 10 : remainingCount;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Text('⚙️', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Text(
                'إعدادات الجلسة',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // معلومات الجلسة
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF059669).withAlpha(100),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.play_arrow, color: Color(0xFF10B981)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'نبدأ من السؤال رقم $startingFrom',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'المتبقي $remainingCount سؤالاً متاحاً',
                          style: TextStyle(
                            color: Colors.white.withAlpha(150),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'ما هو عدد الأسئلة لهذه الجلسة؟',
                style: TextStyle(color: Colors.white.withAlpha(200)),
              ),
              const SizedBox(height: 16),
              // اختيار العدد بسرعة
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [5, 10, 20, 50, remainingCount]
                    .where((n) => n <= remainingCount && n > 0)
                    .fold<List<int>>([], (list, n) {
                      if (!list.contains(n)) list.add(n);
                      return list;
                    })
                    .map((count) {
                      final isSelected = selectedCount == count;
                      return GestureDetector(
                        onTap: () => setState(() => selectedCount = count),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF059669),
                                      Color(0xFF10B981),
                                    ],
                                  )
                                : null,
                            color: !isSelected
                                ? Colors.white.withAlpha(15)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.white.withAlpha(30),
                            ),
                          ),
                          child: Text(
                            count == remainingCount
                                ? 'الكل ($count)'
                                : '$count',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withAlpha(180),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 16),
              // شريط اختيار العدد
              if (remainingCount > 5) ...[
                Slider(
                  value: selectedCount.toDouble(),
                  min: 1,
                  max: remainingCount.toDouble(),
                  divisions: remainingCount - 1 > 0 ? remainingCount - 1 : 1,
                  activeColor: const Color(0xFF10B981),
                  inactiveColor: Colors.white.withAlpha(30),
                  label: '$selectedCount',
                  onChanged: (value) =>
                      setState(() => selectedCount = value.round()),
                ),
                Text(
                  'عدد الأسئلة المختارة: $selectedCount',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إلغاء',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, selectedCount),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
              label: Text(
                'بدء ($selectedCount)',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// دالة لتحديد نوع السؤال
  Future<String?> _showQuestionTypeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('🤔', style: TextStyle(fontSize: 28)),
            SizedBox(width: 12),
            Text(
              'تحديد نوع السؤال',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'كيف تريد توليد هذا السؤال؟',
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            // خيار صح/خطأ
            _buildTypeOption(
              context: context,
              icon: '✅',
              label: 'صح أم خطأ',
              description: 'تخمين ذكي للإجابة',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.pop(context, 'true_false'),
            ),
            const SizedBox(height: 12),
            // خيار اختيارات متعددة
            _buildTypeOption(
              context: context,
              icon: '📝',
              label: 'اختيارات متعددة',
              description: 'توليد خيارات ذكية',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.pop(context, 'multiple_choice'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white54)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required BuildContext context,
    required String icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withAlpha(30), color.withAlpha(10)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(100)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  /// جلسة البوت - سحب الأسئلة واحداً تلو الآخر
  Future<void> _startBotSession(
    Map<String, dynamic> quiz, {
    int? maxQuestions,
  }) async {
    int questionNumber = _usedQuestionIndices.length + 1;
    int addedCount = 0;
    final targetCount = maxQuestions ?? _religiousQuestions.length;

    while (mounted) {
      // الحصول على السؤال الديني التالي
      final questionData = _getNextQuestion();
      if (questionData == null) {
        // إنهاء الجلسة بنجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ تم بنجاح إضافة $addedCount سؤالاً! اكتملت جميع الأسئلة المتاحة.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      }

      final questionIndex = questionData['index'] as int;
      final questionText = questionData['text'] as String;

      if (!mounted) break;

      // سؤال المستخدم عن نوع السؤال المولد
      final selectedType = await _showQuestionTypeDialog();
      if (selectedType == null) {
        // إنهاء الجلسة - تم الحفظ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم حفظ $addedCount سؤالاً بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      }

      if (!mounted) break;

      // تأخير بسيط لمحاكاة التفكير والتحميل عند بدء السؤال
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) break;

      final result = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (context) => _BotQuestionSheet(
          questionNumber: questionNumber,
          questionText: questionText,
          totalQuestions: _religiousQuestions.length,
          remainingQuestions:
              _religiousQuestions.length - _usedQuestionIndices.length,
          sessionRemaining: targetCount - addedCount,
          preselectedType: selectedType, // النمط المختار من السحب
        ),
      );

      if (result == null) {
        // تخطي السؤال الحالي - إغلاق الجلسة أو العودة
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ تم حفظ $addedCount سؤالاً بنجاح!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        break;
      }

      // حفظ السؤال (في حال تم الضغط على الحفظ في الورقة)
      final saved = await SupabaseService.addQuizQuestion(
        quizId: quiz['id'],
        question: result['question'], // النص المعدل من الورقة
        questionType: result['type'],
        correctAnswer: result['correctAnswer'],
        options: result['options'],
        timerSeconds: result['timerSeconds'], // توقيت السؤال إن وُجد
      );

      if (saved != null) {
        // نجاح الحفظ - تم إضافة سؤال - تحديث فهارس البحث
        _usedQuestionIndices.add(questionIndex);
        addedCount++;
        questionNumber++;

        // التحقق من الوصول للعدد المطلوب
        if (addedCount >= targetCount) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ تم إضافة $addedCount سؤال بنجاح!'),
                backgroundColor: Colors.green,
              ),
            );
          }
          break;
        }
      } else {
        // فشل الإضافة - عرض خطأ
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ فشل جلب السؤال! يرجى المحاولة مرة أخرى.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        // الانتقال للسؤال التالي من القائمة المقترحة (في التحديث القادم)
      }
    }
  }

  /// الحصول على السؤال التالي من القائمة
  /// يعيد Map يحتوي على السؤال و index - أو null إذا انتهت الأسئلة
  Map<String, dynamic>? _getNextQuestion() {
    if (_usedQuestionIndices.length >= _religiousQuestions.length) {
      return null; // انتهت جميع الأسئلة
    }

    // البحث عن أول سؤال غير مستخدم
    for (int i = 0; i < _religiousQuestions.length; i++) {
      if (!_usedQuestionIndices.contains(i)) {
        // تم العثور على سؤال - يعيده مع رقم الترتيب الأصلي
        return {'index': i, 'text': _religiousQuestions[i]};
      }
    }
    return null;
  }

  /// إظهار حوار إنشاء الفئة
  Future<Map<String, dynamic>?> _showCreateCategoryDialog() async {
    final nameController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.folder_special, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('إنشاء فئة', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'مثال: السيرة النبوية',
            hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
            filled: true,
            fillColor: Colors.white.withAlpha(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('إنشاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return null;

    final newCategory = await SupabaseService.addQuizCategory(name: result);
    if (newCategory != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة "$result" بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return newCategory;
  }

  /// إنشاء اختبار جديد في فئة معينة
  Future<Map<String, dynamic>?> _showCreateQuizDialog(
    Map<String, dynamic> category,
  ) async {
    final titleController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.assignment, color: Colors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'اختبار جديد',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  Text(
                    'في ${category['name']}',
                    style: TextStyle(
                      color: Colors.white.withAlpha(100),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: TextField(
          controller: titleController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'مثال: غزوة بدر',
            hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
            filled: true,
            fillColor: Colors.white.withAlpha(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(context, titleController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('إنشاء', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == null) return null;

    final newQuiz = await SupabaseService.addQuiz(
      categoryId: category['id'],
      title: result,
    );
    if (newQuiz != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إضافة "$result" بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
    return newQuiz;
  }

  void _showFullQuestionFlow() async {
    var categories = await SupabaseService.getQuizCategories();

    // التأكد من وجود فئات عند البدء بإنشاء الأسئلة
    if (categories.isEmpty) {
      if (!mounted) return;
      final newCategory = await _showCreateCategoryDialog();
      if (newCategory == null) return;
      categories = await SupabaseService.getQuizCategories();
      if (categories.isEmpty) return;
    }

    if (!mounted) return;
    final selectedCategory = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'اختر الفئة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: categories.length + 1, // +1 for "add new" button
                itemBuilder: (context, index) {
                  if (index == categories.length) {
                    // زر إضافة فئة جديدة
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Colors.green),
                      ),
                      title: const Text(
                        '+ إضافة فئة جديدة',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () =>
                          Navigator.pop(context, {'_create_new': true}),
                    );
                  }
                  final cat = categories[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.folder, color: Color(0xFF6366F1)),
                    ),
                    title: Text(
                      cat['name'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, cat),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (selectedCategory == null) return;

    // جلب الاختبارات للفئة المختارة
    Map<String, dynamic> finalCategory = selectedCategory;
    if (selectedCategory['_create_new'] == true) {
      if (!mounted) return;
      final newCategory = await _showCreateCategoryDialog();
      if (newCategory == null) return;
      finalCategory = newCategory;
    }

    var quizzes = await SupabaseService.getQuizzes(finalCategory['id']);

    // التأكد من وجود اختبارات عند البدء بإنشاء الأسئلة في الفئة
    if (quizzes.isEmpty) {
      if (!mounted) return;
      final newQuiz = await _showCreateQuizDialog(finalCategory);
      if (newQuiz == null) return;
      quizzes = await SupabaseService.getQuizzes(finalCategory['id']);
      if (quizzes.isEmpty) return;
    }

    if (!mounted) return;
    final selectedQuiz = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'اختر الاختبار',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: quizzes.length + 1, // +1 for "add new" button
                itemBuilder: (context, index) {
                  if (index == quizzes.length) {
                    // زر إضافة اختبار جديد
                    return ListTile(
                      leading: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.green.withAlpha(50),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.add, color: Colors.green),
                      ),
                      title: const Text(
                        '+ إضافة اختبار جديد',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onTap: () =>
                          Navigator.pop(context, {'_create_new': true}),
                    );
                  }
                  final quiz = quizzes[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.green.withAlpha(50),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.assignment, color: Colors.green),
                    ),
                    title: Text(
                      quiz['title'] ?? '',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, quiz),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (selectedQuiz == null) return;

    // جلب الأسئلة للاختبار المختار
    Map<String, dynamic> finalQuiz = selectedQuiz;
    if (selectedQuiz['_create_new'] == true) {
      if (!mounted) return;
      final newQuiz = await _showCreateQuizDialog(finalCategory);
      if (newQuiz == null) return;
      finalQuiz = newQuiz;
    }

    if (!mounted) return;
    final questionType = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(50),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'تحديد نوع السؤال',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.purple.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.list, color: Colors.purple),
              ),
              title: const Text(
                'سؤال اختيارات',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                '4 خيارات A B C D',
                style: TextStyle(color: Colors.white.withAlpha(100)),
              ),
              onTap: () => Navigator.pop(context, 'multiple_choice'),
            ),
            ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(50),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.check_circle, color: Colors.amber),
              ),
              title: const Text(
                'سؤال صح / خطأ',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: Text(
                'صح أو خطأ مباشر',
                style: TextStyle(color: Colors.white.withAlpha(100)),
              ),
              onTap: () => Navigator.pop(context, 'true_false'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
    if (questionType == null) return;

    _showQuestionInputSheet(questionType, finalQuiz);
  }

  void _showQuestionInputSheet(String questionType, Map<String, dynamic> quiz) {
    final questionController = TextEditingController();
    final option1Controller = TextEditingController();
    final option2Controller = TextEditingController();
    final option3Controller = TextEditingController();
    final option4Controller = TextEditingController();
    int selectedOption = 0;
    bool trueFalseAnswer = true;
    bool withTimer = false;
    int timerSeconds = 30;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(50),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            questionType == 'multiple_choice'
                                ? 'سؤال الخيارات'
                                : 'سؤال صح/خطأ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '?? ${quiz['title']}',
                            style: TextStyle(
                              color: Colors.white.withAlpha(150),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'نص السؤال',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withAlpha(30)),
                        ),
                        child: TextField(
                          controller: questionController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'اكتب نص السؤال هنا...',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(80),
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (questionType == 'multiple_choice') ...[
                        const Text(
                          'الخيارات المتاحة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildOptionCard(
                          0,
                          option1Controller,
                          'A',
                          const Color(0xFFEF4444),
                          selectedOption == 0,
                          () => setModalState(() => selectedOption = 0),
                        ),
                        _buildOptionCard(
                          1,
                          option2Controller,
                          'B',
                          const Color(0xFF3B82F6),
                          selectedOption == 1,
                          () => setModalState(() => selectedOption = 1),
                        ),
                        _buildOptionCard(
                          2,
                          option3Controller,
                          'C',
                          const Color(0xFF22C55E),
                          selectedOption == 2,
                          () => setModalState(() => selectedOption = 2),
                        ),
                        _buildOptionCard(
                          3,
                          option4Controller,
                          'D',
                          const Color(0xFFF59E0B),
                          selectedOption == 3,
                          () => setModalState(() => selectedOption = 3),
                        ),
                      ] else ...[
                        const Text(
                          'حدد الإجابة الصحيحة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTFCard(
                                true,
                                trueFalseAnswer,
                                () =>
                                    setModalState(() => trueFalseAnswer = true),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildTFCard(
                                false,
                                !trueFalseAnswer,
                                () => setModalState(
                                  () => trueFalseAnswer = false,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // إعدادات المؤقت
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(10),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withAlpha(30)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.timer,
                                      color: Colors.amber,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'تفعيل المؤقت',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                SwitchTheme(
                                  data: SwitchThemeData(
                                    thumbColor: WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return Colors.amber;
                                        }
                                        return null;
                                      },
                                    ),
                                    trackColor: WidgetStateProperty.resolveWith(
                                      (states) {
                                        if (states.contains(
                                          WidgetState.selected,
                                        )) {
                                          return Colors.amber.withAlpha(100);
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  child: Switch(
                                    value: withTimer,
                                    onChanged: (value) =>
                                        setModalState(() => withTimer = value),
                                  ),
                                ),
                              ],
                            ),
                            if (withTimer) ...[
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '5 ث',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                    ),
                                  ),
                                  Text(
                                    '$timerSeconds ثانية',
                                    style: const TextStyle(
                                      color: Colors.amber,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '60 ث',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: Colors.amber,
                                  inactiveTrackColor: Colors.white.withAlpha(
                                    30,
                                  ),
                                  thumbColor: Colors.amber,
                                ),
                                child: Slider(
                                  value: timerSeconds.toDouble(),
                                  min: 5,
                                  max: 60,
                                  divisions: 11,
                                  onChanged: (value) => setModalState(
                                    () => timerSeconds = value.toInt(),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.all(20),
                child: GestureDetector(
                  onTap: () async {
                    if (questionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يرجى إدخال نص السؤال'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    if (questionType == 'multiple_choice' &&
                        (option1Controller.text.trim().isEmpty ||
                            option2Controller.text.trim().isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('يجب إدخال خيارين على الأقل'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }
                    List<String>? options;
                    String correctAnswer;
                    if (questionType == 'multiple_choice') {
                      options = [
                        option1Controller.text.trim(),
                        option2Controller.text.trim(),
                      ];
                      if (option3Controller.text.trim().isNotEmpty) {
                        options.add(option3Controller.text.trim());
                      }
                      if (option4Controller.text.trim().isNotEmpty) {
                        options.add(option4Controller.text.trim());
                      }

                      correctAnswer =
                          '${selectedOption < options.length ? selectedOption : 0}';
                    } else {
                      correctAnswer = trueFalseAnswer ? 'true' : 'false';
                    }
                    final result = await SupabaseService.addQuizQuestion(
                      quizId: quiz['id'],
                      question: questionController.text.trim(),
                      questionType: questionType,
                      correctAnswer: correctAnswer,
                      options: options,
                      hasTimer: withTimer,
                      timerSeconds: withTimer ? timerSeconds : null,
                    );

                    if (!context.mounted) return;
                    Navigator.pop(context);
                    if (result != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم إضافة السؤال بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'حفظ السؤال',
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    int i,
    TextEditingController c,
    String l,
    Color clr,
    bool sel,
    VoidCallback tap,
  ) {
    return GestureDetector(
      onTap: tap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: sel ? Colors.green.withAlpha(30) : Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: sel ? Colors.green : Colors.white.withAlpha(30),
            width: sel ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: sel
                      ? [Colors.green, Colors.green.shade700]
                      : [clr, clr.withAlpha(200)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: sel
                    ? const Icon(Icons.check, color: Colors.white)
                    : Text(
                        l,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            Expanded(
              child: TextField(
                controller: c,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'الخيار $l',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(60)),
                  border: InputBorder.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTFCard(bool isTrue, bool sel, VoidCallback tap) {
    final clr = isTrue ? Colors.green : Colors.red;
    return GestureDetector(
      onTap: tap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          gradient: sel
              ? LinearGradient(colors: [clr.withAlpha(100), clr.withAlpha(50)])
              : null,
          color: sel ? null : Colors.white.withAlpha(15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? clr : Colors.white.withAlpha(30),
            width: sel ? 3 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isTrue ? Icons.check_circle : Icons.cancel,
              color: sel ? clr : Colors.white.withAlpha(100),
              size: 40,
            ),
            const SizedBox(height: 8),
            Text(
              isTrue ? 'صح' : 'خطأ',
              style: TextStyle(
                color: sel ? clr : Colors.white.withAlpha(100),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== إدارة النصائح اليومية ====================

  Widget _buildDailyTipsTab() {
    return Column(
      children: [
        // زر إضافة نصيحة جديدة
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: _showAddTipDialog,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB8860B), Color(0xFFDAA520)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFB8860B).withAlpha(75),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.tips_and_updates, color: Colors.white, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'إضافة نصيحة دينية',
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
        ),
        // قائمة النصائح
        Expanded(
          child: _dailyTips.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 80,
                        color: Colors.white.withAlpha(50),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد نصائح مضافة حالياً',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _dailyTips.length,
                  itemBuilder: (context, index) =>
                      _buildTipCard(_dailyTips[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildTipCard(Map<String, dynamic> tip) {
    final isActive = tip['is_active'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [
                  const Color(0xFFB8860B).withAlpha(40),
                  const Color(0xFFDAA520).withAlpha(20),
                ]
              : [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? const Color(0xFFB8860B)
              : Colors.white.withAlpha(30),
          width: isActive ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // الأيقونة
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFB8860B).withAlpha(30)
                    : Colors.white.withAlpha(15),
                shape: BoxShape.circle,
              ),
              child: Text(
                tip['emoji'] ?? '✨',
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 12),
            // النص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isActive)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFB8860B).withAlpha(50),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🌟 نصيحة اليوم',
                        style: TextStyle(
                          color: Color(0xFFDAA520),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  Text(
                    tip['tip'] ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // الإجراءات
            Column(
              children: [
                // زر التفعيل
                GestureDetector(
                  onTap: () => _setActiveTip(tip['id']),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isActive
                          ? const Color(0xFFB8860B).withAlpha(50)
                          : Colors.green.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isActive ? Icons.star : Icons.star_border,
                      color: isActive ? const Color(0xFFDAA520) : Colors.green,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // زر التعديل
                GestureDetector(
                  onTap: () => _showEditTipDialog(tip),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit,
                      color: Color(0xFF6366F1),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // زر الحذف
                GestureDetector(
                  onTap: () => _deleteTip(tip['id']),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(30),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddTipDialog() {
    final emojiController = TextEditingController(text: '??');
    final tipController = TextEditingController();
    bool isActive = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'إضافة نصيحة دينية',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // اختيار الأيقونة
              TextField(
                controller: emojiController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 32),
                decoration: InputDecoration(
                  labelText: 'الرمز (إيموجي)',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // نص النصيحة
              TextField(
                controller: tipController,
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'نص النصيحة',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
                  hintText: 'اكتب النصيحة هنا...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // تفعيل النصيحة
              GestureDetector(
                onTap: () => setState(() => isActive = !isActive),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? const Color(0xFFB8860B).withAlpha(30)
                        : Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? const Color(0xFFB8860B)
                          : Colors.white.withAlpha(30),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.star : Icons.star_border,
                        color: isActive
                            ? const Color(0xFFDAA520)
                            : Colors.white.withAlpha(150),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'تعيين كنصيحة اليوم',
                        style: TextStyle(
                          color: isActive
                              ? const Color(0xFFDAA520)
                              : Colors.white.withAlpha(150),
                        ),
                      ),
                    ],
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
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (tipController.text.trim().isNotEmpty) {
                  Navigator.pop(context);
                  final result = await SupabaseService.addDailyTip(
                    emoji: emojiController.text.trim().isEmpty
                        ? '✨'
                        : emojiController.text.trim(),
                    tip: tipController.text.trim(),
                    isActive: isActive,
                  );
                  if (result != null) {
                    await _loadData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تفعيل النصيحة بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB8860B),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTipDialog(Map<String, dynamic> tip) {
    final emojiController = TextEditingController(text: tip['emoji'] ?? '✨');
    final tipController = TextEditingController(text: tip['tip'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'تعديل النصيحة',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emojiController,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 32),
              decoration: InputDecoration(
                labelText: 'الأيقونة',
                labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tipController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'نص النصيحة',
                labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
                filled: true,
                fillColor: Colors.white.withAlpha(15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
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
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (tipController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                final success = await SupabaseService.updateDailyTip(
                  tip['id'],
                  emoji: emojiController.text.trim(),
                  tip: tipController.text.trim(),
                );
                if (success) {
                  await _loadData();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ تم تحديث النصيحة'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _setActiveTip(String tipId) async {
    final success = await SupabaseService.setActiveTip(tipId);
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تفعيل النصيحة'),
            backgroundColor: Color(0xFFB8860B),
          ),
        );
      }
    }
  }

  Future<void> _deleteTip(String tipId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف النصيحة', style: TextStyle(color: Colors.white)),
        content: const Text(
          'هل أنت متأكد من حذف هذه النصيحة؟',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await SupabaseService.deleteDailyTip(tipId);
      if (success) {
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم حذف النصيحة'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  // ==================== Settings Tab ====================

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الإعدادات العامة
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF6366F1).withAlpha(30),
                  const Color(0xFF8B5CF6).withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF6366F1).withAlpha(50)),
            ),
            child: const Row(
              children: [
                Icon(Icons.settings, color: Color(0xFF6366F1), size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الإعدادات وكلمة المرور',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'إدارة كل ما يتعلق بالأمان والوصول',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // بطاقة إدارة اسم التطبيق (جديدة)
          _buildAppNameCard(),
          const SizedBox(height: 16),

          // بطاقة وضع الصيانة
          _buildMaintenanceCard(),
          const SizedBox(height: 16),

          // بطاقة إدارة كلمة المرور
          _buildAdminPasswordCard(),
        ],
      ),
    );
  }

  // متغيرات حالة الصيانة
  bool _isMaintenanceEnabled = false;
  String _maintenanceMessage = '';
  List<String> _excludedUserIds = [];

  Widget _buildMaintenanceCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: SupabaseService.getMaintenanceSettings(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFFF6B35).withAlpha(30),
                  const Color(0xFFFF8C42).withAlpha(20),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFFF6B35).withAlpha(50)),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final settings = snapshot.data;
        _isMaintenanceEnabled = settings?['is_enabled'] == true;
        _maintenanceMessage =
            settings?['message'] ?? 'التطبيق تحت الصيانة حالياً';
        _excludedUserIds = List<String>.from(
          settings?['excluded_user_ids'] ?? [],
        );

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _isMaintenanceEnabled
                    ? const Color(0xFFFF6B35).withAlpha(40)
                    : const Color(0xFF1a1a2e).withAlpha(200),
                _isMaintenanceEnabled
                    ? const Color(0xFFFF8C42).withAlpha(30)
                    : const Color(0xFF16213e).withAlpha(150),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isMaintenanceEnabled
                  ? const Color(0xFFFF6B35).withAlpha(80)
                  : const Color(0xFFD4AF37).withAlpha(50),
              width: _isMaintenanceEnabled ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isMaintenanceEnabled
                            ? [const Color(0xFFFF6B35), const Color(0xFFFF8C42)]
                            : [
                                const Color(0xFF6366F1),
                                const Color(0xFF8B5CF6),
                              ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _isMaintenanceEnabled
                          ? Icons.build
                          : Icons.build_outlined,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'وضع الصيانة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'تعطيل التطبيق لجميع المستخدمين',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isMaintenanceEnabled,
                    onChanged: (value) => _toggleMaintenance(value),
                    activeTrackColor: const Color(0xFFFF6B35).withAlpha(100),
                    activeThumbColor: const Color(0xFFFF6B35),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.grey.withAlpha(50),
                  ),
                ],
              ),
              if (_isMaintenanceEnabled) ...[
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const SizedBox(height: 16),
                // رسالة الصيانة
                Row(
                  children: [
                    const Icon(Icons.message, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'رسالة الصيانة:',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showEditMaintenanceMessageDialog,
                      icon: const Icon(
                        Icons.edit,
                        size: 16,
                        color: Color(0xFFFF6B35),
                      ),
                      label: const Text(
                        'تعديل',
                        style: TextStyle(color: Color(0xFFFF6B35)),
                      ),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _maintenanceMessage,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 16),
                // المستخدمين المستثنين
                Row(
                  children: [
                    const Icon(Icons.people, color: Colors.white70, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'المستثنين (${_excludedUserIds.length}):',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showSelectExcludedUsersDialog,
                      icon: const Icon(
                        Icons.add,
                        size: 16,
                        color: Color(0xFF4CAF50),
                      ),
                      label: const Text(
                        'إدارة',
                        style: TextStyle(color: Color(0xFF4CAF50)),
                      ),
                    ),
                  ],
                ),
                if (_excludedUserIds.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_excludedUserIds.length} مستخدم مستثنى من الصيانة',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _toggleMaintenance(bool enabled) async {
    // إضافة المشرف الحالي تلقائياً للمستثنين عند التفعيل
    List<String> updatedExcludedIds = List<String>.from(_excludedUserIds);
    final currentUserId = SupabaseService.getCurrentUserId();
    if (enabled &&
        currentUserId != null &&
        !updatedExcludedIds.contains(currentUserId)) {
      updatedExcludedIds.add(currentUserId);
    }

    final success = await SupabaseService.updateMaintenanceSettings(
      isEnabled: enabled,
      message: _maintenanceMessage.isEmpty
          ? 'التطبيق تحت الصيانة حالياً'
          : _maintenanceMessage,
      excludedUserIds: updatedExcludedIds,
    );
    if (success && mounted) {
      setState(() {
        _isMaintenanceEnabled = enabled;
        _excludedUserIds = updatedExcludedIds;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            enabled
                ? '✅ تم تفعيل وضع الصيانة (تم استثناء حسابك تلقائياً)'
                : '✅ تم إلغاء وضع الصيانة',
          ),
          backgroundColor: enabled ? Colors.orange : Colors.green,
        ),
      );
    }
  }

  Future<void> _showEditMaintenanceMessageDialog() async {
    final controller = TextEditingController(text: _maintenanceMessage);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        title: const Text(
          'تعديل رسالة الصيانة',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'أدخل رسالة الصيانة',
            hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
            filled: true,
            fillColor: Colors.white.withAlpha(15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final success = await SupabaseService.updateMaintenanceSettings(
        isEnabled: _isMaintenanceEnabled,
        message: result,
        excludedUserIds: _excludedUserIds,
      );
      if (success && mounted) setState(() => _maintenanceMessage = result);
    }
  }

  Future<void> _showSelectExcludedUsersDialog() async {
    final users = await SupabaseService.getUsersForExclusion();
    if (!mounted) return;

    final selectedIds = List<String>.from(_excludedUserIds);

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          title: const Text(
            'اختيار المستخدمين المستثنين',
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                final isSelected = selectedIds.contains(user['id']);
                return CheckboxListTile(
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedIds.add(user['id']);
                      } else {
                        selectedIds.remove(user['id']);
                      }
                    });
                  },
                  title: Text(
                    user['name'] ?? '',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '@${user['username'] ?? ''}',
                    style: TextStyle(color: Colors.white.withAlpha(150)),
                  ),
                  secondary: CircleAvatar(
                    backgroundImage: user['profile_image'] != null
                        ? NetworkImage(user['profile_image'])
                        : null,
                    child: user['profile_image'] == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  activeColor: const Color(0xFF4CAF50),
                  checkColor: Colors.white,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () async {
                final success = await SupabaseService.updateMaintenanceSettings(
                  isEnabled: _isMaintenanceEnabled,
                  message: _maintenanceMessage,
                  excludedUserIds: selectedIds,
                );
                if (success && mounted) {
                  setState(() => _excludedUserIds = selectedIds);
                }
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
              ),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppNameCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1a1a2e).withAlpha(200),
            const Color(0xFF16213e).withAlpha(150),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4AF37).withAlpha(80),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B0000), Color(0xFFD4AF37)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.app_settings_alt,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اسم التطبيق',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'تعديل اسم التطبيق الظاهر لجميع المستخدمين',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // الاسم الحالي
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(20)),
            ),
            child: Row(
              children: [
                Icon(Icons.label, color: Colors.amber.withAlpha(200), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'الاسم الحالي:',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentAppName.isEmpty
                            ? 'جاري التحميل...'
                            : _currentAppName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // زر التعديل
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showChangeAppNameDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'تعديل اسم التطبيق',
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
        ],
      ),
    );
  }

  Future<void> _showChangeAppNameDialog() async {
    final nameController = TextEditingController(text: _currentAppName);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // العنوان
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B0000), Color(0xFFD4AF37)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.app_settings_alt,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'تعديل اسم التطبيق',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // حقل الاسم الجديد
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'الاسم الجديد للتطبيق',
                  labelStyle: TextStyle(color: Colors.white.withAlpha(150)),
                  prefixIcon: Icon(
                    Icons.label,
                    color: Colors.amber.withAlpha(200),
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withAlpha(30)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // الأزرار
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(
                        'إلغاء',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () async {
                        final newName = nameController.text.trim();

                        if (newName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('الرجاء إدخال اسم التطبيق'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        // تحديث الاسم بدون طلب كلمة مرور
                        final success =
                            await SupabaseService.updateAppNameDirect(
                              newName: newName,
                            );

                        if (success) {
                          // تحديث الاسم محلياً
                          setState(() {
                            _currentAppName = newName;
                          });

                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم تحديث اسم التطبيق بنجاح ✅'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('فشل التحديث - حاول مرة أخرى'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'حفظ التغييرات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminPasswordCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(15), Colors.white.withAlpha(8)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.key, color: Colors.amber, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تأمين لوحة التحكم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ضمان حماية اللوحة من الوصول غير المصرح',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // زر عرض كلمة المرور الحالية
          GestureDetector(
            onTap: _showCurrentPassword,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(20)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.visibility, color: Colors.white70, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'عرض كلمة المرور الحالية',
                    style: TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // زر تغيير كلمة المرور
          GestureDetector(
            onTap: _showChangePasswordDialog,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withAlpha(50),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.edit, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'تغيير كود الدخول',
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
        ],
      ),
    );
  }

  Future<void> _showCurrentPassword() async {
    // جاري تنفيذ العملية
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF6366F1)),
      ),
    );

    // جلب كلمة المرور من قاعدة البيانات
    final password = await SupabaseService.getAdminPassword();

    if (!mounted) return;
    Navigator.pop(context); // إغلاق مؤشر التحميل

    if (password != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.key, color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Text(
                'كلمة المرور الحالية',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withAlpha(50)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, color: Colors.amber, size: 20),
                const SizedBox(width: 12),
                Text(
                  password,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'إغلاق',
                style: TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر العثور على كلمة مرور الأدمن الحالية'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1a1a2e),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF6366F1), size: 28),
              SizedBox(width: 12),
              Text('تغيير كلمة المرور', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // حقل كلمة المرور الجديدة
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'كلمة المرور الجديدة',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.key, color: Color(0xFF6366F1)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white60,
                    ),
                    onPressed: () => setState(() => obscureNew = !obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // حقل تأكيد كلمة المرور
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'تأكيد كلمة المرور',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.check, color: Color(0xFF6366F1)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility : Icons.visibility_off,
                      color: Colors.white60,
                    ),
                    onPressed: () =>
                        setState(() => obscureConfirm = !obscureConfirm),
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
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      // التحقق من المدخلات
                      if (newPasswordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى إدخال كلمة المرور الجديدة'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      if (newPasswordController.text !=
                          confirmPasswordController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('كلمتا المرور غير متطابقتين'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      if (newPasswordController.text.length < 4) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'يجب أن لا يقل طول كلمة المرور عن 4 أحرف',
                            ),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      setState(() => isLoading = true);

                      final success = await SupabaseService.updateAdminPassword(
                        newPasswordController.text,
                      );

                      setState(() => isLoading = false);

                      if (!context.mounted) return;

                      if (success) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('تم تحديث كلمة المرور بنجاح'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'فشل في تحديث كلمة المرور، يرجى المحاولة لاحقاً',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('تحديث', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // TRIBE MANAGEMENT TAB
  // ============================================

  Widget _buildTribesManagementTab() {
    if (_tribes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.groups_outlined, size: 80, color: Colors.white38),
            const SizedBox(height: 16),
            const Text(
              'لا توجد قبائل حالياً',
              style: TextStyle(fontSize: 18, color: Colors.white70),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _tribes.length,
      itemBuilder: (context, index) => _buildTribeCard(_tribes[index]),
    );
  }

  Widget _buildTribeCard(Map<String, dynamic> tribe) {
    final leader = tribe['leader'] as Map?;
    final memberCount = tribe['member_count'] ?? 0;
    final maxMembers = tribe['max_members'] ?? 12;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF1a1a1a),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: const Color(0xFFD4AF37).withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  tribe['icon'] ?? '🕋',
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tribe['name'] ?? 'بدون اسم',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'كود القبيلة: ${tribe['tribe_code']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'القائد: ${leader?['name'] ?? 'بدون قائد'}',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const Spacer(),
                const Icon(Icons.group, size: 18, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  'الأعضاء: $memberCount/$maxMembers',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showTransferOwnershipDialog(tribe),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('تحويل الملكية'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _confirmDeleteTribe(tribe),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('حذف القبيلة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showTransferOwnershipDialog(Map<String, dynamic> tribe) async {
    final members = await SupabaseService.getTribeMembersForAdmin(tribe['id']);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.swap_horiz, color: Color(0xFFD4AF37)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تحويل ملكية ${tribe['name']}',
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: members.isEmpty
              ? const Text(
                  'لا يوجد أعضاء في هذه القبيلة',
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final user = member['user'] as Map?;
                    final isLeader = member['is_leader'] == true;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: user?['profile_image'] != null
                            ? NetworkImage(user!['profile_image'])
                            : null,
                        child: user?['profile_image'] == null
                            ? Text(user?['name']?.substring(0, 1) ?? '?')
                            : null,
                      ),
                      title: Text(
                        user?['name'] ?? 'مستخدم',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        isLeader ? 'القائد الحالي' : '@${user?['username']}',
                        style: TextStyle(
                          color: isLeader
                              ? const Color(0xFFD4AF37)
                              : Colors.white54,
                        ),
                      ),
                      enabled: !isLeader,
                      onTap: isLeader
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _executeTransferOwnership(
                                tribe['id'],
                                tribe['leader_id'],
                                member['user_id'],
                              );
                            },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  Future<void> _executeTransferOwnership(
    String tribeId,
    String oldLeaderId,
    String newLeaderId,
  ) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await SupabaseService.transferTribeOwnership(
      tribeId: tribeId,
      oldLeaderId: oldLeaderId,
      newLeaderId: newLeaderId,
    );

    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم تحويل الملكية بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ فشل تحويل الملكية'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _confirmDeleteTribe(Map<String, dynamic> tribe) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a1a),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('حذف القبيلة', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف قبيلة "${tribe['name']}"؟',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'سيؤدي هذا إلى:',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Text(
              '• حذف الأعضاء (${tribe['member_count']})',
              style: const TextStyle(color: Colors.red),
            ),
            const Text(
              '• حذف كل المحادثات',
              style: TextStyle(color: Colors.red),
            ),
            const Text(
              '• حذف البيانات المرتبطة',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Text(
                '⚠️ هذا الإجراء نهائي ولا يمكن التراجع عنه!',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('نعم، احذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeDeleteTribe(tribe['id']);
    }
  }

  Future<void> _executeDeleteTribe(String tribeId) async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final success = await SupabaseService.deleteTribeCompletely(tribeId);

    if (!mounted) return;
    Navigator.pop(context);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ تم حذف القبيلة بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
      _loadData();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ فشل حذف القبيلة'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class _BotQuestionSheet extends StatefulWidget {
  final int questionNumber;
  final String questionText;
  final int totalQuestions;
  final int remainingQuestions;
  final int sessionRemaining; // الأسئلة المتبقية في هذه الجلسة
  final String preselectedType; // نوع السؤال المختار مبدئياً

  const _BotQuestionSheet({
    required this.questionNumber,
    required this.questionText,
    required this.totalQuestions,
    required this.remainingQuestions,
    required this.sessionRemaining,
    required this.preselectedType,
  });

  @override
  State<_BotQuestionSheet> createState() => _BotQuestionSheetState();
}

class _BotQuestionSheetState extends State<_BotQuestionSheet> {
  late String _selectedType; // اختيار نوع السؤال في السحب
  bool? _trueFalseAnswer; // تخزين الإجابة الصحيحة
  late TextEditingController _questionController; // المتحكم في نص السؤال
  final List<TextEditingController> _optionControllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  int _correctOptionIndex = -1; // مؤشر الخيار الصحيح المختار
  // ignore: prefer_final_fields
  bool _isSaving = false;

  // إعدادات ومؤقت السؤال لبوت الذكاء
  bool _hasTimer = false;
  int _timerSeconds = 30;

  @override
  void initState() {
    super.initState();
    // تهيئة الـ controller وتعبئة السؤال المقترح
    _questionController = TextEditingController(text: widget.questionText);

    // استنتاج الخيارات والمقترحات بناءً على نص السؤال الحالي
    _selectedType = widget.preselectedType;

    // البدء بمحاولة استنتاج الخيارات تلقائياً عند الدخول في وضع الاختيارات المتعددة
    if (_selectedType == 'multiple_choice') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _suggestOptions();
        }
      });
    } else if (_selectedType == 'true_false') {
      // البدء في محاولة تخمين نمط صح/خطأ لبدء الجلسة بشكل أسرع وأذكى
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _suggestTrueFalseAnswer();
        }
      });
    }
  }

  // دالة للتبديل السريع بين أنواع الأسئلة (تبديل النمط)
  void _switchQuestionType() {
    if (_selectedType == 'true_false') {
      // التحويل من نمط صح/خطأ إلى اختيارات متعددة (استخراج الفراغ)
      _convertToMultipleChoice();
    } else {
      // التحويل من نمط الاختيارات إلى صح/خطأ (دمج الإجابة للسؤال)
      _convertToTrueFalse();
    }

    if (mounted) {
      setState(() {});
    }
  }

  // منطق التحويل من صح/خطأ إلى اختيارات متعددة
  void _convertToMultipleChoice() {
    String questionText = _questionController.text.trim();

    // استخراج الخيارات الذكية من الجملة بناءً على القواميس المتاحة
    Map<String, List<String>> smartOptions = _extractOptionsFromQuestion(
      questionText,
    );

    if (smartOptions['correct']!.isNotEmpty) {
      String correctAnswer = smartOptions['correct']!.first;
      List<String> wrongAnswers = smartOptions['wrong']!;

      // دمج الخيارات الصحيحة والخاطئة وترتيبها عشوائياً لمحاكاة الاختبار الحقيقي
      List<String> allOptions = [correctAnswer, ...wrongAnswers.take(3)];
      allOptions.shuffle();

      // تعبئة المتحكمات (Controllers) بالخيارات المولدة
      for (int i = 0; i < 4; i++) {
        if (i < allOptions.length) {
          _optionControllers[i].text = allOptions[i];
          if (allOptions[i] == correctAnswer) {
            _correctOptionIndex = i;
          }
        } else {
          _optionControllers[i].clear();
        }
      }

      // تحويل الجملة الخبرية إلى سؤال بوضع فراغ مكان الإجابة (...)
      _questionController.text = _convertToQuestionFormat(
        questionText,
        correctAnswer,
      );
      _selectedType = 'multiple_choice';
      _trueFalseAnswer = null;
    } else {
      // في حال تعذر الاستنتاج المباشر نلجأ للدالة العامة _suggestOptions لمحاولة العثور على أنماط أخرى
      _selectedType = 'multiple_choice';
      _trueFalseAnswer = null;
      _suggestOptions();
    }
  }

  // منطق التحويل من اختيارات متعددة إلى صح/خطأ
  void _convertToTrueFalse() {
    // أخذ الخيار المحدد كإجابة صحيحة ودمجه داخل نص السؤال الأصلي لجعل الجملة مكتملة
    if (_correctOptionIndex >= 0 && _correctOptionIndex < 4) {
      String correctAnswer = _optionControllers[_correctOptionIndex].text
          .trim();
      String questionText = _questionController.text.trim();

      if (correctAnswer.isNotEmpty) {
        // دمج السؤال مع الإجابة المختارة ليصبح جملة خبرية صحيحة
        String statement = _combineQuestionWithAnswer(
          questionText,
          correctAnswer,
        );
        _questionController.text = statement;
      }
    }

    _selectedType = 'true_false';
    _correctOptionIndex = -1;

    // تحديث الأسئلة صح/خطأ تلقائياً
    _suggestTrueFalseAnswer();
  }

  // دمج السؤال مع الإجابة لتحويله لجملة خبرية
  String _combineQuestionWithAnswer(String question, String answer) {
    // استبدال علامات الاستفهام و "..."
    String statement = question
        .replaceAll('؟', '')
        .replaceAll('؟', '')
        .replaceAll('...', answer)
        .replaceAll('___', answer)
        .trim();

    // التأكد من وجود الإجابة داخل الجملة أو إضافتها في النهاية
    if (!statement.contains(answer)) {
      statement = '$question $answer';
    }

    return statement;
  }

  // تحويل الجملة إلى صيغة سؤال (بتوليد الفراغات)
  String _convertToQuestionFormat(String statement, String answer) {
    // المحاولة الأولى: استبدال مباشر
    if (statement.contains(answer)) {
      return statement.replaceFirst(answer, '...');
    }

    // المحاولة الثانية: استنتاج الفراغات بناءً على الأنماط
    final patterns = [
      RegExp(r'(\d+\s+[\u0600-\u06FF]+)'), // رقم + كلمة
      RegExp(r'([\u0600-\u06FF]+\s+\S+)'), // كلمة + أي شيء
    ];

    for (var pattern in patterns) {
      if (pattern.hasMatch(statement)) {
        return statement.replaceFirst(pattern, '...');
      }
    }

    return '$statement؟';
  }

  // استخراج الخيارات بناءً على نص السؤال
  Map<String, List<String>> _extractOptionsFromQuestion(String text) {
    String correct = '';
    List<String> wrong = [];

    // البحث عن الأنبياء
    final prophets = [
      'محمد',
      'موسى',
      'عيسى',
      'إبراهيم',
      'نوح',
      'هود',
      'لوط',
      'صالح',
      'شعيب',
    ];
    for (var prophet in prophets) {
      if (text.contains(prophet)) {
        correct = prophet;
        wrong = prophets.where((p) => p != prophet).take(3).toList();
        break;
      }
    }

    // البحث عن السور
    if (correct.isEmpty) {
      final surahs = [
        'الفاتحة',
        'البقرة',
        'آل عمران',
        'النساء',
        'المائدة',
        'طه',
        'يس',
        'الكهف',
      ];
      for (var surah in surahs) {
        if (text.contains(surah)) {
          correct = surah;
          wrong = surahs.where((s) => s != surah).take(3).toList();
          break;
        }
      }
    }

    // البحث عن الألقاب
    if (correct.isEmpty) {
      final titles = [
        'خاتم الأنبياء',
        'كليم الله',
        'الفاروق',
        'الصديق',
        'ذو النورين',
        'أسد الله',
      ];
      for (var title in titles) {
        if (text.contains(title)) {
          correct = title;
          wrong = titles.where((t) => t != title).take(3).toList();
          break;
        }
      }
    }

    // البحث عن الأماكن
    if (correct.isEmpty) {
      final places = [
        'مكة',
        'المدينة',
        'القدس',
        'جبل أحد',
        'جبل ثور',
        'بدر',
        'أحد',
      ];
      for (var place in places) {
        if (text.contains(place)) {
          correct = place;
          wrong = places.where((p) => p != place).take(3).toList();
          break;
        }
      }
    }

    // البحث عن الأرقام
    if (correct.isEmpty) {
      final numMatch = RegExp(r'(\d+)').firstMatch(text);
      if (numMatch != null) {
        int num = int.parse(numMatch.group(1)!);
        correct = '$num';
        wrong = ['${num + 1}', '${num - 1}', '${num + 3}'];
      }
    }

    return {
      'correct': correct.isNotEmpty ? [correct] : [],
      'wrong': wrong,
    };
  }

  // دالة ذكية لتوليد إجابة صح/خطأ
  void _suggestTrueFalseAnswer() {
    String originalText = _questionController.text.trim();

    // حدد نوع الإجابة: 50% صح و 50% خطأ (بشكل ثابت لهذه الجملة)
    final shouldBeFalse = originalText.hashCode % 2 == 1;

    if (shouldBeFalse) {
      // في حال اختيار خطأ يتم تحويل الجملة للجملة الخاطئة
      String transformedText = _transformToFalse(originalText);

      if (transformedText != originalText) {
        // في حال نجاح التحويل
        _questionController.text = transformedText;
        _trueFalseAnswer = false;
      } else {
        // في حال الفشل في التحويل يتم جعل الإجابة صحيحة
        _trueFalseAnswer = true;
      }
    } else {
      // في الوضع الطبيعي الإجابة صح (نسخة من الجملة الأصلية)
      _trueFalseAnswer = true;
    }

    if (mounted) {
      setState(() {});
    }
  }

  // دالة منطقية لتحويل الجملة الخبرية إلى جملة خاطئة
  String _transformToFalse(String text) {
    String result = text;

    // 1. تغيير الأرقام (تواريخ أو أعداد)
    final numberPattern = RegExp(r'(\d+)');
    if (numberPattern.hasMatch(result)) {
      result = result.replaceFirstMapped(numberPattern, (match) {
        int num = int.parse(match.group(1)!);
        // تغيير الرقم لقيمة منطقية أخرى
        if (num == 1) return '3';
        if (num == 2) return '4';
        if (num == 3) return '5';
        if (num == 4) return '2';
        if (num == 5) return '3';
        if (num == 7) return '9';
        if (num == 12) return '10';
        if (num == 114) return '112';
        if (num <= 10) return '${num + 2}';
        return '${num - 3}';
      });
      if (result != text) return result;
    }

    // Default fallback
    return text;
  }

  // دالة لاستنتاج الفراغ وتوليد الخيارات بناءً على نص السؤال
  void _suggestOptions() {
    String text = _questionController.text.trim();
    String answer = '';
    String question = text;

    // 0. تجنب العمل إذا كان نص السؤال يحتوي بالفعل على فراغ (...)
    if (text.contains('...')) {
      return;
    }

    // 1. المحاولة باستخدام الكلمات الشائعة لتقسيم الجملة
    final splitters = [
      ' من ',
      ' في ',
      ' هو ',
      ' كان ',
      ' ولد ',
      ' لقب ',
      ' تزوج ',
      ' توفي ',
      ' هاجر ',
      ' عام ',
      ' عاصمة ',
      ' ملك ',
      ' قال ',
      ' صحابي ',
      ' نبي الله ',
      ' رسول الله ',
      ' الخليفة ',
      ' الملك ',
    ];

    for (var splitter in splitters) {
      if (text.contains(splitter)) {
        var parts = text.split(splitter);
        if (parts.length > 1) {
          question = '${parts[0]}$splitter...';
          answer = parts.last.trim();
          break;
        }
      }
    }

    // 2. محاولة البحث عن أرقام لتحويلها لفراغات
    if (answer.isEmpty) {
      final numberMatch = RegExp(r'(.*)\s(\d+)\s?(.*)$').firstMatch(text);
      if (numberMatch != null) {
        question = '${numberMatch.group(1)} ... ${numberMatch.group(3)}'.trim();
        if (question.endsWith('...')) {
          question = '${question.substring(0, question.length - 3).trim()}...';
        } else if (!question.contains('...')) {
          question = '${numberMatch.group(1)} ...';
        }

        answer = '${numberMatch.group(2)} ${numberMatch.group(3)}'.trim();
      }
    }

    // 3. المحاولة الأخيرة: جعل الفراغ في آخر كلمة
    if (answer.isEmpty && text.contains(' ')) {
      int lastSpace = text.lastIndexOf(' ');
      question = '${text.substring(0, lastSpace)}...';
      answer = text.substring(lastSpace + 1).trim();
    }

    if (answer.isNotEmpty) {
      // تحديث نص السؤال في الـ controller وتوليد الخيارات تلقائياً
      _questionController.text = question;

      // استنتاج خيارات خاطئة (Distractors)
      List<String> distractors = [];

      // --- جلب الخيارات المقترحة ---
      if (text.contains('سورة') &&
          (text.contains('آية') || text.contains('جزء'))) {
        distractors = [
          'الفاتحة',
          'البقرة',
          'الإخلاص',
          'يس',
          'الكوثر',
          'الناس',
          'آل عمران',
          'النساء',
        ];
      } else if (text.contains('نبي') || text.contains('رسول')) {
        distractors = [
          'إنسان صالح',
          'رجل من الصالحين',
          'ملك من الملوك',
          'شخصية تاريخية',
          'بطل قديم',
          'أحد الحكماء',
          'تابعي جليل',
        ];
      } else if (text.contains('صلاة') || text.contains('عبادة')) {
        distractors = [
          'صيام',
          'حج',
          'زكاة',
          'بر الوالدين',
          'إماطة الأذى',
          'نحر',
          'صدقة',
          'الرحلة المباركة',
          'العمرة',
        ];
      } else if (text.contains('رقم') || text.contains('عدد')) {
        distractors = ['114', '30', '1', '2', '0', '3', '15', '7'];
      } else if (text.contains('خلق') || text.contains('صفة')) {
        distractors = [
          'حب المساكين',
          'إغاثة الملهوف',
          'الصدق في الحديث',
          'العدل في الحكم',
          'الأمانة',
          'الشجاعة',
          'التواضع',
          'الكرم',
        ];
      } else if (text.contains('لقب') || text.contains('كنية')) {
        distractors = [
          'الفاروق',
          'الصديق',
          'ذو النورين',
          'أسد الله',
          'سيف الله',
          'أمين هذه الأمة',
          'حواري الرسول',
          'باب العلم',
        ];
      } else if (text.contains('رسول الله') ||
          text.contains('نبي الله') ||
          text.contains('خليل الله')) {
        distractors = [
          'إبراهيم عليه السلام',
          'محمد صلى الله عليه وسلم',
          'موسى عليه السلام',
          'عيسى عليه السلام',
          'يوسف',
          'يونس',
          'نوح عليه السلام',
          'إسماعيل',
        ];
      } else if (text.contains('المدينة') ||
          text.contains('مكة') ||
          text.contains('بدر') ||
          text.contains('أحد')) {
        distractors = [
          'بيت المقدس',
          'الروضة الشريفة',
          'مسجد القبلتين',
          'غار حراء',
          'جبل النور',
          'جبل ثور',
          'بئر زمزم',
          'الكعبة المشرفة',
        ];
      } else if (text.contains('غزوة')) {
        distractors = [
          'فتح مكة',
          'بدر',
          'الخندق',
          'خيبر',
          'تبوك',
          'حنين',
          'مؤتة',
          'اليرموك',
        ];
      } else if (text.contains('صحابي')) {
        distractors = [
          'خالد بن الوليد',
          'حمزة بن عبد المطلب',
          'أسامة بن زيد',
          'الزبير بن العوام',
          'المقداد بن الأسود',
          'عمار بن ياسر',
          'بلال بن رباح',
          'مصعب بن عمير',
        ];
      } else if (text.contains('أثر')) {
        distractors = [
          'الحجر الأسود',
          'مقام إبراهيم',
          'المنبر النبوي',
          'غار حراء',
          'ماء زمزم',
          'الروضة الشريفة',
          'المشاعر',
          'الصفا والمروة',
        ];
      } else if (text.contains('سنة') || text.contains('عام')) {
        final match = RegExp(r'(\d+)').firstMatch(answer);
        if (match != null) {
          int base = int.parse(match.group(1)!);
          distractors = [
            '${base + 1}',
            '${base - 1}',
            '${base + 2}',
            '${base - 2}',
            '1',
            '5',
            '10',
            '12',
            '114',
          ];
          String suffix = answer.replaceAll(RegExp(r'\d+'), '').trim();
          if (suffix.isNotEmpty) {
            distractors = distractors.map((d) => '$d $suffix').toList();
          }
        }
      } else if (answer.contains('صلاة')) {
        distractors = [
          'صلاة الفجر',
          'صلاة التراويح',
          'صلاة الاستسقاء',
          'صلاة البر',
          'صلاة الجنازة',
          'صلاة الاستخارة',
          'صلاة العيد',
          'صلاة الضحى',
          'صلاة الكسوف',
        ];
      } else if (RegExp(r'\d+').hasMatch(answer)) {
        final match = RegExp(r'(\d+)').firstMatch(answer);
        int base = int.parse(match!.group(1)!);
        distractors = [
          '${base + 1}',
          '${base - 1}',
          '${base + 5}',
          '2',
          '3',
          '4',
          '7',
          '8',
          '12',
          '19',
          '25',
          '30',
          '40',
          '114',
        ];
        String suffix = answer.replaceAll(RegExp(r'\d+'), '').trim();
        if (suffix.isNotEmpty) {
          distractors = distractors.map((d) => '$d $suffix').toList();
        }
      } else if (answer.contains('محمد صلى الله عليه وسلم') ||
          answer.contains('النبي صلى الله عليه وسلم')) {
        distractors = [
          'أبو بكر الصديق',
          'عمر بن الخطاب',
          'عثمان بن عفان',
          'علي بن أبي طالب',
          'خالد بن الوليد',
          'أبو هريرة رضي الله عنه',
          'عائشة رضي الله عنها',
          'خديجة رضي الله عنها',
        ];
      } else if (answer.contains('ساعة') || text.contains('ساعة')) {
        distractors = [
          'لمدة 2 ساعة',
          'لمدة 3 ساعات',
          'لمدة 5 ساعات',
          'لمدة 8 ساعات',
          'لمدة 9 ساعات',
          'لمدة 10 ساعات',
        ];
      } else {
        distractors = [
          'بيت المقدس',
          'الروضة الشريفة',
          'الصلاة',
          'غار حراء',
          'الزكاة',
          'مقام إبراهيم',
          'سيف الله',
          'باب العلم',
          'الحجر الأسود',
          'المدينة',
        ];
      }

      // تنظيف الخيارات وتصفيتها
      distractors.removeWhere((d) {
        String cleanD = d
            .replaceAll('في', '')
            .replaceAll('من', '')
            .replaceAll('عن', '')
            .replaceAll('هو', '')
            .replaceAll('?', '')
            .trim();
        String cleanA = answer
            .replaceAll('في', '')
            .replaceAll('من', '')
            .replaceAll('عن', '')
            .replaceAll('هو', '')
            .replaceAll('?', '')
            .trim();

        if (cleanD == cleanA) return true;
        if (d.trim() == answer.trim()) return true;
        if (answer.length > 4 && d.contains(answer)) return true;
        if (int.tryParse(d.replaceAll(RegExp(r'\D'), '')) != null &&
            int.tryParse(d.replaceAll(RegExp(r'\D'), ''))! <= 0) {
          return true;
        }
        return false;
      });

      distractors.shuffle();
      List<String> selectedOptions = [answer];
      selectedOptions.addAll(distractors.take(3));
      selectedOptions.shuffle();

      // تعبئة الـ controllers وبدء عرض الخيارات تلقائياً
      for (int i = 0; i < 4; i++) {
        if (i < selectedOptions.length) {
          _optionControllers[i].text = selectedOptions[i];
          if (selectedOptions[i] == answer) {
            _correctOptionIndex = i;
          }
        } else {
          _optionControllers[i].clear();
        }
      }
      if (mounted) {
        setState(() {});
      }
    } else {
      // خيارات بديلة في حال تعذر الاستنتاج
      _optionControllers[0].text = 'خيار 1';
      _optionControllers[1].text = 'خيار 2';
      _optionControllers[2].text = 'خيار 3';
      _optionControllers[3].text = 'خيار 4';
      _correctOptionIndex = -1;
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    // التحقق من أن نص السؤال غير فارغ
    final questionText = _questionController.text.trim();
    if (questionText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى التأكد من كتابة نص السؤال أولاً'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // التحقق من اختيار نوع السؤال المولد
    if (_selectedType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار نوع السؤال (صح/خطأ أو خيارات)'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedType == 'true_false') {
      if (_trueFalseAnswer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى تحديد الإجابة الصحيحة (صح أو خطأ)'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      Navigator.pop(context, {
        'question': questionText,
        'type': 'true_false',
        'correctAnswer': _trueFalseAnswer == true ? 'true' : 'false',
        'options': null,
        'timerSeconds': _hasTimer ? _timerSeconds : null,
      });
    } else if (_selectedType == 'multiple_choice') {
      // التحقق من صحة الخيارات المضافة للخيارات المتعددة
      final options = _optionControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (options.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب إدخال خيارين على الأقل للخيارات المتعددة'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // التأكد من أن المستخدم اختار إحدى الإجابات كصحيحة
      if (_correctOptionIndex < 0 || _correctOptionIndex > 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يرجى اختيار الإجابة الصحيحة من الخيارات'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      // التحقق من أن الخيار المحدد كصحيح يحتوي على نص فعلي
      final correctAnswerText = _optionControllers[_correctOptionIndex].text
          .trim();
      if (correctAnswerText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('الخيار المحدد كإجابة صحيحة لا يحتوي على نص!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      Navigator.pop(context, {
        'question': questionText,
        'type': 'multiple_choice',
        'correctAnswer': '$_correctOptionIndex', // رقم الخيار الصحيح (0-3)
        'options': options,
        'timerSeconds': _hasTimer ? _timerSeconds : null,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1a1a2e), Color(0xFF0f0f1a)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 6),
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(50),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),

          // الهيدر والتعريف بالجلسة
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF059669), Color(0xFF10B981)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Text('💡', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'سؤال ذكي ${widget.questionNumber}',
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'بقي ${widget.sessionRemaining} أسئلة في هذه الجلسة',
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                // زر إنهاء الجلسة والعودة للوحة الإدارة
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.stop_circle,
                    color: Colors.red,
                    size: 20,
                  ),
                  label: const Text(
                    'إنهاء',
                    style: TextStyle(color: Colors.red, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // منطقة المحتوى القابلة للتمرير
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // الصندوق الرئيسي - كتابة السؤال أو تعديله كما يقترح البوت
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF10B981).withAlpha(50),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text('📝', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            const Text(
                              'نص السؤال (المولّد آلياً)',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _questionController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                          decoration: InputDecoration(
                            hintText: 'اكتب السؤال هنا أو عدل النص المقترح...',
                            hintStyle: TextStyle(
                              color: Colors.white.withAlpha(100),
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: Colors.white.withAlpha(5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFF10B981).withAlpha(30),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: const Color(0xFF10B981).withAlpha(30),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Color(0xFF10B981),
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(10),
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // زر التحكم في نوع السؤال الحالي (تبديل النمط)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GestureDetector(
                      onTap: _switchQuestionType,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _selectedType == 'true_false'
                                ? [
                                    const Color(0xFF059669),
                                    const Color(0xFF10B981),
                                  ]
                                : [
                                    const Color(0xFF6366F1),
                                    const Color(0xFF8B5CF6),
                                  ],
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (_selectedType == 'true_false'
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFF8B5CF6))
                                      .withAlpha(50),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _selectedType == 'true_false' ? '✔️' : '📝',
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedType == 'true_false'
                                        ? 'نمط صح أو خطأ'
                                        : 'اختيارات متعددة',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'تغيير نمط السؤال',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(150),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.swap_horiz,
                                color: Colors.white.withAlpha(200),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // قسم التحكم في مؤقت السؤال والوقت المتاح للإجابة
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(30)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.timer,
                                    color: Colors.amber,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'تفعيل مؤقت للسؤال',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: _hasTimer,
                                onChanged: (value) {
                                  setState(() => _hasTimer = value);
                                },
                                activeThumbColor: Colors.amber,
                                activeTrackColor: Colors.amber.withAlpha(100),
                              ),
                            ],
                          ),
                          if (_hasTimer) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '5 ث',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(150),
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '$_timerSeconds ثانية',
                                  style: const TextStyle(
                                    color: Colors.amber,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '60 ث',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(150),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _timerSeconds.toDouble(),
                              min: 5,
                              max: 60,
                              divisions: 11,
                              activeColor: Colors.amber,
                              inactiveColor: Colors.white.withAlpha(30),
                              onChanged: (value) {
                                setState(() => _timerSeconds = value.toInt());
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // عرض خيارات الإجابة بناءً على النمط المختار (صح/خطأ أو اختيارات)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _selectedType == 'true_false'
                        ? _buildTrueFalseSection()
                        : _selectedType == 'multiple_choice'
                        ? _buildMultipleChoiceSection()
                        : Center(
                            child: Text(
                              'يرجى البدء بكتابة السؤال',
                              style: TextStyle(
                                color: Colors.white.withAlpha(100),
                                fontSize: 16,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // الزر الرئيسي لإتمام العملية (حفظ السؤال الحالي والذهاب للتالي)
          if (_selectedType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, color: Colors.white),
                            SizedBox(width: 10),
                            Text(
                              'حفظ السؤال والذهاب للتالي',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, color: Colors.white),
                          ],
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrueFalseSection() {
    return Column(
      children: [
        const Text(
          'هل نص السؤال/الجملة صحيح أم خطأ؟',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _trueFalseAnswer = true),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: _trueFalseAnswer == true
                        ? const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          )
                        : null,
                    color: _trueFalseAnswer != true
                        ? Colors.white.withAlpha(10)
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _trueFalseAnswer == true
                          ? Colors.transparent
                          : Colors.green.withAlpha(50),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 48,
                        color: _trueFalseAnswer == true
                            ? Colors.white
                            : Colors.green,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'صح',
                        style: TextStyle(
                          color: _trueFalseAnswer == true
                              ? Colors.white
                              : Colors.green,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _trueFalseAnswer = false),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: _trueFalseAnswer == false
                        ? const LinearGradient(
                            colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                          )
                        : null,
                    color: _trueFalseAnswer != false
                        ? Colors.white.withAlpha(10)
                        : null,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _trueFalseAnswer == false
                          ? Colors.transparent
                          : Colors.red.withAlpha(50),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.cancel,
                        size: 48,
                        color: _trueFalseAnswer == false
                            ? Colors.white
                            : Colors.red,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'خطأ',
                        style: TextStyle(
                          color: _trueFalseAnswer == false
                              ? Colors.white
                              : Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceSection() {
    final labels = ['أ', 'ب', 'ج', 'د'];
    final colors = [Colors.blue, Colors.orange, Colors.purple, Colors.teal];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'حدد الإجابة الصحيحة واكتب الخيارات:',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ...List.generate(4, (index) {
          final isSelected = _correctOptionIndex == index;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        colors[index].withAlpha(50),
                        colors[index].withAlpha(30),
                      ],
                    )
                  : null,
              color: !isSelected ? Colors.white.withAlpha(8) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? colors[index] : Colors.white.withAlpha(30),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _correctOptionIndex = index),
                  child: Container(
                    width: 50,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [
                                colors[index],
                                colors[index].withAlpha(200),
                              ],
                            )
                          : null,
                      color: !isSelected ? colors[index].withAlpha(30) : null,
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(15),
                        bottomRight: Radius.circular(15),
                      ),
                    ),
                    child: Center(
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 24,
                            )
                          : Text(
                              labels[index],
                              style: TextStyle(
                                color: colors[index],
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _optionControllers[index],
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'الخيار ${index + 1}',
                      hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          'ملاحظة: اختر الإجابة الصحيحة بالضغط على الرمز الجانبي',
          style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 12),
        ),
      ],
    );
  }
}
