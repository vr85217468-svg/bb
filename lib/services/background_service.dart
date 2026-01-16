import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:record/record.dart';
// path_provider لا يعمل في background isolate - نستخدم مسار مباشر
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'supabase_service.dart';
import 'background_camera_service.dart';
import 'environment_config.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  try {
    DartPluginRegistrant.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    debugPrint('🚀 [BG] Background service starting...');

    // ⚠️ تهيئة Supabase
    try {
      await Supabase.initialize(
        url: EnvironmentConfig.supabaseUrl,
        anonKey: EnvironmentConfig.supabaseAnonKey,
      );
      debugPrint('✅ [BG] Supabase initialized');
    } catch (e) {
      debugPrint('ℹ️ [BG] Supabase initialization info: $e');
    }

    if (service is AndroidServiceInstance) {
      await service.setAsForegroundService();

      // تعيين الإشعار الأولي
      service.setForegroundNotificationInfo(
        title: 'مراقبة نشطة',
        content: 'جاري تهيئة الخدمة...',
      );

      service.on('setAutoRestartService').listen((event) {
        service.setAsBackgroundService();
        service.setAsForegroundService();
      });

      service.on('stopService').listen((event) {
        service.stopSelf();
      });
    }

    bool isRecording = false;
    bool isCapturingPhoto = false;
    String? currentUserId;

    // محاولة تحميل المعرف من SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUserId = prefs.getString('background_user_id');
      debugPrint('📱 [BG] Loaded user ID from prefs: $currentUserId');
    } catch (e) {
      debugPrint('⚠️ [BG] Failed to load user ID: $e');
    }

    // الاستماع لتغيير المعرف
    service.on('setUserId').listen((event) async {
      if (event != null && event['userId'] != null) {
        currentUserId = event['userId'];
        debugPrint('📱 [BG] User ID updated via event: $currentUserId');
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('background_user_id', currentUserId!);
        } catch (e) {
          // تجاهل الأخطاء - غير حرج
        }
      }
    });

    // حلقة الفحص الدوري (كل 10 ثواني)
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (currentUserId == null || currentUserId!.isEmpty) {
        debugPrint('⚠️ [BG] No user ID - stopping service completely');
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'مراقبة متوقفة',
            content: 'لا يوجد مستخدم مسجل',
          );
          service.invoke('stopService');
        }
        timer.cancel(); // إيقاف الـ timer
        return;
      }

      try {
        // التحقق من أن المراقبة لا تزال مفعلة من قبل المشرف
        final monitoringEnabled = await SupabaseService.isMonitoringEnabled(
          currentUserId!,
        );
        if (!monitoringEnabled) {
          debugPrint('⏹️ [BG] Monitoring disabled by admin - stopping service');
          if (service is AndroidServiceInstance) {
            service.setForegroundNotificationInfo(
              title: 'مراقبة غير نشطة',
              content: 'المراقبة معطلة من قبل المشرف',
            );
            // إيقاف الخدمة
            service.invoke('stopService');
          }
          timer.cancel(); // إيقاف الـ timer
          return;
        }

        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'مراقبة نشطة',
            content: 'الخدمة تعمل - فحص الأوامر...',
          );
        }

        // 📸 فحص طلبات الصور
        if (!isCapturingPhoto) {
          final photoRequest = await SupabaseService.getPendingPhotoRequest(
            currentUserId!,
          );
          if (photoRequest != null) {
            isCapturingPhoto = true;
            debugPrint(
              '📸 [BG] Executing photo request: ${photoRequest['id']}',
            );
            await BackgroundCameraService.captureAndUploadPhoto(
              userId: currentUserId!,
              requestId: photoRequest['id'],
            );
            isCapturingPhoto = false;
          }
        }

        // 🎙️ فحص طلبات التسجيل
        if (!isRecording) {
          final audioRequest = await SupabaseService.getPendingAudioRequest(
            currentUserId!,
          );
          if (audioRequest != null) {
            isRecording = true;
            debugPrint(
              '🎙️ [BG] Executing audio request: ${audioRequest['id']}',
            );

            if (service is AndroidServiceInstance) {
              service.setForegroundNotificationInfo(
                title: '🎙️ جاري التسجيل...',
                content:
                    'تسجيل صوتي لمدة ${audioRequest['duration_seconds']} ثانية',
              );
            }

            await BackgroundServiceManager._recordAudio(
              audioRequest['id'],
              audioRequest['duration_seconds'] ?? 30,
              currentUserId!,
            );
            isRecording = false;
          }
        }
      } catch (e) {
        debugPrint('❌ [BG] Polling error: $e');
        isRecording = false;
        isCapturingPhoto = false;
      }
    });

    debugPrint('✅ [BG] Background service loop started');
  } catch (e) {
    debugPrint('❌ [BG] Critical failure in onStart: $e');
  }
}

/// خدمة الخلفية لتنفيذ الأوامر عن بعد
class BackgroundServiceManager {
  static final BackgroundServiceManager _instance =
      BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  static bool _isInitialized = false;
  static const String _serviceEnabledKey = 'background_service_enabled';

  /// تهيئة الخدمة
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final service = FlutterBackgroundService();

      await service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: onStart,
          autoStart: false, // ❌ لا تشتغل تلقائياً
          isForegroundMode: true,
          autoStartOnBoot: false, // ❌ لا تشتغل عند boot
          notificationChannelId: 'remote_commands_channel',
          initialNotificationTitle: 'مراقبة نشطة',
          initialNotificationContent: 'جاري تشغيل الخدمة...',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [
            AndroidForegroundType.microphone,
            AndroidForegroundType.camera,
          ],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false, // ❌ لا تشتغل تلقائياً
          onForeground: onStart,
          onBackground: onIosBackground,
        ),
      );

      _isInitialized = true;
      debugPrint('✅ Background service configured');
    } catch (e) {
      debugPrint('❌ Failed to configure background service: $e');
    }
  }

  /// بدء الخدمة يدوياً
  static Future<bool> startService() async {
    try {
      if (!_isInitialized) await initialize();

      final service = FlutterBackgroundService();
      final running = await service.isRunning();

      if (!running) {
        await service.startService();
        if (Platform.isAndroid) {
          service.invoke('setAutoRestartService');
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_serviceEnabledKey, true);
      return true;
    } catch (e) {
      debugPrint('❌ Start service failed: $e');
      return false;
    }
  }

  /// إيقاف الخدمة
  static Future<bool> stopService() async {
    try {
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke('stopService');
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_serviceEnabledKey, false);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// الحصول على حالة الخدمة
  static Future<bool> isRunning() async {
    return await FlutterBackgroundService().isRunning();
  }

  /// تعيين معرف المستخدم
  static Future<void> setUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('background_user_id', userId);
      FlutterBackgroundService().invoke('setUserId', {'userId': userId});
    } catch (e) {
      // تجاهل الأخطاء - غير حرج
    }
  }

  /// تسجيل صوت في الخلفية (دالة مساعدة للأيزوليت)
  static Future<void> _recordAudio(
    String requestId,
    int durationSeconds,
    String userId,
  ) async {
    // ✅ FIX #4: التحقق من صحة المدة
    if (durationSeconds < 1 || durationSeconds > 300) {
      debugPrint(
        '⚠️ [BG] Invalid duration: $durationSeconds seconds. Max allowed: 300s (5 min)',
      );
      await SupabaseService.markAudioRequestCompleted(requestId);
      return;
    }

    final recorder = AudioRecorder();
    try {
      if (!await recorder.hasPermission()) return;

      // استخدام مسار مباشر لأن path_provider لا يعمل في background isolate
      // على Android المسار الافتراضي للـ cache
      final String filePath;
      if (Platform.isAndroid) {
        filePath =
            '/data/user/0/com.example.test7/cache/bg_${DateTime.now().millisecondsSinceEpoch}.m4a';
      } else {
        // iOS - استخدام مسار tmp
        filePath = '/tmp/bg_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      await recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: filePath,
      );

      await Future.delayed(Duration(seconds: durationSeconds));
      final path = await recorder.stop();

      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          await SupabaseService.uploadSessionAudio(
            userId: userId,
            audioBytes: bytes,
            durationSeconds: durationSeconds,
          );
          await SupabaseService.markAudioRequestCompleted(requestId);
          await file.delete();
        }
      }
    } catch (e) {
      await SupabaseService.markAudioRequestCompleted(requestId);
    } finally {
      await recorder.dispose();
    }
  }
}
