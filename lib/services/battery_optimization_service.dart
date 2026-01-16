import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// خدمة لإدارة تحسينات البطارية والسماح للخدمة بالعمل في الخلفية
class BatteryOptimizationService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.test7/battery',
  );

  /// طلب تعطيل تحسين البطارية للتطبيق
  static Future<void> requestBatteryOptimizationExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimization');
    } catch (e) {
      debugPrint('⚠️ Failed to request battery optimization: $e');
    }
  }

  /// التحقق من تعطيل تحسين البطارية
  static Future<bool> isBatteryOptimizationDisabled() async {
    try {
      final bool result = await _channel.invokeMethod(
        'isBatteryOptimizationDisabled',
      );
      return result;
    } catch (e) {
      debugPrint('⚠️ Failed to check battery optimization: $e');
      return false;
    }
  }
}
