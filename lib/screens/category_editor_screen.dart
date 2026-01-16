import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';

class CategoryEditorScreen extends StatefulWidget {
  final Map<String, dynamic> category;

  const CategoryEditorScreen({super.key, required this.category});

  @override
  State<CategoryEditorScreen> createState() => _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends State<CategoryEditorScreen> {
  List<Map<String, dynamic>> _subCategories = [];
  List<Map<String, dynamic>> _contents = [];
  bool _isLoading = true;
  final ImagePicker _picker = ImagePicker();

  final List<Map<String, dynamic>> _availableIcons = [
    {'name': 'القرآن', 'icon': 'book'},
    {'name': 'الصباح', 'icon': 'wb_sunny'},
    {'name': 'المساء', 'icon': 'nights_stay'},
    {'name': 'الصلاة', 'icon': 'mosque'},
    {'name': 'القلب', 'icon': 'favorite'},
    {'name': 'الدعاء', 'icon': 'pan_tool'},
    {'name': 'النوم', 'icon': 'bedtime'},
    {'name': 'نجمة', 'icon': 'star'},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final subCategories = await SupabaseService.getAdhkarCategories(
      parentId: widget.category['id'],
    );
    final contents = await SupabaseService.getCategoryContents(
      widget.category['id'],
    );
    if (mounted) {
      setState(() {
        _subCategories = subCategories;
        _contents = contents;
        _isLoading = false;
      });
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

  Future<void> _addSubCategory() async {
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
            'إضافة قسم فرعي',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableIcons.map((item) {
                  final isSelected = selectedIcon == item['icon'];
                  return GestureDetector(
                    onTap: () => setState(() => selectedIcon = item['icon']),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : Colors.white.withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getIconData(item['icon']),
                        color: Colors.white,
                        size: 22,
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
                  await SupabaseService.addAdhkarCategory(
                    name: nameController.text.trim(),
                    icon: selectedIcon,
                    parentId: widget.category['id'],
                  );
                  await _loadData();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('إضافة', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTextContent() async {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('إضافة نص', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'العنوان (اختياري)',
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
                controller: contentController,
                style: const TextStyle(color: Colors.white),
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'المحتوى...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
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
              if (contentController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                await SupabaseService.addContent(
                  categoryId: widget.category['id'],
                  contentType: 'text',
                  title: titleController.text.trim().isEmpty
                      ? null
                      : titleController.text.trim(),
                  content: contentController.text.trim(),
                );
                await _loadData();
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
  }

  Future<void> _addImageContent() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final imageUrl = await SupabaseService.uploadContentImage(
        bytes,
        image.name,
      );

      if (imageUrl != null) {
        await SupabaseService.addContent(
          categoryId: widget.category['id'],
          contentType: 'image',
          mediaUrl: imageUrl,
        );
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع الصورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  /// تعديل قسم فرعي
  Future<void> _editSubCategory(Map<String, dynamic> category) async {
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
              'تعديل القسم',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
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
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableIcons.map((item) {
                    final isSelected = dialogIcon == item['icon'];
                    return GestureDetector(
                      onTap: () => setState(() => dialogIcon = item['icon']),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF6366F1)
                              : Colors.white.withAlpha(15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getIconData(item['icon']),
                          color: Colors.white,
                          size: 22,
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
                ),
                child: const Text('حفظ', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );

    // تنفيذ التحديث بعد إغلاق الـ dialog
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
              content: Text('تم تحديث القسم'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل تحديث القسم'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// تعديل محتوى نصي
  Future<void> _editTextContent(Map<String, dynamic> content) async {
    final titleController = TextEditingController(text: content['title'] ?? '');
    final contentController = TextEditingController(
      text: content['content'] ?? '',
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('تعديل النص', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'العنوان (اختياري)',
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
                controller: contentController,
                style: const TextStyle(color: Colors.white),
                maxLines: 6,
                decoration: InputDecoration(
                  hintText: 'المحتوى...',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
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
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'إلغاء',
              style: TextStyle(color: Colors.white.withAlpha(150)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (contentController.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    // تنفيذ التحديث بعد إغلاق الـ dialog
    if (result == true && contentController.text.trim().isNotEmpty) {
      await SupabaseService.updateContent(
        content['id'],
        title: titleController.text.trim().isEmpty
            ? null
            : titleController.text.trim(),
        content: contentController.text.trim(),
      );
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث المحتوى'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _deleteSubCategory(String id) async {
    await SupabaseService.deleteAdhkarCategory(id);
    await _loadData();
  }

  Future<void> _deleteContent(String id) async {
    await SupabaseService.deleteContent(id);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f0f23)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildActionButtons(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF6366F1),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (_subCategories.isNotEmpty) ...[
                              _buildSectionTitle('الأقسام الفرعية'),
                              ..._subCategories.map(_buildSubCategoryCard),
                            ],
                            if (_contents.isNotEmpty) ...[
                              _buildSectionTitle('المحتويات'),
                              ..._contents.map(_buildContentCard),
                            ],
                            if (_subCategories.isEmpty && _contents.isEmpty)
                              _buildEmptyState(),
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
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _getIconData(widget.category['icon'] ?? 'star'),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.category['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'تحرير المحتوى',
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionButton(
              'قسم فرعي',
              Icons.folder_open,
              _addSubCategory,
              const Color(0xFF6366F1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              'نص',
              Icons.text_fields,
              _addTextContent,
              const Color(0xFF22C55E),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionButton(
              'صورة',
              Icons.image,
              _addImageContent,
              const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback onTap,
    Color color,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color, color.withAlpha(200)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withAlpha(75),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withAlpha(150),
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSubCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
            size: 22,
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
            // زر تعديل اسم القسم
            IconButton(
              icon: const Icon(Icons.edit_note, color: Colors.amber, size: 22),
              onPressed: () => _editSubCategory(category),
            ),
            // زر تعديل المحتوى الداخلي
            IconButton(
              icon: const Icon(
                Icons.folder_open,
                color: Color(0xFF6366F1),
                size: 22,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CategoryEditorScreen(category: category),
                ),
              ).then((_) => _loadData()),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red, size: 22),
              onPressed: () => _deleteSubCategory(category['id']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> content) {
    final type = content['content_type'] ?? 'text';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white.withAlpha(20), Colors.white.withAlpha(10)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(30)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: type == 'text'
                        ? Colors.green.withAlpha(50)
                        : Colors.orange.withAlpha(50),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    type == 'text' ? Icons.text_fields : Icons.image,
                    color: type == 'text' ? Colors.green : Colors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                if (content['title'] != null)
                  Expanded(
                    child: Text(
                      content['title'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                // زر التعديل للنصوص فقط
                if (type == 'text')
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.amber, size: 20),
                    onPressed: () => _editTextContent(content),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  onPressed: () => _deleteContent(content['id']),
                ),
              ],
            ),
            if (type == 'text' && content['content'] != null) ...[
              const SizedBox(height: 12),
              Text(
                content['content'],
                style: TextStyle(
                  color: Colors.white.withAlpha(200),
                  fontSize: 15,
                ),
              ),
            ],
            if (type == 'image' && content['media_url'] != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  content['media_url'],
                  fit: BoxFit.cover,
                  height: 150,
                  width: double.infinity,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              Icons.add_box_outlined,
              size: 60,
              color: Colors.white.withAlpha(50),
            ),
            const SizedBox(height: 16),
            Text(
              'لا يوجد محتوى',
              style: TextStyle(
                color: Colors.white.withAlpha(150),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف أقسام فرعية أو محتوى',
              style: TextStyle(
                color: Colors.white.withAlpha(100),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
