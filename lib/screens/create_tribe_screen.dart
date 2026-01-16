import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

/// شاشة إنشاء قبيلة جديدة - تصميم فاخر

const Color _royalRed = Color(0xFF630000);
const Color _gold = Color(0xFFFFD700);
const Color _darkBg = Color(0xFF0A0A0A);
const Color _cardBg = Color(0xFF151515);

class CreateTribeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const CreateTribeScreen({super.key, required this.user});

  @override
  State<CreateTribeScreen> createState() => _CreateTribeScreenState();
}

class _CreateTribeScreenState extends State<CreateTribeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedIcon = '⚔️';
  bool _isPrivate = false;
  bool _isCreating = false;

  static const List<String> _icons = [
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
    '🎨',
    '📚',
    '⚖️',
    '🕌',
    '🕋',
    '📿',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createTribe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final tribe = await SupabaseService.createTribe(
        name: _nameController.text.trim(),
        nameEn: _nameEnController.text.trim().isEmpty
            ? null
            : _nameEnController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        icon: _selectedIcon,
        isPrivate: _isPrivate,
        leaderId: widget.user['id'],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تشييد قبيلة "${tribe!['name']}" بنجاح! ⚔️'),
          backgroundColor: _royalRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, tribe);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_darkBg, const Color(0xFF2A1F3D), _darkBg],
          ),
        ),
        child: Stack(
          children: [
            // دوائر زخرفية
            Positioned(
              top: -100,
              right: -50,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _royalRed.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -80,
              left: -80,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [_gold.withValues(alpha: 0.1), Colors.transparent],
                  ),
                ),
              ),
            ),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 160,
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  leading: IconButton(
                    icon: Icon(Icons.close_rounded, color: _gold),
                    onPressed: () => Navigator.pop(context),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    title: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [_gold, _royalRed],
                      ).createShader(bounds),
                      child: const Text(
                        'إنشاء قبيلة جديدة',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                        ),
                      ),
                    ),
                    centerTitle: false,
                    titlePadding: const EdgeInsets.only(left: 60, bottom: 20),
                    background: Stack(
                      children: [
                        Positioned(
                          right: -30,
                          top: -20,
                          child: Icon(
                            Icons.auto_awesome,
                            size: 180,
                            color: _royalRed.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildIconPreview(),
                          const SizedBox(height: 10),
                          _buildIconSelector(),
                          const SizedBox(height: 40),
                          _buildTextField(
                            controller: _nameController,
                            label: 'اسم القبيلة',
                            hint: 'مثال: المجتهدون',
                            icon: Icons.groups_rounded,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'الرجاء تسمية قبيلتك';
                              }
                              return null;
                            },
                          ),
                          _buildTextField(
                            controller: _nameEnController,
                            label: 'الاسم بالإنجليزية (اختياري)',
                            hint: 'e.g. The Learners',
                            icon: Icons.language_rounded,
                          ),
                          _buildTextField(
                            controller: _descriptionController,
                            label: 'وصف القبيلة (اختياري)',
                            hint: 'ما هدف قبيلتك؟',
                            icon: Icons.description_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 10),
                          _buildPrivacySwitch(),
                          const SizedBox(height: 50),
                          _buildCreateButton(),
                          const SizedBox(height: 80),
                        ],
                      ),
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

  Widget _buildIconPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _royalRed.withValues(alpha: 0.3),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_cardBg, const Color(0xFF3D2F5A)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _royalRed.withValues(alpha: 0.3),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _selectedIcon,
                    style: const TextStyle(fontSize: 50),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [_gold, Colors.white],
            ).createShader(bounds),
            child: const Text(
              'رمز القبيلة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 4),
          child: Text(
            'اختر الختم'.toUpperCase(),
            style: TextStyle(
              color: _gold.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            ),
          ),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 75,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _icons.length,
            itemBuilder: (context, index) {
              final icon = _icons[index];
              final isSelected = icon == _selectedIcon;
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = icon),
                child: Container(
                  width: 65,
                  margin: const EdgeInsets.only(left: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [_royalRed.withValues(alpha: 0.3), _cardBg],
                          )
                        : null,
                    color: isSelected ? null : _cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? _gold
                          : _royalRed.withValues(alpha: 0.3),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: _gold.withValues(alpha: 0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 28)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _royalRed.withValues(alpha: 0.3), width: 1),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _gold, size: 18),
              const SizedBox(width: 8),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: _gold.withValues(alpha: 0.9),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
            maxLines: maxLines,
            validator: validator,
            cursorColor: _gold,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacySwitch() {
    return GestureDetector(
      onTap: () => setState(() => _isPrivate = !_isPrivate),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardBg.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _royalRed.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            Icon(
              _isPrivate ? Icons.lock_rounded : Icons.public_rounded,
              color: _gold,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'نوع القبيلة',
                    style: TextStyle(
                      color: _gold.withValues(alpha: 0.9),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isPrivate
                        ? 'خاصة (تحتاج موافقة للانضمام)'
                        : 'عامة (يمكن للجميع الانضمام)',
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
              onChanged: (v) => setState(() => _isPrivate = v),
              activeTrackColor: _royalRed.withValues(alpha: 0.5),
              activeThumbColor: _gold, // ✅ Fixed deprecated activeColor
              inactiveThumbColor: Colors.grey[600],
              inactiveTrackColor: Colors.grey[800],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(colors: [_royalRed, const Color(0xFF8B0000)]),
        boxShadow: [
          if (!_isCreating)
            BoxShadow(
              color: _royalRed.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isCreating ? null : _createTribe,
          borderRadius: BorderRadius.circular(32),
          child: Center(
            child: _isCreating
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: _gold, size: 22),
                      const SizedBox(width: 12),
                      Text(
                        'إنشاء القبيلة',
                        style: TextStyle(
                          color: _gold,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
