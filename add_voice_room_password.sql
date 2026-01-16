-- إضافة حماية كلمة السر لغرف الصوت الخاصة
-- Add password protection for private voice rooms

-- 1. إضافة أعمدة is_private و password
ALTER TABLE public.voice_rooms 
ADD COLUMN IF NOT EXISTS is_private BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS password TEXT NULL;

-- 2. إضافة تعليقات للتوضيح
COMMENT ON COLUMN voice_rooms.is_private IS 'Whether the room is private (requires password to join)';
COMMENT ON COLUMN voice_rooms.password IS 'Optional password for private rooms. NULL means no password required.';

-- 3. إنشاء index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_voice_rooms_private ON voice_rooms(is_private) WHERE is_private = true;

-- ✅ تم! الآن غرف الصوت تدعم كلمة السر
