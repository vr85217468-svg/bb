# تطبيق تحديثات الغرف الصوتية في Supabase 🚀

## الخطوات (دقيقتين فقط!)

### 1️⃣ افتح Supabase Dashboard
```
https://supabase.com/dashboard/project/YOUR_PROJECT_ID
```

### 2️⃣ اذهب إلى SQL Editor
- من القائمة الجانبية: **SQL Editor**
- اضغط: **New Query**

### 3️⃣ انسخ والصق الكود
افتح ملف `update_voice_rooms_table.sql` وانسخ المحتوى كاملاً

أو انسخ هذا مباشرة:

```sql
-- ═══════════════════════════════════════════════════════════════
-- تحديث جدول voice_rooms لدعم الميزات الجديدة
-- ═══════════════════════════════════════════════════════════════

-- لون الغرفة (purple, pink, cyan, green, gold)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'voice_rooms' 
        AND column_name = 'room_color'
    ) THEN
        ALTER TABLE public.voice_rooms 
        ADD COLUMN room_color TEXT DEFAULT 'purple';
    END IF;
END $$;

-- أيقونة الغرفة (headset, music, game, chat, study, podcast)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'voice_rooms' 
        AND column_name = 'room_icon'
    ) THEN
        ALTER TABLE public.voice_rooms 
        ADD COLUMN room_icon TEXT DEFAULT 'headset';
    END IF;
END $$;

-- الحد الأقصى للمشاركين
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'voice_rooms' 
        AND column_name = 'max_participants'
    ) THEN
        ALTER TABLE public.voice_rooms 
        ADD COLUMN max_participants INTEGER DEFAULT 10;
    END IF;
END $$;

-- هل الغرفة خاصة
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_schema = 'public' 
        AND table_name = 'voice_rooms' 
        AND column_name = 'is_private'
    ) THEN
        ALTER TABLE public.voice_rooms 
        ADD COLUMN is_private BOOLEAN DEFAULT FALSE;
    END IF;
END $$;

-- تحديث الغرف الموجودة بالقيم الافتراضية
UPDATE public.voice_rooms 
SET 
    room_color = COALESCE(room_color, 'purple'),
    room_icon = COALESCE(room_icon, 'headset'),
    max_participants = COALESCE(max_participants, 10),
    is_private = COALESCE(is_private, FALSE)
WHERE room_color IS NULL 
   OR room_icon IS NULL 
   OR max_participants IS NULL 
   OR is_private IS NULL;

-- ═══════════════════════════════════════════════════════════════
-- تأكيد التحديث
-- ═══════════════════════════════════════════════════════════════
SELECT 
    column_name, 
    data_type, 
    column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'voice_rooms'
ORDER BY ordinal_position;
```

### 4️⃣ شغّل الكود
اضغط زر **Run** (أو Ctrl+Enter)

### 5️⃣ تحقق من النجاح ✅

**رسالة النجاح:**
```
Success. No rows returned
```

**أو سيظهر جدول بأعمدة voice_rooms:**
يجب أن ترى الأعمدة الجديدة:
- `room_color` - TEXT
- `room_icon` - TEXT  
- `max_participants` - INTEGER
- `is_private` - BOOLEAN

---

## ماذا بعد النجاح؟

### اختبر فوراً! 🎉

1. **افتح التطبيق**
2. **اذهب للغرف الصوتية**
3. **أنشئ غرفة جديدة:**
   - اختر لون (مثلاً: وردي)
   - اختر أيقونة (مثلاً: موسيقى)
   - اضبط الحد الأقصى (مثلاً: 5)
   - فعّل "غرفة خاصة"

4. **شاهد النتائج:**
   - ✅ الغرفة باللون الوردي
   - ✅ أيقونة موسيقى
   - ✅ قفل ذهبي 🔒
   - ✅ عداد `0/5`

---

## إذا واجهت مشكلة ❌

### خطأ: "column already exists"
**الحل:** الأعمدة موجودة مسبقاً - كل شيء تمام! ✅

### خطأ: "permission denied"
**الحل:** تأكد أنك مسجل دخول كـ Owner للمشروع

### خطأ: "table does not exist"
**الحل:** نفذ أولاً: `create_voice_rooms.sql`

---

## التحقق اليدوي (اختياري)

### افحص الأعمدة في Table Editor:
1. اذهب لـ **Table Editor** → **voice_rooms**
2. تحقق من وجود الأعمدة الجديدة
3. جرب إضافة غرفة يدوية مع القيم الجديدة

---

## ✅ بعد التطبيق الناجح

الميزات الجديدة **تعمل الآن**:
- 🎨 5 ألوان مخصصة
- 🎵 6 أيقونات متنوعة  
- 👥 حد أقصى قابل للتعديل
- 🔒 غرف خاصة

**استمتع! 🎉**
