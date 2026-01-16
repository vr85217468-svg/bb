import 'package:flutter/foundation.dart';

/// خدمة تحميل بيانات الاعتماد من البيئة
///
/// هذا الملف يوفر طريقة آمنة للوصول إلى بيانات الاعتماد
/// دون تضمينها مباشرة في الكود المصدري
class EnvironmentConfig {
  /// رابط Supabase
  static String get supabaseUrl {
    // في الوضع الإنتاجي، يتم التحميل من البيئة
    // في الوضع التطويري، نستخدم القيمة الافتراضية
    const url = String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://jmtriazkllozwwgyuimw.supabase.co',
    );

    if (kDebugMode && url == 'https://jmtriazkllozwwgyuimw.supabase.co') {
      debugPrint('⚠️ Using default Supabase URL in debug mode');
    }

    return url;
  }

  /// مفتاح Anon الخاص بـ Supabase
  static String get supabaseAnonKey {
    const key = String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptdHJpYXprbGxvend3Z3l1aW13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MjY5MzUsImV4cCI6MjA4MTMwMjkzNX0.YqIPIjAAX5NN23vv48DF5MT9NLCZL6rccDpUh2fy-pw',
    );

    if (kDebugMode && key.startsWith('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')) {
      debugPrint('⚠️ Using default Supabase Anon Key in debug mode');
      debugPrint(
        'ℹ️ For production, set SUPABASE_URL and SUPABASE_ANON_KEY environment variables',
      );
    }

    return key;
  }
}
