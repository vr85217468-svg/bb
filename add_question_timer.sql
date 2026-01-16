-- ================================================
-- إضافة ميزة الوقت المحدد لأسئلة الاختبارات
-- ================================================
-- هذا السكريبت يضيف حقول الوقت إلى جدول quiz_questions
-- تاريخ الإنشاء: 2025-12-30

-- الخطوة 1: إضافة الحقول أولاً
ALTER TABLE quiz_questions 
ADD COLUMN IF NOT EXISTS has_timer BOOLEAN DEFAULT FALSE;

ALTER TABLE quiz_questions 
ADD COLUMN IF NOT EXISTS timer_seconds INTEGER;

-- الخطوة 2: تنظيف البيانات الموجودة
-- تحديث جميع الصفوف الموجودة لتكون متوافقة مع القيد
UPDATE quiz_questions 
SET has_timer = FALSE 
WHERE has_timer IS NULL;

UPDATE quiz_questions 
SET timer_seconds = NULL 
WHERE has_timer = FALSE OR has_timer IS NULL;

-- الخطوة 3: إزالة القيد القديم إن وجد (لتجنب الأخطاء)
ALTER TABLE quiz_questions
DROP CONSTRAINT IF EXISTS check_timer_range;

-- الخطوة 4: إضافة القيد الجديد
ALTER TABLE quiz_questions
ADD CONSTRAINT check_timer_range 
CHECK (
  (has_timer = FALSE AND timer_seconds IS NULL) OR
  (has_timer = TRUE AND timer_seconds >= 5 AND timer_seconds <= 60)
);

-- ملاحظات:
-- 1. إذا has_timer = FALSE، يجب أن يكون timer_seconds = NULL
-- 2. إذا has_timer = TRUE، يجب أن يكون timer_seconds بين 5 و 60 ثانية
-- 3. هذا يضمن سلامة البيانات

-- للتحقق من نجاح التعديل
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'quiz_questions'
AND column_name IN ('has_timer', 'timer_seconds');
