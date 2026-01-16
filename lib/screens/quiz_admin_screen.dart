import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'quiz_editor_screen.dart';

class QuizAdminScreen extends StatefulWidget {
  const QuizAdminScreen({super.key});

  @override
  State<QuizAdminScreen> createState() => _QuizAdminScreenState();
}

class _QuizAdminScreenState extends State<QuizAdminScreen> {
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await SupabaseService.getQuizCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final bronzeController = TextEditingController(text: '10');
    final platinumController = TextEditingController(text: '11');
    final goldController = TextEditingController(text: '12');
    final purpleController = TextEditingController(text: '14');
    final heroController = TextEditingController(text: '16');
    final royalController = TextEditingController(text: '17');

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: Color(0xFF6366F1)),
            SizedBox(width: 12),
            Text('إضافة قسم جديد', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اسم القسم',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'وصف القسم (اختياري)',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // قسم الشارات
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withAlpha(30),
                      Colors.purple.withAlpha(20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'إعدادات الشارات 🏆',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeField(
                            bronzeController,
                            '🥉 برونزية',
                            const Color(0xFFCD7F32),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBadgeField(
                            platinumController,
                            '💎 بلاتينية',
                            const Color(0xFFE5E4E2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeField(
                            goldController,
                            '🥇 ذهبية',
                            const Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBadgeField(
                            purpleController,
                            '💜 بنفسجية',
                            const Color(0xFF9B59B6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeField(
                            heroController,
                            '❤️ هيرو',
                            const Color(0xFFE74C3C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBadgeField(
                            royalController,
                            '👑 ملكية',
                            const Color(0xFFFFC107),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'badge_bronze': int.tryParse(bronzeController.text) ?? 10,
                  'badge_platinum': int.tryParse(platinumController.text) ?? 11,
                  'badge_gold': int.tryParse(goldController.text) ?? 12,
                  'badge_purple': int.tryParse(purpleController.text) ?? 14,
                  'badge_hero': int.tryParse(heroController.text) ?? 16,
                  'badge_royal': int.tryParse(royalController.text) ?? 17,
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('إضافة', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null) {
      final category = await SupabaseService.addQuizCategory(
        name: result['name']!,
        description: result['description']!.isNotEmpty
            ? result['description']
            : null,
      );
      if (category != null) {
        // تحديث إعدادات الشارات للفئة المضافة حديثاً
        await SupabaseService.updateCategoryBadgeSettings(
          categoryId: category['id'],
          bronzeThreshold: result['badge_bronze'],
          platinumThreshold: result['badge_platinum'],
          goldThreshold: result['badge_gold'],
          purpleThreshold: result['badge_purple'],
          heroThreshold: result['badge_hero'],
          royalThreshold: result['badge_royal'],
        );
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة القسم وإعدادات الشارات ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('حذف القسم', style: TextStyle(color: Colors.white)),
        content: Text(
          'هل أنت متأكد من حذف "${category['name']}"؟\nسيتم حذف جميع الاختبارات والأسئلة.',
          style: const TextStyle(color: Colors.white70),
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
      // حذف فوري من القائمة المحلية
      setState(() {
        _categories.removeWhere((c) => c['id'] == category['id']);
      });

      // إظهار رسالة النجاح فوراً
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف القسم'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 1),
          ),
        );
      }

      // حذف من السيرفر في الخلفية
      SupabaseService.deleteQuizCategory(category['id']);
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final nameController = TextEditingController(text: category['name'] ?? '');
    final descController = TextEditingController(
      text: category['description'] ?? '',
    );

    // إعدادات الشارات
    final bronzeController = TextEditingController(
      text: (category['badge_bronze_threshold'] ?? 10).toString(),
    );
    final platinumController = TextEditingController(
      text: (category['badge_platinum_threshold'] ?? 11).toString(),
    );
    final goldController = TextEditingController(
      text: (category['badge_gold_threshold'] ?? 12).toString(),
    );
    final purpleController = TextEditingController(
      text: (category['badge_purple_threshold'] ?? 14).toString(),
    );
    final heroController = TextEditingController(
      text: (category['badge_hero_threshold'] ?? 16).toString(),
    );
    final royalController = TextEditingController(
      text: (category['badge_royal_threshold'] ?? 17).toString(),
    );

    final result = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.amber),
            SizedBox(width: 12),
            Text('تعديل القسم', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'اسم القسم',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'الوصف (اختياري)',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // قسم الشارات
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.amber.withAlpha(30),
                      Colors.purple.withAlpha(20),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.amber.withAlpha(80)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'إعدادات الشارات 🏆',
                          style: TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // صف 1: برونزية + بلاتينية
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeField(
                            bronzeController,
                            '🥉 برونزية',
                            const Color(0xFFCD7F32),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBadgeField(
                            platinumController,
                            '💎 بلاتينية',
                            const Color(0xFFE5E4E2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // صف 2: ذهبية + بنفسجية
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeField(
                            goldController,
                            '🥇 ذهبية',
                            const Color(0xFFFFD700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBadgeField(
                            purpleController,
                            '💜 بنفسجية',
                            const Color(0xFF9B59B6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // صف 3: هيرو + ملكية
                    Row(
                      children: [
                        Expanded(
                          child: _buildBadgeField(
                            heroController,
                            '❤️ هيرو',
                            const Color(0xFFE74C3C),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildBadgeField(
                            royalController,
                            '👑 ملكية',
                            const Color(0xFFFFC107),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
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
                Navigator.pop(context, {
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                  'badge_bronze': int.tryParse(bronzeController.text) ?? 10,
                  'badge_platinum': int.tryParse(platinumController.text) ?? 11,
                  'badge_gold': int.tryParse(goldController.text) ?? 12,
                  'badge_purple': int.tryParse(purpleController.text) ?? 14,
                  'badge_hero': int.tryParse(heroController.text) ?? 16,
                  'badge_royal': int.tryParse(royalController.text) ?? 17,
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

    if (result != null) {
      final success = await SupabaseService.updateQuizCategory(
        category['id'],
        name: result['name'],
        description: result['description'],
      );
      // تحديث إعدادات الشارات
      await SupabaseService.updateCategoryBadgeSettings(
        categoryId: category['id'],
        bronzeThreshold: result['badge_bronze'],
        platinumThreshold: result['badge_platinum'],
        goldThreshold: result['badge_gold'],
        purpleThreshold: result['badge_purple'],
        heroThreshold: result['badge_hero'],
        royalThreshold: result['badge_royal'],
      );
      if (success) {
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث القسم والشارات ✓'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    }
  }

  Widget _buildBadgeField(
    TextEditingController controller,
    String label,
    Color color,
  ) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: TextStyle(color: color, fontWeight: FontWeight.bold),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color.withAlpha(180), fontSize: 11),
        filled: true,
        fillColor: color.withAlpha(20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withAlpha(100)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withAlpha(60)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'إدارة الاختبارات',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _addCategory,
                      icon: const Icon(
                        Icons.add_circle,
                        color: Color(0xFF6366F1),
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : _categories.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.quiz,
                              size: 80,
                              color: Colors.white.withAlpha(50),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'لا توجد أقسام',
                              style: TextStyle(
                                color: Colors.white.withAlpha(150),
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: _addCategory,
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF6366F1),
                              ),
                              label: const Text(
                                'إضافة قسم',
                                style: TextStyle(color: Color(0xFF6366F1)),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _categories.length,
                        itemBuilder: (context, index) =>
                            _buildCategoryCard(_categories[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withAlpha(50),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.quiz, color: Color(0xFF6366F1), size: 28),
        ),
        title: Text(
          category['name'] ?? '',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle:
            category['description'] != null &&
                category['description'].toString().isNotEmpty
            ? Text(
                category['description'],
                style: TextStyle(
                  color: Colors.white.withAlpha(150),
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => _editCategory(category),
              icon: const Icon(Icons.edit_note, color: Colors.amber, size: 22),
              tooltip: 'تعديل الاسم',
            ),
            IconButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => QuizEditorScreen(category: category),
                  ),
                );
                _loadCategories();
              },
              icon: const Icon(
                Icons.folder_open,
                color: Color(0xFF6366F1),
                size: 22,
              ),
              tooltip: 'الاختبارات',
            ),
            IconButton(
              onPressed: () => _deleteCategory(category),
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
              tooltip: 'حذف',
            ),
          ],
        ),

        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => QuizEditorScreen(category: category),
            ),
          );
          _loadCategories();
        },
      ),
    );
  }
}
