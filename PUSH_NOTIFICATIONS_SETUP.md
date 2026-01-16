# 🔔 دليل إعداد Push Notifications

## الوضع الحالي ✅
- ✅ الإشعارات **محفوظة** في قاعدة البيانات
- ✅ المستخدم يراها عند فتح التطبيق
- ✅ Badge يظهر عدد الإشعارات الجديدة

## لتفعيل Push Notifications الحقيقية (تظهر والتطبيق مغلق):

### الخطوة 1: إعداد Firebase Project

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. أنشئ مشروع جديد أو استخدم مشروع موجود
3. أضف التطبيق (Android/iOS/Web)
4. حمّل ملف `google-services.json` (Android) أو `GoogleService-Info.plist` (iOS)

### الخطوة 2: إضافة المكتبات المطلوبة

في `pubspec.yaml`:
```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_messaging: ^14.7.9
```

ثم نفذ:
```bash
flutter pub get
```

### الخطوة 3: تكوين Android

في `android/app/build.gradle`:
```gradle
dependencies {
    implementation platform('com.google.firebase:firebase-bom:32.7.0')
    implementation 'com.google.firebase:firebase-messaging'
}
```

في `android/build.gradle`:
```gradle
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.0'
    }
}
```

في `android/app/build.gradle` (في نهاية الملف):
```gradle
apply plugin: 'com.google.gms.google-services'
```

### الخطوة 4: إنشاء خدمة Firebase Messaging

إنشاء ملف `lib/services/firebase_messaging_service.dart`:

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

// Background message handler
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 Background Message: ${message.notification?.title}');
}

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// تهيئة FCM
  static Future<void> initialize() async {
    // طلب الأذونات
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('✅ Notification permission granted');

      // جلب FCM Token
      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 FCM Token: $token');
        // حفظ في قاعدة البيانات
        // TODO: احصل على user_id من الجلسة الحالية
        // await SupabaseService.saveFCMToken(
        //   userId: currentUserId,
        //   token: token,
        //   platform: 'android', // أو 'ios' أو 'web'
        // );
      }

      // الاستماع للرسائل في الـ foreground
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📨 Foreground Message: ${message.notification?.title}');
        // يمكن عرض dialog أو snackbar
      });

      // عند الضغط على الإشعار
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('🔔 Notification tapped: ${message.notification?.title}');
        // يمكن التنقل لصفحة معينة
      });

      // Background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }
}
```

### الخطوة 5: تحديث main.dart

```dart
import 'package:firebase_core/firebase_core.dart';
import 'services/firebase_messaging_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // تهيئة Firebase
  await Firebase.initializeApp();
  
  // تهيئة Supabase
  await SupabaseService.initialize();
  
  // تهيئة FCM
  await FirebaseMessagingService.initialize();
  
  runApp(const MyApp());
}
```

### الخطوة 6: إنشاء Cloud Function لإرسال الإشعارات

في Supabase، أنشئ Edge Function:

```typescript
// supabase/functions/send-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  try {
    const { tokens, title, body } = await req.json()

    // استخدم Firebase Admin SDK لإرسال الإشعارات
    const response = await fetch(
      'https://fcm.googleapis.com/fcm/send',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `key=YOUR_FIREBASE_SERVER_KEY`
        },
        body: JSON.stringify({
          registration_ids: tokens,
          notification: {
            title: title,
            body: body,
            sound: 'default',
            badge: '1'
          }
        })
      }
    )

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500 }
    )
  }
})
```

### الخطوة 7: تحديث sendNotificationToAll في SupabaseService

في الكود الموجود، فك التعليق عن:
```dart
// استدعاء Edge Function
await client.functions.invoke('send-notification', body: {
  'tokens': tokens,
  'title': title,
  'body': body,
});
```

---

## 📊 الخلاصة:

### ✅ ما هو جاهز الآن:
1. ✅ **تخزين الإشعارات** - مضمون 100%
2. ✅ **عرض الإشعارات** في التطبيق
3. ✅ **Badge للإشعارات الجديدة**
4. ✅ **سجل كامل** للإشعارات

### ⚙️ ما يحتاج إعداد إضافي:
1. ⚠️ **Firebase Setup** - لإرسال push notifications
2. ⚠️ **Cloud Function** - لإرسال الإشعارات من الخادم
3. ⚠️ **FCM Integration** - للتطبيق

### 💡 الحل البديل (بدون Firebase):
- الإشعارات **محفوظة** في قاعدة البيانات
- عند فتح التطبيق، سيظهر Badge بعدد الإشعارات
- يمكن للمستخدم قراءتها جميعاً
- **مضمونة 100%** - لن تضيع أبداً

---

## 🚀 التوصية:

للبداية، النظام الحالي **كافٍ ومضمون**:
- ✅ جميع الإشعارات محفوظة
- ✅ المستخدم يراها عند فتح التطبيق
- ✅ لا تضيع أي رسالة

إذا كنت تريد push notifications حقيقية، اتبع الخطوات أعلاه.
