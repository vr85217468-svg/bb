-- ============================================
-- تحديث نظام المحادثة لدعم الوسائط
-- Update Chat System for Media Support
-- ============================================

-- ============================================
-- 1. تحديث جدول tribe_messages لدعم أنواع جديدة
-- ============================================

-- حذف القيد القديم
ALTER TABLE tribe_messages 
  DROP CONSTRAINT IF EXISTS tribe_messages_message_type_check;

-- إضافة القيد الجديد مع الأنواع الإضافية
ALTER TABLE tribe_messages 
  ADD CONSTRAINT tribe_messages_message_type_check 
  CHECK (message_type IN ('text', 'sticker', 'image', 'audio'));

-- إضافة عمود لرابط الملف
ALTER TABLE tribe_messages 
  ADD COLUMN IF NOT EXISTS media_url TEXT;

-- إضافة عمود لمدة الملف الصوتي (بالثواني)
ALTER TABLE tribe_messages 
  ADD COLUMN IF NOT EXISTS audio_duration INT;

-- ============================================
-- 2. إنشاء Storage Bucket للصور والصوت (إن لم يكن موجوداً)
-- ============================================
-- ملاحظة: يجب تنفيذ هذا من Supabase Dashboard → Storage
-- اسم bucket: tribe-media
-- Public: نعم
-- Allowed MIME types: image/*, audio/*

-- ============================================
-- 3. تعطيل RLS على tribe_messages (للاختبار)
-- ============================================
ALTER TABLE tribe_messages DISABLE ROW LEVEL SECURITY;

-- ============================================
-- 4. إضافة index لتحسين الأداء
-- ============================================
CREATE INDEX IF NOT EXISTS idx_tribe_messages_media 
  ON tribe_messages(tribe_id, message_type, created_at DESC) 
  WHERE message_type IN ('image', 'audio');

-- ============================================
-- 5. عرض بنية الجدول المحدّثة
-- ============================================
SELECT 
  column_name,
  data_type,
  is_nullable,
  column_default
FROM information_schema.columns
WHERE table_name = 'tribe_messages'
ORDER BY ordinal_position;

-- ============================================
-- 6. اختبار إدراج رسالة بصورة (للتجربة)
-- ============================================
-- استبدل القيم بقيم حقيقية
-- INSERT INTO tribe_messages (tribe_id, user_id, message, message_type, media_url)
-- VALUES (
--   'TRIBE_ID_HERE',
--   'USER_ID_HERE',
--   'شاهد هذه الصورة!',
--   'image',
--   'https://supabase.co/storage/v1/object/public/tribe-media/image_123.jpg'
-- );

-- ============================================
-- تم! ✅
-- ============================================
