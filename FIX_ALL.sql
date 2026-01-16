-- ============================================
-- إصلاح شامل للقبائل - نفذ هذا الملف فقط
-- ============================================

-- 1. إصلاح قيد message_type لدعم voice
ALTER TABLE tribe_messages 
  DROP CONSTRAINT IF EXISTS tribe_messages_message_type_check;

ALTER TABLE tribe_messages 
  ADD CONSTRAINT tribe_messages_message_type_check 
  CHECK (message_type IN ('text', 'sticker', 'image', 'audio', 'voice'));

-- 2. التأكد من وجود عمود media_url
ALTER TABLE tribe_messages 
  ADD COLUMN IF NOT EXISTS media_url TEXT;

-- تم! ✅
SELECT 'All fixes applied successfully!' as status;
