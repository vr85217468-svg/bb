import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// خدمة التنظيف التلقائي لغرف الصوت
/// تُنظف المشاركين الخاملين والغرف الفارغة بشكل دوري
class VoiceRoomCleanupService {
  static Timer? _cleanupTimer;
  static final _client = Supabase.instance.client;
  static bool _isRunning = false;

  /// بدء خدمة التنظيف التلقائي
  /// يتم الاستدعاء كل 5 دقائق افتراضياً
  static void start({Duration interval = const Duration(minutes: 5)}) {
    if (_isRunning) {
      debugPrint('⚠️ Cleanup service already running');
      return;
    }

    debugPrint('🧹 Starting voice room cleanup service...');
    _isRunning = true;

    // تنفيذ فوري أول مرة
    _performCleanup();

    // ثم تنفيذ دوري
    _cleanupTimer = Timer.periodic(interval, (_) {
      _performCleanup();
    });
  }

  /// إيقاف خدمة التنظيف
  static void stop() {
    if (_cleanupTimer != null) {
      _cleanupTimer!.cancel();
      _cleanupTimer = null;
      _isRunning = false;
      debugPrint('🛑 Voice room cleanup service stopped');
    }
  }

  /// تنفيذ عملية التنظيف
  static Future<void> _performCleanup() async {
    try {
      debugPrint('🧹 Running cleanup...');

      // 1. تنظيف المشاركين الخاملين (آخر نشاط أكثر من 5 دقائق)
      await _cleanupStaleParticipants();

      // 2. تنظيف الغرف الخاملة
      await _cleanupInactiveRooms();

      debugPrint('✅ Cleanup completed successfully');
    } catch (e) {
      debugPrint('❌ Cleanup error: $e');
    }
  }

  /// تنظيف المشاركين الخاملين
  static Future<void> _cleanupStaleParticipants() async {
    try {
      // حذف المشاركين الذين last_seen أكثر من 5 دقائق
      await _client.rpc('cleanup_stale_participants');
      debugPrint('🧹 Stale participants cleaned');
    } catch (e) {
      debugPrint('⚠️ Stale participants cleanup failed: $e');
      // Fallback: استخدام DELETE مباشر
      try {
        await _client
            .from('voice_room_participants')
            .delete()
            .lt(
              'last_seen',
              DateTime.now()
                  .subtract(const Duration(minutes: 5))
                  .toIso8601String(),
            );
        debugPrint('✅ Fallback cleanup succeeded');
      } catch (e2) {
        debugPrint('❌ Fallback cleanup also failed: $e2');
      }
    }
  }

  /// تنظيف الغرف الخاملة
  static Future<void> _cleanupInactiveRooms() async {
    try {
      // استدعاء دالة التنظيف
      await _client.rpc('cleanup_inactive_voice_rooms');
      debugPrint('🧹 Inactive rooms cleaned');
    } catch (e) {
      debugPrint('⚠️ Inactive rooms cleanup failed: $e');
      // Fallback: استخدام UPDATE/DELETE مباشر
      try {
        // تعطيل الغرف الفارغة القديمة
        await _client
            .from('voice_rooms')
            .update({'is_active': false})
            .eq('participants_count', 0)
            .eq('is_active', true)
            .lt(
              'updated_at',
              DateTime.now()
                  .subtract(const Duration(minutes: 30))
                  .toIso8601String(),
            );

        // حذف الغرف المعطلة القديمة جداً
        await _client
            .from('voice_rooms')
            .delete()
            .eq('is_active', false)
            .lt(
              'updated_at',
              DateTime.now()
                  .subtract(const Duration(hours: 24))
                  .toIso8601String(),
            );

        debugPrint('✅ Fallback inactive rooms cleanup succeeded');
      } catch (e2) {
        debugPrint('❌ Fallback  inactive rooms cleanup also failed: $e2');
      }
    }
  }

  /// تنفيذ يدوي للتنظيف (للاستخدام عند الحاجة)
  static Future<void> runManualCleanup() async {
    debugPrint('🧹 Running manual cleanup...');
    await _performCleanup();
  }

  /// الحصول على حالة الخدمة
  static bool get isRunning => _isRunning;
}
