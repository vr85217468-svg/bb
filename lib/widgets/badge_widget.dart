import 'package:flutter/material.dart';
import 'dart:math' as math;

/// شارات الإنجاز الملكية الفاخرة بتصميم الدرع 🛡️
class BadgeWidget extends StatefulWidget {
  final BadgeType type;
  final double size;
  final bool showGlow;

  const BadgeWidget({
    super.key,
    required this.type,
    this.size = 60,
    this.showGlow = true,
  });

  @override
  State<BadgeWidget> createState() => _BadgeWidgetState();
}

class _BadgeWidgetState extends State<BadgeWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: widget.showGlow
                ? [
                    BoxShadow(
                      color: _getGlowColor().withAlpha(120),
                      blurRadius: widget.size * 0.5,
                      spreadRadius: widget.size * 0.05,
                    ),
                  ]
                : null,
          ),
          child: CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _RoyalBadgePainter(
              type: widget.type,
              animationValue: _controller.value,
            ),
            child: Center(child: _buildIcon()),
          ),
        );
      },
    );
  }

  Widget _buildIcon() {
    return Icon(
      _getIcon(),
      color: Colors.white.withAlpha(235),
      size: widget.size * 0.38,
      shadows: [
        Shadow(
          color: Colors.black.withAlpha(150),
          blurRadius: 3,
          offset: const Offset(1, 1.5),
        ),
      ],
    );
  }

  IconData _getIcon() {
    switch (widget.type) {
      case BadgeType.bronze:
        return Icons.military_tech_rounded;
      case BadgeType.platinum:
        return Icons.diamond_rounded;
      case BadgeType.gold:
        return Icons.emoji_events_rounded;
      case BadgeType.purple:
        return Icons.auto_awesome_rounded;
      case BadgeType.hero:
        return Icons.local_fire_department_rounded;
      case BadgeType.royal:
        return Icons.workspace_premium_rounded;
    }
  }

  Color _getGlowColor() {
    switch (widget.type) {
      case BadgeType.bronze:
        return const Color(0xFFCD7F32);
      case BadgeType.platinum:
        return const Color(0xFFE5E4E2);
      case BadgeType.gold:
        return const Color(0xFFFFD700);
      case BadgeType.purple:
        return const Color(0xFF9B59B6);
      case BadgeType.hero:
        return const Color(0xFFE74C3C);
      case BadgeType.royal:
        return const Color(0xFFFFC107);
    }
  }
}

class _RoyalBadgePainter extends CustomPainter {
  final BadgeType type;
  final double animationValue;

  _RoyalBadgePainter({required this.type, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // رسم مسار الدرع (Shield Path)
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.1, h * 0.2);
    shieldPath.quadraticBezierTo(w * 0.5, h * 0.1, w * 0.9, h * 0.2);
    shieldPath.lineTo(w * 0.9, h * 0.55);
    shieldPath.quadraticBezierTo(w * 0.9, h * 0.85, w * 0.5, h * 0.98);
    shieldPath.quadraticBezierTo(w * 0.1, h * 0.85, w * 0.1, h * 0.55);
    shieldPath.close();

    // 1. الظل المحيطي العميق
    final shadowPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(shieldPath.shift(const Offset(0, 3)), shadowPaint);

    // 2. تدرج المعدن الأساسي (Base Metallic)
    final colors = _getMetallicColors();
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
      stops: const [0.0, 0.45, 0.5, 0.55, 1.0],
    );

    final metalPaint = Paint()
      ..shader = gradient.createShader(shieldPath.getBounds())
      ..style = PaintingStyle.fill;
    canvas.drawPath(shieldPath, metalPaint);

    // 3. الإطار الخارجي اللامع (Golden/Silver Frame)
    final borderPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _getSecondaryColor().withAlpha(255),
          _getMainColor().withAlpha(200),
          _getSecondaryColor().withAlpha(255),
        ],
      ).createShader(shieldPath.getBounds())
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08;
    canvas.drawPath(shieldPath, borderPaint);

    // 4. تأثير اللمعان المتحرك (Liquid Shine Animation)
    final shineValue = (animationValue * 2) - 0.5;
    final shineGradient = LinearGradient(
      begin: Alignment(-1.5 + shineValue * 3, -1.0),
      end: Alignment(-0.5 + shineValue * 3, 1.0),
      colors: [
        Colors.white.withAlpha(0),
        Colors.white.withAlpha(120),
        Colors.white.withAlpha(0),
      ],
      stops: const [0.3, 0.5, 0.7],
    );

    final shinePaint = Paint()
      ..shader = shineGradient.createShader(shieldPath.getBounds())
      ..blendMode = BlendMode.overlay;
    canvas.drawPath(shieldPath, shinePaint);

    // 5. تأثير البريق للهيرو والملكي
    if (type == BadgeType.hero || type == BadgeType.royal) {
      _drawSparkles(canvas, size);
    }
  }

  void _drawSparkles(Canvas canvas, Size size) {
    final sparklePaint = Paint()
      ..color = Colors.white.withAlpha(
        (math.sin(animationValue * math.pi * 4).abs() * 150 + 100).toInt(),
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1);

    final random = math.Random(type.index);
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.2 + random.nextDouble() * 0.6);
      final y = size.height * (0.2 + random.nextDouble() * 0.6);
      final s = 1.0 + random.nextDouble() * 2.5;
      canvas.drawCircle(Offset(x, y), s, sparklePaint);
    }
  }

  List<Color> _getMetallicColors() {
    final main = _getMainColor();
    final dark = _getDarkColor();
    final light = _getLightColor();
    return [dark, main, light, main, dark];
  }

  Color _getMainColor() {
    switch (type) {
      case BadgeType.bronze:
        return const Color(0xFFCD7F32);
      case BadgeType.platinum:
        return const Color(0xFFE5E4E2);
      case BadgeType.gold:
        return const Color(0xFFFFD700);
      case BadgeType.purple:
        return const Color(0xFF8E44AD);
      case BadgeType.hero:
        return const Color(0xFFE74C3C);
      case BadgeType.royal:
        return const Color(0xFFF39C12);
    }
  }

  Color _getDarkColor() {
    switch (type) {
      case BadgeType.bronze:
        return const Color(0xFF8B4513);
      case BadgeType.platinum:
        return const Color(0xFFA0A0A0);
      case BadgeType.gold:
        return const Color(0xFFB8860B);
      case BadgeType.purple:
        return const Color(0xFF5B2C6F);
      case BadgeType.hero:
        return const Color(0xFF943126);
      case BadgeType.royal:
        return const Color(0xFF935116);
    }
  }

  Color _getLightColor() {
    return Colors.white.withAlpha(180);
  }

  Color _getSecondaryColor() {
    switch (type) {
      case BadgeType.bronze:
        return const Color(0xFFE6A756);
      case BadgeType.platinum:
        return const Color(0xFFFFFFFF);
      case BadgeType.gold:
        return const Color(0xFFFFF176);
      case BadgeType.purple:
        return const Color(0xFFD2B4DE);
      case BadgeType.hero:
        return const Color(0xFFF1948A);
      case BadgeType.royal:
        return const Color(0xFFFFE082);
    }
  }

  @override
  bool shouldRepaint(covariant _RoyalBadgePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

/// أنواع الشارات
enum BadgeType {
  bronze, // 🥉 برونزية - 10 إجابات
  platinum, // 💎 بلاتينية - 11 إجابة
  gold, // 🥇 ذهبية - 12 إجابة
  purple, // 💜 بنفسجية - 14 إجابة
  hero, // ❤️ هيرو - 16 إجابة
  royal, // 👑 ملكية - 17 إجابة
}

/// مساعد للحصول على الشارة المناسبة بناءً على عدد الإجابات الصحيحة
class BadgeHelper {
  /// الحصول على الشارة المناسبة
  static BadgeType? getBadgeForScore(
    int correctAnswers, {
    int bronzeThreshold = 10,
    int platinumThreshold = 11,
    int goldThreshold = 12,
    int purpleThreshold = 14,
    int heroThreshold = 16,
    int royalThreshold = 17,
  }) {
    if (correctAnswers >= royalThreshold) return BadgeType.royal;
    if (correctAnswers >= heroThreshold) return BadgeType.hero;
    if (correctAnswers >= purpleThreshold) return BadgeType.purple;
    if (correctAnswers >= goldThreshold) return BadgeType.gold;
    if (correctAnswers >= platinumThreshold) return BadgeType.platinum;
    if (correctAnswers >= bronzeThreshold) return BadgeType.bronze;
    return null;
  }

  /// الحصول على اسم الشارة بالعربية
  static String getBadgeName(BadgeType type) {
    switch (type) {
      case BadgeType.bronze:
        return 'الشارة البرونزية 🥉';
      case BadgeType.platinum:
        return 'الشارة البلاتينية 💎';
      case BadgeType.gold:
        return 'الشارة الذهبية 🥇';
      case BadgeType.purple:
        return 'الشارة البنفسجية 💜';
      case BadgeType.hero:
        return 'شارة الهيرو ❤️';
      case BadgeType.royal:
        return 'الشارة الملكية 👑';
    }
  }

  /// الحصول على وصف الشارة
  static String getBadgeDescription(BadgeType type) {
    switch (type) {
      case BadgeType.bronze:
        return 'أحسنت! بداية موفقة';
      case BadgeType.platinum:
        return 'رائع! مستوى متقدم';
      case BadgeType.gold:
        return 'ممتاز! إنجاز ذهبي';
      case BadgeType.purple:
        return 'مذهل! شخصية VIP';
      case BadgeType.hero:
        return 'أسطوري! أنت بطل';
      case BadgeType.royal:
        return 'ملكي! أعلى مستوى';
    }
  }
}
