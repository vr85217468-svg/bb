import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import 'dart:ui';

class CreateVoiceRoomScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  const CreateVoiceRoomScreen({super.key, required this.user});

  @override
  State<CreateVoiceRoomScreen> createState() => _CreateVoiceRoomScreenState();
}

class _CreateVoiceRoomScreenState extends State<CreateVoiceRoomScreen>
    with SingleTickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _passwordController = TextEditingController(); // ✅ حقل كلمة السر
  bool _isLoading = false;
  final _client = Supabase.instance.client;

  // خيارات الغرفة الجديدة
  String _selectedColor = 'purple';
  String _selectedIcon = 'headset';
  int _maxParticipants = 10;
  bool _isPrivate = false;
  bool _showPassword = false; // ✅ لإظهار/إخفاء كلمة السر

  late AnimationController _animController;
  late Animation<double> _slideAnimation;

  // قائمة الألوان المتاحة
  final List<Map<String, dynamic>> _colors = [
    {'name': 'purple', 'color': AppTheme.accentPurple, 'label': 'بنفسجي'},
    {'name': 'pink', 'color': AppTheme.accentPink, 'label': 'وردي'},
    {'name': 'cyan', 'color': AppTheme.accentCyan, 'label': 'سماوي'},
    {'name': 'green', 'color': AppTheme.accentGreen, 'label': 'أخضر'},
    {'name': 'gold', 'color': AppTheme.accentGold, 'label': 'ذهبي'},
  ];

  // قائمة الأيقونات المتاحة
  final List<Map<String, dynamic>> _icons = [
    {'name': 'headset', 'icon': Icons.headset_mic_rounded, 'label': 'سماعات'},
    {'name': 'music', 'icon': Icons.music_note_rounded, 'label': 'موسيقى'},
    {'name': 'game', 'icon': Icons.sports_esports_rounded, 'label': 'ألعاب'},
    {'name': 'chat', 'icon': Icons.chat_rounded, 'label': 'دردشة'},
    {'name': 'study', 'icon': Icons.school_rounded, 'label': 'دراسة'},
    {'name': 'podcast', 'icon': Icons.podcasts_rounded, 'label': 'بودكاست'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _passwordController.dispose(); // ✅ تنظيف password controller
    _animController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    return _colors.firstWhere(
          (c) => c['name'] == _selectedColor,
          orElse: () => _colors.first,
        )['color']
        as Color;
  }

  IconData get _currentIcon {
    return _icons.firstWhere(
          (i) => i['name'] == _selectedIcon,
          orElse: () => _icons.first,
        )['icon']
        as IconData;
  }

  Future<void> _handleCreate() async {
    if (_isLoading) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('يرجى إدخال عنوان الغرفة'),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // التحقق من وجود معرف مستخدم صحيح
    final userId = widget.user['id'];

    if (userId == null || userId.toString().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('خطأ في معرف المستخدم'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    // الضيوف السريعون لا يمكنهم إنشاء غرف (يحتاجون UUID حقيقي)
    if (userId.toString() == 'guest') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'يجب إنشاء حساب كامل لإنشاء الغرف الصوتية\nالحسابات الضيف للمشاهدة فقط',
          ),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      Navigator.pop(context);
      return;
    }

    debugPrint('✅ User ID: $userId');

    setState(() => _isLoading = true);

    try {
      if (widget.user['id'] == null) {
        throw Exception('User ID is missing');
      }

      final roomName = 'room_${const Uuid().v4().substring(0, 8)}';

      debugPrint('📝 Creating room with name: $roomName');
      debugPrint('📝 User ID: ${widget.user['id']}');
      debugPrint('📝 Title: $title');

      // البيانات الأساسية + الميزات الجديدة
      final roomData = {
        'title': title,
        'description': _descriptionController.text.trim(),
        'created_by': widget.user['id'],
        'room_name': roomName,
        'is_active': true,
        'participants_count': 0,
        // ✅ الميزات الجديدة - Room Customization
        'room_color': _selectedColor,
        'room_icon': _selectedIcon,
        'max_participants': _maxParticipants,
        'is_private': _isPrivate,
        'password': _isPrivate && _passwordController.text.trim().isNotEmpty
            ? _passwordController.text.trim()
            : null, // ✅ كلمة السر للغرف الخاصة
      };

      debugPrint('📝 Inserting room data...');
      final createdRoom = await _client
          .from('voice_rooms')
          .insert(roomData)
          .select()
          .single()
          .timeout(const Duration(seconds: 10));
      debugPrint('✅ Room created successfully!');

      if (mounted) {
        // ✅ إرجاع بيانات الغرفة للانضمام المباشر
        Navigator.pop(context, createdRoom);
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error creating room: $e');
      debugPrint('Stack trace: $stackTrace');

      String errorMessage = 'فشل إنشاء الغرفة';

      // تحديد نوع الخطأ
      if (e.toString().contains('unique')) {
        errorMessage = 'اسم الغرفة مكرر، حاول مرة أخرى';
      } else if (e.toString().contains('foreign key')) {
        errorMessage = 'خطأ في معرف المستخدم';
      } else if (e.toString().contains('null')) {
        errorMessage = 'بيانات ناقصة';
      } else if (e.toString().contains('permission') ||
          e.toString().contains('policy')) {
        errorMessage = 'ليس لديك صلاحية إنشاء غرفة';
      } else {
        errorMessage = 'خطأ: ${e.toString()}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          MediaQuery.of(context).size.height * 0.3 * _slideAnimation.value,
        ),
        child: child,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A1A2E), const Color(0xFF0D0D1A)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: _currentColor.withAlpha(60), width: 1.5),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                top: 12,
                left: 24,
                right: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // مقبض السحب
                  Center(
                    child: Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(60),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // العنوان مع أيقونة متحركة
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _currentColor.withAlpha(80),
                              _currentColor.withAlpha(40),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _currentColor.withAlpha(60),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _currentIcon,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'غرفة صوتية جديدة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // حقل العنوان
                  _buildTextField(
                    controller: _titleController,
                    hint: 'عنوان الغرفة',
                    icon: Icons.title_rounded,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 16),

                  // حقل الوصف
                  _buildTextField(
                    controller: _descriptionController,
                    hint: 'وصف الغرفة (اختياري)',
                    icon: Icons.description_rounded,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 28),

                  // اختيار اللون
                  _buildSectionTitle('لون الغرفة'),
                  const SizedBox(height: 12),
                  _buildColorPicker(),
                  const SizedBox(height: 24),

                  // اختيار الأيقونة
                  _buildSectionTitle('أيقونة الغرفة'),
                  const SizedBox(height: 12),
                  _buildIconPicker(),
                  const SizedBox(height: 24),

                  // الحد الأقصى للمشاركين
                  _buildSectionTitle('الحد الأقصى للمشاركين'),
                  const SizedBox(height: 12),
                  _buildParticipantsSlider(),
                  const SizedBox(height: 24),

                  // غرفة خاصة
                  _buildPrivateSwitch(),

                  // ✅ حقل كلمة السر (يظهر فقط للغرف الخاصة)
                  if (_isPrivate) ...[
                    const SizedBox(height: 16),
                    _buildPasswordField(),
                  ],

                  const SizedBox(height: 32),

                  // زر الإنشاء
                  _buildCreateButton(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
          prefixIcon: Icon(icon, color: _currentColor),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withAlpha(200),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildColorPicker() {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _colors.length,
        itemBuilder: (context, index) {
          final colorData = _colors[index];
          final isSelected = colorData['name'] == _selectedColor;

          return GestureDetector(
            onTap: () => setState(() => _selectedColor = colorData['name']),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(
                right: index < _colors.length - 1 ? 12 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? (colorData['color'] as Color).withAlpha(50)
                    : Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? colorData['color'] as Color
                      : Colors.white.withAlpha(20),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: (colorData['color'] as Color).withAlpha(60),
                          blurRadius: 12,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: colorData['color'] as Color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (colorData['color'] as Color).withAlpha(100),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    colorData['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIconPicker() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _icons.map((iconData) {
        final isSelected = iconData['name'] == _selectedIcon;

        return GestureDetector(
          onTap: () => setState(() => _selectedIcon = iconData['name']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected
                  ? _currentColor.withAlpha(50)
                  : Colors.white.withAlpha(8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? _currentColor : Colors.white.withAlpha(20),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _currentColor.withAlpha(60),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                Icon(
                  iconData['icon'] as IconData,
                  color: isSelected ? _currentColor : Colors.white70,
                  size: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  iconData['label'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 11,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildParticipantsSlider() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.people_rounded, color: _currentColor, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '$_maxParticipants',
                    style: TextStyle(
                      color: _currentColor,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'مشارك',
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              Text(
                'الحد الأقصى',
                style: TextStyle(
                  color: Colors.white.withAlpha(100),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: _currentColor,
              inactiveTrackColor: _currentColor.withAlpha(40),
              thumbColor: _currentColor,
              overlayColor: _currentColor.withAlpha(30),
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            ),
            child: Slider(
              value: _maxParticipants.toDouble(),
              min: 2,
              max: 50,
              divisions: 24,
              onChanged: (value) {
                setState(() => _maxParticipants = value.toInt());
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivateSwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isPrivate
              ? _currentColor.withAlpha(60)
              : Colors.white.withAlpha(20),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isPrivate ? Icons.lock_rounded : Icons.lock_open_rounded,
            color: _isPrivate ? _currentColor : Colors.white60,
            size: 24,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'غرفة خاصة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isPrivate
                      ? 'فقط من تتم دعوتهم يمكنهم الانضمام'
                      : 'أي شخص يمكنه الانضمام للغرفة',
                  style: TextStyle(
                    color: Colors.white.withAlpha(120),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isPrivate,
            onChanged: (value) => setState(() => _isPrivate = value),
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _currentColor;
              }
              return Colors.white;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return _currentColor.withAlpha(100);
              }
              return Colors.white.withAlpha(30);
            }),
          ),
        ],
      ),
    );
  }

  /// ✅ حقل كلمة السر للغرف الخاصة
  Widget _buildPasswordField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _currentColor.withAlpha(60), width: 1.5),
      ),
      child: TextField(
        controller: _passwordController,
        obscureText: !_showPassword,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'كلمة السر (اختياري)',
          hintStyle: TextStyle(color: Colors.white.withAlpha(80)),
          prefixIcon: Icon(Icons.lock_rounded, color: _currentColor),
          suffixIcon: IconButton(
            icon: Icon(
              _showPassword ? Icons.visibility_off : Icons.visibility,
              color: Colors.white54,
            ),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
          filled: false,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleCreate,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isLoading
                ? [Colors.grey, Colors.grey.shade600]
                : [_currentColor, _currentColor.withAlpha(200)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _isLoading
              ? null
              : [
                  BoxShadow(
                    color: _currentColor.withAlpha(100),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: Center(
          child: _isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'إنشاء الغرفة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
