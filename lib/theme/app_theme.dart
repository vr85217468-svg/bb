import 'dart:ui';
import 'package:flutter/material.dart';

/// نظام التصميم الموحد للتطبيق
/// ✨ Angelic Theme - Celestial & Spiritual Design System 👼
class AppTheme {
  // ═══════════════════════════════════════════════════════════════
  // الألوان الملائكية - Angelic Color Palette ✨
  // ═══════════════════════════════════════════════════════════════

  // ألوان السماء
  static const Color primaryDark = Color(0xFF0A0E27); // أزرق داكن سماوي
  static const Color primaryMid = Color(0xFF1A1F4E); // بنفسجي سماوي
  static const Color primaryLight = Color(0xFF2D3875); // أزرق ليلي

  // ألوان الملائكة 👼
  static const Color accentPurple = Color(0xFF6B5CE7); // بنفسجي ملائكي
  static const Color accentViolet = Color(0xFF8B7CF7); // بنفسجي فاتح
  static const Color accentPink = Color(0xFFE8B4E6); // وردي روحاني
  static const Color accentCyan = Color(0xFF64D2FF); // أزرق سماوي متوهج
  static const Color accentGreen = Color(0xFF4ADE80); // أخضر نعيم
  static const Color accentGold = Color(0xFFFFD700); // ذهبي ملائكي
  static const Color accentSilverGold = Color(0xFFE5E4E2); // فضي ذهبي ملكي
  static const Color accentBlackSilver = Color(0xFF1B1B1B); // فضي مسود غامض
  static const Color accentWhitishSilver = Color(0xFFF5F5F7); // فضي مبيض نقي

  // ألوان التدرج الملائكية
  static const List<Color> gradientPrimary = [
    Color(0xFF1A1F4E),
    Color(0xFF2D3875),
  ];

  static const List<Color> gradientDark = [
    Color(0xFF0A0E27),
    Color(0xFF1A1F4E),
    Color(0xFF0D1235),
  ];

  static const List<Color> gradientAccent = [
    Color(0xFFE5E4E2), // فضي ذهبي
    Color(0xFFC0C0C0), // فضي
    Color(0xFF1B1B1B), // فضي مسود
  ];

  static const List<Color> gradientSuccess = [
    Color(0xFF4ADE80),
    Color(0xFF22C55E),
  ];

  static const List<Color> gradientWarning = [
    Color(0xFFFFD700),
    Color(0xFFFFC107),
  ];

  // ═══════════════════════════════════════════════════════════════
  // الظلال - Premium Shadows
  // ═══════════════════════════════════════════════════════════════

  static List<BoxShadow> get shadowSmall => [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.1),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowMedium => [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.15),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get shadowLarge => [
    BoxShadow(
      color: Color.fromRGBO(0, 0, 0, 0.2),
      blurRadius: 40,
      spreadRadius: 5,
      offset: const Offset(0, 15),
    ),
  ];

  static List<BoxShadow> shadowGlow(Color color) => [
    BoxShadow(
      color: Color.fromRGBO(
        (color.r * 255).round(),
        (color.g * 255).round(),
        (color.b * 255).round(),
        0.4,
      ),
      blurRadius: 20,
      spreadRadius: 2,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════
  // تأثير الزجاج - Glassmorphism
  // ═══════════════════════════════════════════════════════════════

  static BoxDecoration get glassCard => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.fromRGBO(255, 255, 255, 0.15),
        Color.fromRGBO(255, 255, 255, 0.05),
      ],
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Color.fromRGBO(255, 255, 255, 0.2), width: 1.5),
  );

  static BoxDecoration get glassCardDark => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color.fromRGBO(0, 0, 0, 0.3), Color.fromRGBO(0, 0, 0, 0.1)],
    ),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Color.fromRGBO(255, 255, 255, 0.1), width: 1),
  );

  // ═══════════════════════════════════════════════════════════════
  // الخلفيات - Backgrounds
  // ═══════════════════════════════════════════════════════════════

  static BoxDecoration get backgroundGradient => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: gradientDark,
    ),
  );

  // ═══════════════════════════════════════════════════════════════
  // أنماط النصوص - Text Styles
  // ═══════════════════════════════════════════════════════════════

  static const TextStyle headingLarge = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  );

  static const TextStyle headingSmall = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    color: Colors.white70,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    color: Colors.white60,
  );

  static const TextStyle labelStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white54,
    letterSpacing: 0.5,
  );

  // ═══════════════════════════════════════════════════════════════
  // أشكال الأزرار - Button Styles
  // ═══════════════════════════════════════════════════════════════

  static ButtonStyle get primaryButton => ElevatedButton.styleFrom(
    backgroundColor: accentPurple,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    elevation: 0,
  );

  static ButtonStyle get glassButton => ElevatedButton.styleFrom(
    backgroundColor: Color.fromRGBO(255, 255, 255, 0.1),
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.2)),
    ),
    elevation: 0,
  );

  // ═══════════════════════════════════════════════════════════════
  // حقول الإدخال - Input Decoration
  // ═══════════════════════════════════════════════════════════════

  static InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) => InputDecoration(
    labelText: label,
    labelStyle: TextStyle(color: Color.fromRGBO(255, 255, 255, 0.7)),
    prefixIcon: Icon(icon, color: Color.fromRGBO(255, 255, 255, 0.7)),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Color.fromRGBO(255, 255, 255, 0.1),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: accentPurple, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.1)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
  );
}

// ═══════════════════════════════════════════════════════════════
// ويدجت البطاقة الزجاجية - Glass Card Widget
// ═══════════════════════════════════════════════════════════════

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.blur = 10,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(borderRadius),
              child: Container(
                padding: padding ?? const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.fromRGBO(255, 255, 255, 0.15),
                      Color.fromRGBO(255, 255, 255, 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: Color.fromRGBO(255, 255, 255, 0.2),
                    width: 1.5,
                  ),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// زر متدرج - Gradient Button
// ═══════════════════════════════════════════════════════════════

class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final List<Color> gradient;
  final IconData? icon;
  final bool isLoading;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient = AppTheme.gradientAccent,
    this.icon,
    this.isLoading = false,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.onPressed != null
                  ? widget.gradient
                  : [Colors.grey, Colors.grey.shade600],
            ),
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: widget.onPressed != null
                ? [
                    BoxShadow(
                      color: Color.fromRGBO(
                        (widget.gradient.first.r * 255).round(),
                        (widget.gradient.first.g * 255).round(),
                        (widget.gradient.first.b * 255).round(),
                        0.4,
                      ),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.text,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (widget.icon != null) ...[
                        const SizedBox(width: 8),
                        Icon(widget.icon, color: Colors.white, size: 22),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// شريط التنقل السفلي المتقدم - Premium Bottom Nav
// ═══════════════════════════════════════════════════════════════

class PremiumBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<PremiumNavItem> items;

  const PremiumBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color.fromRGBO(26, 31, 78, 0.95),
            Color.fromRGBO(10, 14, 39, 0.98),
          ],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Color.fromRGBO(255, 215, 0, 0.2)),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isActive = index == currentIndex;

          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isActive ? 20 : 16,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: isActive
                    ? const LinearGradient(colors: AppTheme.gradientAccent)
                    : null,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? item.activeIcon : item.icon,
                    color: isActive ? Colors.white : Colors.white54,
                    size: 24,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Text(
                      item.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class PremiumNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const PremiumNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ═══════════════════════════════════════════════════════════════
// دوائر الخلفية الديكورية - Decorative Circles
// ═══════════════════════════════════════════════════════════════

class AnimatedBackgroundCircles extends StatelessWidget {
  const AnimatedBackgroundCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -100,
          right: -100,
          child: _buildCircle(300, Color.fromRGBO(107, 92, 231, 0.15)),
        ),
        Positioned(
          top: 200,
          left: -80,
          child: _buildCircle(200, Color.fromRGBO(255, 215, 0, 0.1)),
        ),
        Positioned(
          bottom: 100,
          right: -60,
          child: _buildCircle(250, Color.fromRGBO(139, 124, 247, 0.1)),
        ),
        Positioned(
          bottom: -80,
          left: 40,
          child: _buildCircle(180, Color.fromRGBO(100, 210, 255, 0.12)),
        ),
      ],
    );
  }

  Widget _buildCircle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            Color.fromRGBO(
              (color.r * 255).round(),
              (color.g * 255).round(),
              (color.b * 255).round(),
              0,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// تأثير التوهج - Glow Effect Widget
// ═══════════════════════════════════════════════════════════════

class GlowContainer extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double blurRadius;
  final BorderRadius? borderRadius;

  const GlowContainer({
    super.key,
    required this.child,
    this.glowColor = AppTheme.accentPurple,
    this.blurRadius = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(
              (glowColor.r * 255).round(),
              (glowColor.g * 255).round(),
              (glowColor.b * 255).round(),
              0.4,
            ),
            blurRadius: blurRadius,
            spreadRadius: 2,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// النقشات الملائكية المخيفة - Mystical Angelic Patterns ✨👼
// ═══════════════════════════════════════════════════════════════

class MysticalAngelicPatterns extends StatefulWidget {
  const MysticalAngelicPatterns({super.key});

  @override
  State<MysticalAngelicPatterns> createState() =>
      _MysticalAngelicPatternsState();
}

class _MysticalAngelicPatternsState extends State<MysticalAngelicPatterns>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _floatController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    // أنيميشن بطيء وسلس للأداء العالي
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5), // أبطأ للسلاسة
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30), // أبطأ للسلاسة
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6), // أبطأ للسلاسة
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      // نطاق أصغر
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      // حركة أقل
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // خلفية سوداء غامقة جداً
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF000000), // أسود تام
                  Color(0xFF050510), // أسود مع لمسة زرقاء
                  Color(0xFF0a0a15), // أسود داكن
                  Color(0xFF050510), // أسود مع لمسة زرقاء
                  Color(0xFF000000), // أسود تام
                ],
              ),
            ),
          ),
        ),

        // نجوم لامعة متناثرة
        ..._buildTwinklingStarsBackground(),
        // الملاك الشبحي العائم في الخلفية
        Positioned(
          top: 30,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _floatAnimation,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _floatAnimation.value),
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Opacity(
                  opacity: 0.35 + (_pulseAnimation.value - 0.8) * 0.15,
                  child: Center(
                    child: Image.asset(
                      'assets/images/angelic_figure.png',
                      height: 420,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // هالة ملائكية كبيرة في الأعلى
        Positioned(
          top: -150,
          left: 0,
          right: 0,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) => Transform.scale(
              scale: _pulseAnimation.value,
              child: Container(
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color.fromRGBO(255, 215, 0, 0.15),
                      Color.fromRGBO(255, 215, 0, 0.08),
                      Color.fromRGBO(255, 215, 0, 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // نجوم متوهجة متفرقة فقط
        ..._buildFloatingStars(),
      ],
    );
  }

  List<Widget> _buildFloatingStars() {
    return [
      _buildStar(top: 80, left: 50, size: 8, delay: 0),
      _buildStar(top: 150, right: 80, size: 6, delay: 0.3),
      _buildStar(top: 250, left: 120, size: 10, delay: 0.6),
      _buildStar(bottom: 300, right: 40, size: 7, delay: 0.2),
      _buildStar(bottom: 180, left: 80, size: 5, delay: 0.5),
      _buildStar(top: 350, right: 150, size: 8, delay: 0.8),
    ];
  }

  Widget _buildStar({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double delay,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final adjustedValue =
              ((_pulseAnimation.value - 0.8) + delay) % 0.4 + 0.8;
          return Opacity(
            opacity: (adjustedValue - 0.6).clamp(0.2, 1.0),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(255, 255, 255, 0.8),
                    blurRadius: size * 2,
                    spreadRadius: size / 2,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // نجوم متلألئة في الخلفية السوداء - عدد محسّن للأداء
  List<Widget> _buildTwinklingStarsBackground() {
    return [
      // نجوم متناثرة بعدد أقل للسلاسة
      _buildBackgroundStar(top: 60, left: 30, size: 2, delay: 0.0),
      _buildBackgroundStar(top: 120, right: 50, size: 3, delay: 0.3),
      _buildBackgroundStar(top: 200, left: 120, size: 2, delay: 0.5),
      _buildBackgroundStar(top: 280, right: 80, size: 3, delay: 0.2),
      _buildBackgroundStar(top: 380, left: 60, size: 2, delay: 0.7),
      _buildBackgroundStar(top: 480, right: 40, size: 3, delay: 0.4),
      _buildBackgroundStar(top: 580, left: 150, size: 2, delay: 0.1),
      // نجوم أسفل
      _buildBackgroundStar(bottom: 250, left: 50, size: 2, delay: 0.6),
      _buildBackgroundStar(bottom: 180, right: 100, size: 3, delay: 0.3),
      _buildBackgroundStar(bottom: 100, left: 100, size: 2, delay: 0.8),
      _buildBackgroundStar(bottom: 50, right: 60, size: 3, delay: 0.2),
      // نجوم وسط
      _buildBackgroundStar(top: 150, left: 200, size: 2, delay: 0.4),
      _buildBackgroundStar(top: 350, right: 180, size: 3, delay: 0.6),
      _buildBackgroundStar(bottom: 320, left: 160, size: 2, delay: 0.1),
      _buildBackgroundStar(bottom: 220, right: 140, size: 3, delay: 0.5),
    ];
  }

  Widget _buildBackgroundStar({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required double delay,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          // تأثير لمعان متفاوت
          final twinkle =
              ((_pulseAnimation.value - 0.8 + delay) * 2.5).abs() % 1.0;
          return Opacity(
            opacity: 0.3 + twinkle * 0.7,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withAlpha(
                      (150 + twinkle * 100).toInt(),
                    ),
                    blurRadius: size * 3,
                    spreadRadius: size * 0.5,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
