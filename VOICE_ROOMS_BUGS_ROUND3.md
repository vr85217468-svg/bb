# الأخطاء الخفية - الجولة الثالث ة 🔍

## ❌ مشكلة #10: Race Condition في registerEventHandler

**الموقع:** `agora_voice_service.dart:60-103`

**المشكلة:**
```dart
static Future<int?> joinChannel(...) async {
  // ...
  _engine!.registerEventHandler(...); // ❌ كل مرة يُسجل handlers جديدة!
  
  await _engine!.joinChannel(...);
}
```

**السيناريو:**
```
1. مستخدم ينضم لغرفة 1 → registerEventHandler مرة واحدة
2. مستخدم يغادر ويدخل غرفة 2 → registerEventHandler مرة ثانية!
3. النتيجة: نفس الـ event يُطلق مرتين!
```

**التأثير:**
- 🐛 **Duplicat e callbacks**: `onUserJoined` يُستدعى مرتين
- 📊 **عداد خاطئ**: _loadParticipants() يُطلق مرتين
- 💥 **استهلاك ذاكرة**: كل join يضيف handlers جديدة

**الحل:**
```dart
static RtcEngineEventHandler? _eventHandler;

static Future<int?> joinChannel(...) async {
  // ...
  // ✅ تسجيل مرة واحدة فقط
  if (_eventHandler == null) {
    _eventHandler = RtcEngineEventHandler(...);
    _engine!.registerEventHandler(_eventHandler!);
  }
  
  // تحديث الـ callbacks
  _onUserJoinedCallback = onUserJoined;
  _onUserOfflineCallback = onUserOffline;
  _onActiveSpeakerCallback = onActiveSpeaker;
}
```

---

## ❌ مشكلة #11: participants_count لا يتحدث تلقائياً

**الموقع:** الكود بالكامل

**المشكلة:**
النظام يعتمد على **trigger في قاعدة البيانات** لتحديث `participants_count`، لكن:

1. لا يوجد كود Flutter يحدثه يدوياً
2. إذا فشل الـ trigger؟ العداد خاطئ للأبد!
3. لا يوجد sync mechanism

**التأثير:**
- 📊 **عداد غير دقيق**: قد لا يعكس الواقع
- ⚡ **اعتماد على triggers**: خطير
- 🐛 **لا fallback**: إذا فشل trigger

**الحل:**
```dart
Future<void> _joinChannel() async {
  // ... بعد الانضمام بنجاح
  
  // ✅ تحديث يدوي كـ fallback
  await _client.rpc('increment_room_participants', params: {
    'room_name_param': widget.room['room_name'],
  });
}

Future<void> _removeParticipantFromDB() async {
  await _client.from('voice_room_participants').delete()...;
  
  // ✅ تحديث يدوي
  await _client.rpc('decrement_room_participants', params: {
    'room_name_param': widget.room['room_name'],
  });
}
```

---

## ❌ مشكلة #12: _joinRoom تستخدم participants_count القديم

**الموقع:** `voice_rooms_screen.dart:148-177`

**المشكلة:**
```dart
void _joinRoom(Map<String, dynamic> room) async {
  final currentCount = room['participants_count'] as int? ?? 0; // ❌ من الـ cache!
  
  if (currentCount >= maxParticipants) {
    return; // منع الانضمام
  }
  
  // ... لكن قد يكون currentCount قديم!
}
```

**السيناريو:**
```
1. الغرفة: max=5, current=4 (في الـ cache المحلي)
2. مستخدمان (A و B) يضغطان "انضم" في نفس الوقت
3. كلاهما يرى 4 < 5 ✅ OK
4. كلاهما ينضم!
5. النتيجة: 6 مشاركين في غرفة max=5! 💥
```

**التأثير:**
- 🔴 **Race condition خطير**
- 📊 **تجاوز الحد الأقصى**
- 🐛 **منطق خاطئ**

**الحل:**
```dart
void _joinRoom(Map<String, dynamic> room) async {
  // ✅ جلب العداد الحالي من DB (real-time)
  final freshData = await _client
    .from('voice_rooms')
    .select('participants_count, max_participants')
    .eq('room_name', room['room_name'])
    .single();
  
  final currentCount = freshData['participants_count'] ?? 0;
  final maxParticipants = freshData['max_participants'];
  
  if (maxParticipants != null && currentCount >= maxParticipants) {
    ScaffoldMessenger.of(context).showSnackBar(...);
    return;
  }
  
  // ✅ الآن آمن للانضمام
  await Navigator.push(...);
}
```

---

## ❌ مشكلة #13: لا يوجد retry logic للـ heartbeat

**الموقع:** `voice_room_active_screen.dart:49-62`

**المشكلة:**
```dart
Future<void> _updateHeartbeat() async {
  try {
    await _client.from('voice_room_participants').update(...);
  } catch (e) {
    debugPrint('⚠️ Heartbeat update failed: $e');
    // ❌ ماذا بعد؟ لا شيء!
  }
}
```

إذا فشل heartbeat **مرة واحدة**:
- المستخدم لا يزال في الغرفة
- لكن `last_seen` لم يتحدث
- بعد دقيقتين → cleanup يحذفه! 👻

**التأثير:**
- 👻 **اختفاء مفاجئ** بعد فشل heartbeat واحد
- 🌐 **مشكلة شبكة مؤقتة** تسبب حذف
- 📊 **عداد خاطئ**

**الحل:**
```dart
int _heartbeatFailures = 0;
const int MAX_FAILURES = 3;

Future<void> _updateHeartbeat() async {
  try {
    await _client.from('voice_room_participants').update({
      'last_seen': DateTime.now().toIso8601String(),
    }).match(...).timeout(const Duration(seconds: 5));
    
    // ✅ نجح - reset counter
    _heartbeatFailures = 0;
  } catch (e) {
    _heartbeatFailures++;
    debugPrint('⚠️ Heartbeat failed ($_heartbeatFailures/$MAX_FAILURES): $e');
    
    // ✅ بعد 3 فشل متتالي - نحاول مرة أخرى بعد 5 ثواني
    if (_heartbeatFailures >= MAX_FAILURES) {
      await Future.delayed(const Duration(seconds: 5));
      unawaited(_updateHeartbeat()); // retry
    }
  }
}
```

---

## ملخص الجولة الثالثة

| # | المشكلة | الخطورة | الأولوية |
|---|---------|---------|----------|
| 10 | Duplicate event handlers | 🔴 عالية | 1 |
| 11 | participants_count بدون fallback | 🟡 متوسطة | 3 |
| 12 | Race condition في _joinRoom | 🔴 عالية جداً | 1 |
| 13 | لا retry للـ heartbeat | 🟡 متوسطة | 2 |

---

## الأولوية للإصلاح

🔥 **فوري:** #10, #12  
⚠️ **قريباً:** #13, #11
