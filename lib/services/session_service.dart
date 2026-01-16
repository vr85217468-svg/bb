import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// خدمة إدارة الجلسات
/// تحفظ بيانات المستخدم محلياً لتذكر تسجيل الدخول
class SessionService {
  static const String _userKey = 'logged_in_user';

  /// حفظ بيانات المستخدم
  static Future<void> saveUserSession(Map<String, dynamic> user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user));
    } catch (e) {
      // تجاهل الأخطاء - لا نريد انهيار التطبيق
    }
  }

  /// استرجاع بيانات المستخدم المحفوظة
  static Future<Map<String, dynamic>?> getUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_userKey);
      if (userJson != null && userJson.isNotEmpty) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    } catch (e) {
      // تجاهل الأخطاء - نعيد null
    }
    return null;
  }

  /// التحقق من وجود جلسة محفوظة
  static Future<bool> hasSession() async {
    try {
      final user = await getUserSession();
      return user != null && user['id'] != null;
    } catch (e) {
      return false;
    }
  }

  /// مسح الجلسة عند تسجيل الخروج
  static Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }
}
