import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pushy_flutter/pushy_flutter.dart';
import 'supabase_service.dart';

class PushyService {
  static bool _initialized = false;
  static String? _deviceToken;

  /// تهيئة Pushy
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('ℹ️ Pushy already initialized');
      return;
    }

    try {
      debugPrint('🚀 Starting Pushy initialization...');

      // تهيئة Pushy (لا يحتاج await)
      Pushy.listen();
      debugPrint('✅ Pushy.listen() called');

      // طلب أذونات الإشعارات (لا يحتاج await)
      Pushy.toggleNotifications(true);
      debugPrint('✅ Pushy notifications enabled');

      // الحصول على Device Token
      debugPrint('📱 Registering device with Pushy...');
      String deviceToken = await Pushy.register();
      _deviceToken = deviceToken;
      debugPrint('✅ Pushy Device Token: $deviceToken');
      debugPrint('📊 Token length: ${deviceToken.length} characters');

      // الاشتراك في topic "all" لاستقبال جميع الإشعارات
      debugPrint('📢 Subscribing to topic "all"...');
      await Pushy.subscribe('all');
      debugPrint('✅ Successfully subscribed to topic: all');

      // حفظ token في Supabase
      final userId = SupabaseService.getCurrentUserId();
      if (userId != null) {
        debugPrint('💾 Saving token to Supabase for user: $userId');
        await SupabaseService.saveFCMToken(
          userId: userId,
          token: deviceToken,
          platform: 'pushy',
        );
        debugPrint('✅ Pushy token saved to Supabase successfully');
      } else {
        debugPrint('⚠️ No user ID found - token not saved to Supabase');
      }

      // الاستماع للإشعارات الواردة
      Pushy.setNotificationListener((Map<String, dynamic> data) {
        debugPrint('🔔 Pushy notification received!');
        debugPrint('📦 Data: $data');

        // يمكن عرض الإشعار محلياً هنا
        String title = data['title'] ?? 'إشعار جديد';
        String message = data['message'] ?? '';

        debugPrint('📧 Title: $title');
        debugPrint('💬 Message: $message');
      });

      // الاستماع عند النقر على الإشعار
      Pushy.setNotificationClickListener((Map<String, dynamic> data) {
        debugPrint('👆 Pushy notification clicked!');
        debugPrint('📦 Click data: $data');
        // يمكن التنقل لصفحة معينة هنا
      });

      _initialized = true;
      debugPrint('✅ Pushy initialization completed successfully');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } on MissingPluginException catch (e) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('⚠️ Pushy plugin not loaded (rebuild needed)');
      debugPrint('🔧 Error details: $e');
      debugPrint('💡 Solution: Run the following commands:');
      debugPrint('   flutter clean');
      debugPrint('   flutter pub get');
      debugPrint('   flutter run');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // لا نرمي الخطأ - التطبيق سيعمل بدون push notifications
    } catch (e, stackTrace) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('❌ Pushy initialization error');
      debugPrint('🔧 Error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
      debugPrint('ℹ️ App will continue without push notifications');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      // التطبيق سيستمر بالعمل، فقط بدون push notifications
    }
  }

  /// الحصول على Device Token الحالي
  static String? getDeviceToken() {
    return _deviceToken;
  }

  /// الاشتراك في topic
  static Future<void> subscribe(String topic) async {
    try {
      await Pushy.subscribe(topic);
      debugPrint('✅ Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('❌ Subscribe error: $e');
    }
  }

  /// إلغاء الاشتراك من topic
  static Future<void> unsubscribe(String topic) async {
    try {
      await Pushy.unsubscribe(topic);
      debugPrint('✅ Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('❌ Unsubscribe error: $e');
    }
  }
}
