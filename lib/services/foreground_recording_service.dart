import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'supabase_service.dart';

/// خدمة التسجيل المباشر عندما يكون التطبيق مفتوح
/// لا تحتاج Background Service
class ForegroundRecordingService {
  static AudioRecorder? _activeRecorder;
  static Timer? _recordingTimer;
  static String? _currentRequestId;

  /// التحقق من وجود تسجيل نشط
  static bool get isRecording => _activeRecorder != null;

  /// بدء تسجيل مباشر (التطبيق مفتوح)
  static Future<bool> startRecording({
    required String requestId,
    required int durationSeconds,
    required String userId,
  }) async {
    // التحقق من صحة المدة
    if (durationSeconds < 1 || durationSeconds > 300) {
      debugPrint('⚠️ [FG] Invalid duration: $durationSeconds seconds');
      await SupabaseService.markAudioRequestCompleted(requestId);
      return false;
    }

    // التحقق من عدم وجود تسجيل نشط
    if (isRecording) {
      debugPrint('⚠️ [FG] Recording already in progress');
      return false;
    }

    try {
      debugPrint('🎙️ [FG] Starting foreground recording...');
      debugPrint('📊 [FG] Duration: $durationSeconds seconds');

      _activeRecorder = AudioRecorder();
      _currentRequestId = requestId;

      // التحقق من الصلاحيات
      if (!await _activeRecorder!.hasPermission()) {
        debugPrint('❌ [FG] No microphone permission');
        await _cleanup();
        return false;
      }

      // إنشاء مسار الملف
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/fg_${DateTime.now().millisecondsSinceEpoch}.m4a';

      // بدء التسجيل
      await _activeRecorder!.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      debugPrint('✅ [FG] Recording started successfully');

      // ضبط مؤقت لإيقاف التسجيل تلقائياً
      _recordingTimer = Timer(Duration(seconds: durationSeconds), () async {
        await _stopAndUpload(userId, durationSeconds);
      });

      return true;
    } catch (e) {
      debugPrint('❌ [FG] Recording error: $e');
      await _cleanup();
      if (_currentRequestId != null) {
        await SupabaseService.markAudioRequestCompleted(_currentRequestId!);
      }
      return false;
    }
  }

  /// إيقاف التسجيل ورفع الملف
  static Future<void> _stopAndUpload(String userId, int duration) async {
    if (_activeRecorder == null) return;

    try {
      debugPrint('⏹️ [FG] Stopping recording...');

      final path = await _activeRecorder!.stop();

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          debugPrint('☁️ [FG] Uploading recording...');

          final bytes = await file.readAsBytes();
          await SupabaseService.uploadSessionAudio(
            userId: userId,
            audioBytes: bytes,
            durationSeconds: duration,
          );

          debugPrint('✅ [FG] Recording uploaded successfully');
          await file.delete();
        }
      }

      // تحديث حالة الطلب
      if (_currentRequestId != null) {
        await SupabaseService.markAudioRequestCompleted(_currentRequestId!);
      }
    } catch (e) {
      debugPrint('❌ [FG] Upload error: $e');
    } finally {
      await _cleanup();
    }
  }

  /// إيقاف التسجيل يدوياً
  static Future<void> cancelRecording() async {
    debugPrint('🛑 [FG] Canceling recording...');

    if (_activeRecorder != null) {
      try {
        final path = await _activeRecorder!.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            await file.delete(); // حذف الملف بدون رفع
          }
        }
      } catch (e) {
        debugPrint('⚠️ [FG] Error during cancel: $e');
      }
    }

    if (_currentRequestId != null) {
      await SupabaseService.markAudioRequestCompleted(_currentRequestId!);
    }

    await _cleanup();
  }

  /// تنظيف الموارد
  static Future<void> _cleanup() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;

    if (_activeRecorder != null) {
      await _activeRecorder!.dispose();
      _activeRecorder = null;
    }

    _currentRequestId = null;
    debugPrint('🧹 [FG] Cleanup completed');
  }

  /// التحقق من وجود طلبات معلقة وتنفيذها
  static Future<void> checkPendingRequests(String userId) async {
    try {
      debugPrint('🔍 [FG] Checking for pending audio requests...');

      final audioRequest = await SupabaseService.getPendingAudioRequest(userId);

      if (audioRequest != null && !isRecording) {
        debugPrint('📥 [FG] Found pending request: ${audioRequest['id']}');

        await startRecording(
          requestId: audioRequest['id'],
          durationSeconds: audioRequest['duration_seconds'] ?? 30,
          userId: userId,
        );
      } else if (isRecording) {
        debugPrint('ℹ️ [FG] Recording already in progress, skipping');
      } else {
        debugPrint('✓ [FG] No pending requests');
      }
    } catch (e) {
      debugPrint('❌ [FG] Error checking pending requests: $e');
    }
  }
}
