// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:html' as html;
import 'dart:ui' as ui;

/// خدمة المكالمات الصوتية للويب فقط
/// تستخدم Jitsi Meet عبر iframe
class WebVoiceCallService {
  static html.IFrameElement? _iframe;
  static String? _currentRoomName;
  static String? _currentUserId;
  static final _client = Supabase.instance.client;
  static bool _isRegistered = false;

  /// بدء المكالمة في المتصفح
  static Future<void> joinCall({
    required String userName,
    required String roomName,
    String? userId,
    String? userAvatar,
  }) async {
    try {
      debugPrint('🌐 ========== WEB CALL (IFRAME) ==========');
      debugPrint('🏠 Room: $roomName');
      debugPrint('👤 User: $userName');

      _currentRoomName = roomName;
      _currentUserId = userId;

      // تسجيل في قاعدة البيانات
      if (userId != null) {
        await _client.from('voice_room_participants').upsert({
          'room_name': roomName,
          'user_id': userId,
          'last_seen': DateTime.now().toIso8601String(),
        }, onConflict: 'room_name,user_id');
        debugPrint('✅ Registered in database');
      }

      // إنشاء iframe لـ Jitsi Meet
      _iframe = html.IFrameElement()
        ..src = _buildJitsiUrl(roomName, userName)
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none'
        ..allow =
            'camera; microphone; fullscreen; display-capture; autoplay; clipboard-write'; // ✅ إضافة إذن الكاميرا

      final viewType = 'jitsi-meet-$roomName';

      // تسجيل الـ iframe في platformViewRegistry
      if (!_isRegistered) {
        // ignore: undefined_prefixed_name
        ui.platformViewRegistry.registerViewFactory(
          viewType,
          (int viewId) => _iframe!,
        );
        _isRegistered = true;
        debugPrint('✅ Iframe registered in platformViewRegistry');
      }

      debugPrint('✅ Jitsi iframe created and ready');
      debugPrint('🎤 Browser will request microphone permission');
      debugPrint('🌐 ========== WEB CALL READY ==========');
    } catch (e, stackTrace) {
      debugPrint('❌ Error in web call: $e');
      debugPrint('Stack: $stackTrace');
      await _removeParticipant(userId, roomName);
      rethrow;
    }
  }

  /// بناء URL لـ Jitsi Meet
  static String _buildJitsiUrl(String roomName, String userName) {
    final baseUrl = 'https://meet.jit.si/$roomName';

    // استخدام URL parameters بدلاً من hash
    final params = Uri(queryParameters: {'displayName': userName});

    // إضافة config في hash
    final config = [
      'config.startWithAudioMuted=false',
      'config.startWithVideoMuted=false', // ✅ تفعيل الفيديو
      'config.prejoinPageEnabled=false',
      'config.requireDisplayName=false',
      'config.resolution=720', // ✅ جودة الفيديو
      'interfaceConfig.SHOW_JITSI_WATERMARK=false',
      'interfaceConfig.SHOW_BRAND_WATERMARK=false',
    ].join('&');

    final fullUrl = '$baseUrl?${params.query}#$config';
    debugPrint('📍 Jitsi URL: $fullUrl');
    return fullUrl;
  }

  /// إنهاء المكالمة
  static Future<void> hangUp() async {
    debugPrint('📴 Hanging up web call...');
    if (_iframe != null) {
      _iframe!.remove();
      _iframe = null;
    }
    await _removeParticipant(_currentUserId, _currentRoomName);
    _currentRoomName = null;
    _currentUserId = null;
    _isRegistered = false;
  }

  /// إزالة المشارك
  static Future<void> _removeParticipant(
    String? userId,
    String? roomName,
  ) async {
    if (userId == null || roomName == null) return;
    try {
      await _client
          .from('voice_room_participants')
          .delete()
          .eq('room_name', roomName)
          .eq('user_id', userId);
      debugPrint('✅ Participant removed from database');
    } catch (e) {
      debugPrint('❌ Error removing participant: $e');
    }
  }

  /// اسم الـ view للـ widget
  static String getViewType(String roomName) => 'jitsi-meet-$roomName';
}
