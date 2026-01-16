import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tutorial overlay يوجه المستخدم لزر الإشعارات
class NotificationTutorialOverlay extends StatefulWidget {
  final VoidCallback onBellTap;
  final Offset bellIconPosition;

  const NotificationTutorialOverlay({
    super.key,
    required this.onBellTap,
    required this.bellIconPosition,
  });

  /// التحقق إذا تم عرض Tutorial مسبقاً
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('notification_tutorial_shown') ?? false);
  }

  /// عرض Tutorial
  static Future<void> show(
    BuildContext context,
    Offset bellIconPosition,
    VoidCallback onBellTap,
  ) async {
    final shouldShowTutorial = await NotificationTutorialOverlay.shouldShow();
    if (!shouldShowTutorial || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      builder: (context) => NotificationTutorialOverlay(
        onBellTap: onBellTap,
        bellIconPosition: bellIconPosition,
      ),
    );
  }

  @override
  State<NotificationTutorialOverlay> createState() =>
      _NotificationTutorialOverlayState();
}

class _NotificationTutorialOverlayState
    extends State<NotificationTutorialOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacityAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismissTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_tutorial_shown', true);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Stack(
        children: [
          // النقر في أي مكان لإغلاق
          Positioned.fill(
            child: GestureDetector(
              onTap: _dismissTutorial,
              child: Container(color: Colors.transparent),
            ),
          ),

          // السهم المتحرك يشير لزر الإشعارات
          Positioned(
            top: widget.bellIconPosition.dy + 60,
            right: widget.bellIconPosition.dx - 20,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.arrow_upward,
                          color: Color(0xFFD4AF37),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFD4AF37), Color(0xFFB8960F)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFD4AF37,
                                ).withValues(alpha: 0.4),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Text(
                            '👆 اضغط هنا لرؤية الإشعارات',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // رسالة توضيحية في الأسفل
          Positioned(
            bottom: 100,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1a4d2e), Color(0xFF2d5f3f)],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.notifications_active,
                    color: Color(0xFFD4AF37),
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🔔 مركز الإشعارات',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ستظهر هنا جميع الإشعارات والتنبيهات المهمة\nاضغط على الزر أعلاه للوصول لصندوق الإشعارات',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _dismissTutorial,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'فهمت!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
}
