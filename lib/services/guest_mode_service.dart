import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_screen.dart';

/// خدمة إدارة وضع الزائر
class GuestModeService {
  static const String _guestModeKey = 'is_guest_mode';
  static const String _firstLaunchKey = 'first_launch_timestamp';

  /// التحقق من وضع الزائر
  static Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_guestModeKey) ?? false;
  }

  /// تفعيل وضع الزائر
  static Future<void> enableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, true);

    // حفظ وقت أول إطلاق إذا لم يكن محفوظاً
    if (!prefs.containsKey(_firstLaunchKey)) {
      await prefs.setInt(
        _firstLaunchKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }
  }

  /// تعطيل وضع الزائر (عند تسجيل الدخول)
  static Future<void> disableGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_guestModeKey, false);
  }

  /// عرض طلب تسجيل الدخول
  static void showLoginPrompt(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFF1A1A2E),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withAlpha(50),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Color(0xFF00D4FF),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'تسجيل الدخول مطلوب',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'للاستمتاع بميزة "$featureName" يجب عليك تسجيل الدخول أولاً',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00D4FF).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF00D4FF).withAlpha(50),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.star, color: Color(0xFF00D4FF), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'سجل الآن واستمتع بجميع المزايا!',
                      style: TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'لاحقاً',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'تسجيل الدخول',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// فرض تسجيل الدخول للميزة
  /// يرجع true إذا كان المستخدم مسجلاً، false إذا كان زائراً (ويعرض Dialog)
  static Future<bool> requireLogin(
    BuildContext context,
    String featureName,
  ) async {
    final isGuest = await isGuestMode();
    if (isGuest) {
      // التحقق من mounted قبل استخدام context
      if (context.mounted) {
        showLoginPrompt(context, featureName);
      }
      return false;
    }
    return true;
  }
}
