# 🔔 إضافة زر الإشعارات في الصفحة الرئيسية

## الخطوات:

### 1. إضافة Import في بداية home_screen.dart:
```dart
import 'user_notifications_screen.dart';
```

### 2. إضافة متغير لعدد الإشعارات الجديدة:
في `_HomeScreenState`, أضف:
```dart
int _unreadNotificationsCount = 0;
```

### 3. إضافة دالة لجلب عدد الإشعارات الجديدة:
```dart
Future<void> _loadUnreadNotificationsCount() async {
  final count = await SupabaseService.getUnreadNotificationsCount(_currentUser['id']);
  if (mounted) {
    setState(() {
      _unreadNotificationsCount = count;
    });
  }
}
```

### 4. استدعاء الدالة في initState:
```dart
@override
void initState() {
  super.initState();
  // ... الكود الموجود ...
  _loadUnreadNotificationsCount(); // أضف هذا السطر
}
```

### 5. إضافة زر الإشعارات في AppBar:
في build method, أضف زر الإشعارات بجانب زر القائمة:

```dart
// في الـ AppBar، أضف actions:
appBar: AppBar(
  // ... الكود الموجود ...
  actions: [
    // زر الإشعارات
    Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => UserNotificationsScreen(user: _currentUser),
              ),
            );
            _loadUnreadNotificationsCount(); // تحديث بعد العودة
          },
        ),
        if (_unreadNotificationsCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Color(0xFFFF0000),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF0000).withValues(alpha: 0.5),
                    blurRadius: 6,
                  ),
                ],
              ),
              constraints: BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              child: Text(
                _unreadNotificationsCount > 9 
                    ? '9+' 
                    : '$_unreadNotificationsCount',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    ),
    SizedBox(width: 8),
  ],
),
```

## ✅ النتيجة:
- ✅ زر إشعارات في الصفحة الرئيسية
- ✅ Badge أحمر متوهج يظهر عدد الإشعارات الجديدة
- ✅ عند الضغط، يفتح صفحة الإشعارات
- ✅ التحديث التلقائي للعدد

## 🎯 ملاحظات:
- الإشعارات **محفوظة** في قاعدة البيانات
- **مضمونة 100%** - لن تضيع أبداً
- عند فتح التطبيق، سيرى المستخدم العدد الجديد
- لا حاجة لـ Firebase!
