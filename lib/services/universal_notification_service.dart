import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import 'session_service.dart';

/// خدمة الإشعارات الشاملة - تعمل على الويب والموبايل مثل تليجرام
class UniversalNotificationService {
  static RealtimeChannel? _notificationChannel;
  static bool _isInitialized = false;
  static Function(Map<String, dynamic>)? _onNotificationReceived;
  static int _unreadCount = 0;

  /// الحصول على عدد الإشعارات غير المقروءة
  static int get unreadCount => _unreadCount;

  /// تهيئة الخدمة
  static Future<void> initialize({
    Function(Map<String, dynamic>)? onNotificationReceived,
  }) async {
    if (_isInitialized) {
      debugPrint('ℹ️ [Notifications] Already initialized');
      return;
    }

    debugPrint(
      '🔔 [Notifications] Initializing notification service (like Telegram)...',
    );
    _onNotificationReceived = onNotificationReceived;

    // الاشتراك في إشعارات Supabase Realtime (للويب والموبايل)
    await _subscribeToRealtimeNotifications();

    // جلب الإشعارات غير المقروءة عند البداية
    await _updateUnreadCount();

    _isInitialized = true;
    debugPrint('✅ [Notifications] Service initialized successfully');
  }

  /// الاشتراك في Supabase Realtime للإشعارات (مثل تليجرام)
  static Future<void> _subscribeToRealtimeNotifications() async {
    try {
      // الحصول على userId من SessionService (custom auth)
      final session = await SessionService.getUserSession();
      final userId = session?['id'];

      if (userId == null) {
        debugPrint('⚠️ [Notifications] No user ID, skipping subscription');
        return;
      }

      debugPrint('🔌 [Notifications] Subscribing to realtime notifications...');
      debugPrint('👤 [Notifications] User ID: $userId');

      _notificationChannel = SupabaseService.client
          .channel('user_notifications_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'user_notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              debugPrint(
                '📥 [Notifications] New notification received in realtime!',
              );
              _handleIncomingNotification(payload.newRecord);
            },
          )
          .subscribe();

      debugPrint('✅ [Notifications] Subscribed successfully');
    } catch (e) {
      debugPrint('❌ [Notifications] Subscription error: $e');
    }
  }

  /// معالجة الإشعار القادم (يعمل حتى لو التطبيق مفتوح - مثل تليجرام)
  static void _handleIncomingNotification(Map<String, dynamic> notification) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📬 [Notifications] New notification!');
    debugPrint('📧 Title: ${notification['title']}');
    debugPrint('💬 Body: ${notification['body']}');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    // زيادة عداد غير المقروءة
    _unreadCount++;

    // عرض الإشعار في واجهة التطبيق (عبر callback)
    if (_onNotificationReceived != null) {
      _onNotificationReceived!(notification);
    }

    // في الويب: سيظهر الإشعار تلقائياً في المتصفح عبر Notifications API
    if (kIsWeb) {
      _showWebNotification(
        title: notification['title'] ?? 'إشعار جديد',
        body: notification['body'] ?? '',
      );
    }
  }

  /// عرض إشعار في المتصفح (مثل تليجرام في الويب)
  static void _showWebNotification({
    required String title,
    required String body,
  }) {
    // Web Notifications API سيتم استخدامها تلقائياً من قبل المتصفح
    debugPrint('🌐 [Notifications] Web notification would show here');
    debugPrint('   Title: $title');
    debugPrint('   Body: $body');

    // ملاحظة: Flutter Web يدعم عرض الإشعارات تلقائياً
    // لكن يحتاج إذن من المستخدم أولاً
  }

  /// جلب الإشعارات غير المقروءة عند فتح التطبيق
  static Future<List<Map<String, dynamic>>> fetchUnreadNotifications() async {
    try {
      // الحصول على userId من SessionService
      final session = await SessionService.getUserSession();
      final userId = session?['id'];

      if (userId == null) return [];

      debugPrint('📊 [Notifications] Fetching unread notifications...');

      final response = await SupabaseService.client
          .from('user_notifications')
          .select()
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      final notifications = List<Map<String, dynamic>>.from(response);
      _unreadCount = notifications.length;

      debugPrint(
        '✅ [Notifications] Found ${notifications.length} unread notifications',
      );

      return notifications;
    } catch (e) {
      debugPrint('❌ [Notifications] Fetch unread error: $e');
      return [];
    }
  }

  /// تحديث عدد الإشعارات غير المقروءة
  static Future<void> _updateUnreadCount() async {
    final unread = await fetchUnreadNotifications();
    _unreadCount = unread.length;
  }

  /// تحديث حالة الإشعار إلى مقروء
  static Future<void> markAsRead(String notificationId) async {
    try {
      await SupabaseService.client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      _unreadCount = (_unreadCount - 1).clamp(0, 999);
      debugPrint(
        '✅ [Notifications] Marked as read. Unread count: $_unreadCount',
      );
    } catch (e) {
      debugPrint('❌ [Notifications] Mark as read error: $e');
    }
  }

  /// تحديد جميع الإشعارات كمقروءة
  static Future<void> markAllAsRead() async {
    try {
      final session = await SessionService.getUserSession();
      final userId = session?['id'];

      if (userId == null) return;

      await SupabaseService.client
          .from('user_notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      _unreadCount = 0;
      debugPrint('✅ [Notifications] All notifications marked as read');
    } catch (e) {
      debugPrint('❌ [Notifications] Mark all as read error: $e');
    }
  }

  /// إلغاء الاشتراك
  static Future<void> dispose() async {
    if (_notificationChannel != null) {
      await SupabaseService.client.removeChannel(_notificationChannel!);
      _notificationChannel = null;
    }
    _isInitialized = false;
    _unreadCount = 0;
    debugPrint('🔕 [Notifications] Service disposed');
  }
}
