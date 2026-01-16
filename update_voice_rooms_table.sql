-- ═══════════════════════════════════════════════════════════════
-- تحديث جدول voice_rooms لدعم الميزات الجديدة
-- ═══════════════════════════════════════════════════════════════

-- إضافة الأعمدة الجديدة إذا لم تكن موجودة

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
