import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/session_service.dart';
import 'services/background_service.dart';
import 'services/universal_notification_service.dart';
import 'services/guest_mode_service.dart';
import 'screens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() async {
  // حماية التطبيق من الانهيار
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // التقاط أخطاء Flutter
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        debugPrint('🔴 Flutter Error: ${details.exception}');
      };

      // التقاط الأخطاء غير المعالجة
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('🔴 Platform Error: $error');
        return true;
      };

      // تهيئة Supabase
      await SupabaseService.initialize();

      // تهيئة نظام الإشعارات الشامل (يعمل على الويب والموبايل مثل تليجرام)
      try {
        await UniversalNotificationService.initialize(
          onNotificationReceived: (notification) {
            debugPrint('🔔 New notification: ${notification['title']}');
          },
        );
        debugPrint('✅ Notification service ready');
      } catch (e) {
        debugPrint('⚠️ Notification service failed: $e');
      }

      // التحقق من الجلسة المحفوظة
      final savedUser = await SessionService.getUserSession();

      // ✅ تفعيل وضع الزائر إذا لم توجد جلسة
      if (savedUser == null) {
        await GuestModeService.enableGuestMode();
        debugPrint('👥 Guest mode enabled - user can explore app');
      } else {
        await GuestModeService.disableGuestMode();
        debugPrint('✅ User logged in - guest mode disabled');
      }

      // ✅ تهيئة خدمة الخلفية (بدون بدء تلقائي)
      if (!kIsWeb && Platform.isAndroid) {
        try {
          await BackgroundServiceManager.initialize();
          debugPrint('✅ Background service initialized');

          // 🎯 بدء الخدمة فقط إذا كان المستخدم مسجل دخول والمراقبة مفعّلة
          if (savedUser != null && savedUser['id'] != null) {
            final userId = savedUser['id'];
            final monitoringEnabled = await SupabaseService.isMonitoringEnabled(
              userId,
            );

            if (monitoringEnabled) {
              debugPrint('🎯 Monitoring is enabled, starting service...');
              await BackgroundServiceManager.startService();
              await BackgroundServiceManager.setUserId(userId);
              debugPrint('✅ Background service auto-started');
            } else {
              debugPrint('ℹ️ Monitoring disabled, service not started');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Background service initialization failed: $e');
        }
      }

      // تشغيل التطبيق
      runApp(MyApp(initialUser: savedUser));
    },
    (error, stack) {
      debugPrint('🔴 Zone Error: $error');
    },
  );
}

class MyApp extends StatefulWidget {
  final Map<String, dynamic>? initialUser;

  const MyApp({super.key, this.initialUser});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _appName = 'تطبيق تسجيل الدخول';
  RealtimeChannel? _appNameChannel;

  @override
  void initState() {
    super.initState();
    _loadAppName();
    _subscribeToAppNameChanges();
  }

  Future<void> _loadAppName() async {
    final name = await SupabaseService.getAppName();
    if (mounted) {
      setState(() {
        _appName = name;
      });
    }
  }

  void _subscribeToAppNameChanges() {
    _appNameChannel = SupabaseService.subscribeToAppName((newName) {
      if (mounted) {
        setState(() {
          _appName = newName;
        });
        debugPrint('✅ App name updated to: $newName');
      }
    });
  }

  @override
  void dispose() {
    if (_appNameChannel != null) {
      SupabaseService.unsubscribeFromAppName(_appNameChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _appName, // استخدام الاسم الديناميكي
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 74, 79, 105),
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      // دعم اللغة العربية
      locale: const Locale('ar', 'SA'),
      // شاشة البداية الملكية أولاً
      home: SplashScreen(
        nextScreen: HomeScreen(
          user:
              widget.initialUser ??
              {
                'id': 'guest',
                'name': 'زائر',
                'username': 'guest',
                'is_guest': true,
              },
        ),
      ),
    );
  }
}
