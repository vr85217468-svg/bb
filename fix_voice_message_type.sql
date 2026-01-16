-- ============================================
-- إصلاح قيد message_type لدعم voice
-- Fix message_type constraint to support voice
-- ============================================

-- حذف القيد القديم
ALTER TABLE tribe_messages 
  DROP CONSTRAINT IF EXISTS tribe_messages_message_type_check;

-- إضافة القيد الجديد مع voice
ALTER TABLE tribe_messages 
  ADD CONSTRAINT tribe_messages_message_type_check 
  CHECK (message_type IN ('text', 'sticker', 'image', 'audio', 'voice'));

-- تغيير نوع media_url ليدعم Base64 الكبيرة
-- ALTER TABLE tribe_messages
--   ALTER COLUMN media_url TYPE TEXT;

-- التحقق
SELECT 'Done! message_type now supports: text, sticker, image, audio, voice' as status;
