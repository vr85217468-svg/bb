import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/supabase_service.dart';
import '../services/guest_mode_service.dart';
import '../services/session_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  late AnimationController _gemController;

  @override
  void initState() {
    super.initState();
    _gemController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _gemController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// التحقق من حالة الصيانة قبل الدخول
  Future<bool> _checkMaintenanceBeforeLogin(String userId) async {
    try {
      final status = await SupabaseService.checkMaintenanceStatus(userId);
      if (status['isUnderMaintenance'] == true && mounted) {
        // عرض شاشة الصيانة
        _showMaintenanceDialog(status['message'] ?? 'التطبيق تحت الصيانة');
        return true; // تحت الصيانة
      }
      return false; // ليس تحت الصيانة
    } catch (e) {
      debugPrint('❌ Error checking maintenance: $e');
      return false; // السماح بالدخول في حالة الخطأ
    }
  }

  /// عرض dialog الصيانة
  void _showMaintenanceDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1a1a2e), Color(0xFF0f0f1a)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '🔧 تحت الصيانة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'نعتذر عن الإزعاج، يرجى المحاولة لاحقاً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text(
                    'حسناً',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = await SupabaseService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (user != null && mounted) {
        // التحقق من حالة الحظر
        final isBanned = user['is_banned'] == true;
        if (isBanned) {
          throw Exception('⛔ حسابك معلق! تواصل مع الإدارة لفك التعليق.');
        }

        // التحقق من حالة الصيانة قبل الدخول
        final isUnderMaintenance = await _checkMaintenanceBeforeLogin(
          user['id'],
        );
        if (isUnderMaintenance) {
          if (mounted) setState(() => _isLoading = false);
          return; // إيقاف الدخول إذا كان تحت الصيانة
        }

        // حفظ الجلسة وتعطيل وضع الزائر
        await SessionService.saveUserSession(user);
        await GuestModeService.disableGuestMode();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                HomeScreen(user: user),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red.shade400,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginAsGuest() async {
    setState(() => _isLoading = true);
    try {
      await GuestModeService.enableGuestMode();
      await SessionService.clearSession(); // التأكد من مسح أي جلسة سابقة (لأنه مجرد زائر)

      if (mounted) {
        // إنشاء بيانات مستخدم افتراضية للزائر (محلياً فقط)
        final guestUser = {
          'id': 'guest',
          'name': 'زائر',
          'username': 'guest',
          'is_guest': true,
        };

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                HomeScreen(user: guestUser),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الدخول كزائر: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createGuestAccount() async {
    setState(() => _isLoading = true);
    try {
      // إنشاء حساب حقيقي في قاعدة البيانات
      final user = await SupabaseService.createGuestAccount();

      if (user != null && mounted) {
        // التحقق من حالة الصيانة قبل الدخول
        final isUnderMaintenance = await _checkMaintenanceBeforeLogin(
          user['id'],
        );
        if (isUnderMaintenance) {
          if (mounted) setState(() => _isLoading = false);
          return; // إيقاف الدخول إذا كان تحت الصيانة
        }

        // حفظ الجلسة وتعطيل وضع الزائر (لأنه أصبح حساباً حقيقياً)
        await SessionService.saveUserSession(user);
        await GuestModeService.disableGuestMode();

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                HomeScreen(user: user),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء حساب الضيف: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية السوداء
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF000000), // أسود نقي
                  Color(0xFF0A0A0A), // أسود غامق جداً
                  Color(0xFF050505), // أسود غامق
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // النقشات الديكورية
          Positioned(
            top: -100,
            right: -100,
            child: _buildDecorativeCircle(250, 0.1),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: _buildDecorativeCircle(150, 0.08),
          ),
          Positioned(
            bottom: 150,
            right: -80,
            child: _buildDecorativeCircle(200, 0.06),
          ),
          Positioned(
            bottom: -50,
            left: 50,
            child: _buildDecorativeCircle(120, 0.1),
          ),

          // النقاط المتناثرة
          ...List.generate(20, (index) {
            final random = math.Random(index);
            return Positioned(
              top: random.nextDouble() * MediaQuery.of(context).size.height,
              left: random.nextDouble() * MediaQuery.of(context).size.width,
              child: Container(
                width: random.nextDouble() * 4 + 2,
                height: random.nextDouble() * 4 + 2,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(
                    (random.nextDouble() * 50 + 20).toInt(),
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),

          // المحتوى الرئيسي
          SafeArea(
            child: Center(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  scrollbars: false,
                  overscroll: true,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // الشعار
                      _buildLogo(),
                      const SizedBox(height: 40),

                      // بطاقة تسجيل الدخول
                      _buildLoginCard(),

                      const SizedBox(height: 24),

                      // رابط إنشاء حساب
                      _buildRegisterLink(),

                      const SizedBox(height: 32),

                      // خيار الدخول كزائر
                      _buildGuestSection(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecorativeCircle(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withAlpha((opacity * 255).toInt()),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        // جوهرة متحركة
        AnimatedBuilder(
          animation: _gemController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _gemController.value * 2 * math.pi,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF00D4FF).withAlpha(200),
                      Color(0xFF00F5E4).withAlpha(180),
                      Color(0xFFB388FF).withAlpha(200),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF00D4FF).withAlpha(150),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Color(0xFFB388FF).withAlpha(100),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: math.pi / 4,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withAlpha(250),
                            Color(0xFF00D4FF).withAlpha(200),
                            Color(0xFFB388FF).withAlpha(150),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withAlpha(100),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        const Text(
          'مرحباً بك',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'سجّل دخولك للمتابعة',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withAlpha(178),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withAlpha(38), Colors.white.withAlpha(13)],
        ),
        border: Border.all(color: Colors.white.withAlpha(50), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(50),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // حقل اسم المستخدم
                _buildTextField(
                  controller: _usernameController,
                  label: 'اسم المستخدم',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال اسم المستخدم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // حقل كلمة المرور
                _buildTextField(
                  controller: _passwordController,
                  label: 'كلمة المرور',
                  icon: Icons.lock_outline_rounded,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: Colors.white.withAlpha(178),
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'الرجاء إدخال كلمة المرور';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // زر تسجيل الدخول
                _buildLoginButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      textDirection: TextDirection.ltr,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withAlpha(178), fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.white.withAlpha(178)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withAlpha(25),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withAlpha(125), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
        errorStyle: TextStyle(color: Colors.red.shade200),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color.fromARGB(255, 74, 79, 105),
          disabledBackgroundColor: Colors.white.withAlpha(125),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Color.fromARGB(255, 74, 79, 105),
                  strokeWidth: 2.5,
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'تسجيل الدخول',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 22),
                ],
              ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'ليس لديك حساب؟',
          style: TextStyle(color: Colors.white.withAlpha(178), fontSize: 15),
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) =>
                    const RegisterScreen(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutCubic,
                              ),
                            ),
                        child: child,
                      );
                    },
                transitionDuration: const Duration(milliseconds: 400),
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.white),
          child: const Text(
            'إنشاء حساب',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGuestSection() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withAlpha(50))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'أو',
                style: TextStyle(color: Colors.white.withAlpha(127)),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withAlpha(50))),
          ],
        ),
        const SizedBox(height: 24),

        // زر إنشاء حساب ضيف حقيقي
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _createGuestAccount,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFB388FF).withAlpha(100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 24),
                SizedBox(width: 12),
                Text(
                  'إنشاء حساب ضيف',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // زر الدخول كزائر (محلي)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _loginAsGuest,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withAlpha(60), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              foregroundColor: Colors.white.withAlpha(180),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.visibility_rounded, size: 22),
                SizedBox(width: 12),
                Text(
                  'المتابعة كزائر فقط',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
