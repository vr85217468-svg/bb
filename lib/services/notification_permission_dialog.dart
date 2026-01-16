import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';

/// Dialog إسلامي لطلب إذن الإشعارات بطريقة ذكية
class NotificationPermissionDialog {
  /// عرض Dialog بعد 3 ثواني من تسجيل الدخول
  static Future<void> showAfterDelay(BuildContext context) async {
    // انتظار 3 ثواني
    await Future.delayed(const Duration(seconds: 3));

    // على الويب، فقط اعرض رسالة توضيحية
    if (kIsWeb) {
      debugPrint('ℹ️ Running on web - notification permission not applicable');
      return; // لا نعرض Dialog على الويب
    }

    // التحقق إذا كان الإذن ممنوحاً مسبقاً (على الموبايل فقط)
    final status = await Permission.notification.status;
    if (status.isGranted) {
      debugPrint('✅ Notification permission already granted');
      return;
    }

    // التحقق من mounted بعد async
    if (!context.mounted) return;

    // عرض Dialog
    showDialog(
      context: context,
      barrierDismissible: false, // لا يمكن إغلاقه بالضغط خارجه
      builder: (context) => const _NotificationPermissionDialogContent(),
    );
  }
}

class _NotificationPermissionDialogContent extends StatelessWidget {
  const _NotificationPermissionDialogContent();

  Future<void> _requestPermission(BuildContext context) async {
    // طلب الإذن من النظام
    final status = await Permission.notification.request();

    if (status.isGranted) {
      debugPrint('✅ Notification permission granted');
      if (context.mounted) {
        // إغلاق Dialog
        Navigator.of(context).pop();

        // رسالة نجاح
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ تم تفعيل الإشعارات بنجاح'),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      debugPrint('⚠️ Notification permission denied');
      if (context.mounted) {
        // رسالة تحذيرية لطيفة
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('يمكنك تفعيل الإشعارات لاحقاً من الإعدادات'),
            backgroundColor: Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1a4d2e), // أخضر إسلامي داكن
              Color(0xFF2d5f3f),
              Color(0xFF1a3d2e),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.3), // ذهبي
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // أيقونة إسلامية
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37), // ذهبي
                      const Color(0xFFB8960F),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // العنوان
              const Text(
                '🌙 تفعيل الإشعارات',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // الوصف
              Text(
                'هل تريد السماح بإرسال الإشعارات لك؟',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // الفوائد
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD4AF37).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBenefitItem('🕌', 'تذكير بأوقات الصلاة'),
                    const SizedBox(height: 8),
                    _buildBenefitItem('📿', 'إشعارات الأذكار اليومية'),
                    const SizedBox(height: 8),
                    _buildBenefitItem('🌟', 'تحديثات وتنبيهات مهمة'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // زر التفعيل
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => _requestPermission(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFD4AF37), // ذهبي
                          Color(0xFFB8960F),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Container(
                      alignment: Alignment.center,
                      child: const Text(
                        '✅ تفعيل الإشعارات',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // زر تخطي (اختياري)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'ربما لاحقاً',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem(String emoji, String text) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
