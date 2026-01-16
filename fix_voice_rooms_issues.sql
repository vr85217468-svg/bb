-- إصلاح المشاكل الإضافية في نظام غرف الصوت
-- تاريخ: 2025-12-31

-- ==================== المشكلة 1: Trigger لا يعالج UPDATE ====================
-- إسقاط الـ trigger القديم
DROP TRIGGER IF EXISTS trigger_update_participant_count ON public.voice_room_participants;

-- إعادة إنشاء الـ function مع معالجة UPDATE
CREATE OR REPLACE FUNCTION public.update_room_participant_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        -- عند إضافة مشارك جديد
        UPDATE public.voice_rooms 
        SET participants_count = (
            SELECT count(*) 
            FROM public.voice_room_participants 
            WHERE room_name = NEW.room_name
        ),
        updated_at = NOW()  -- تحديث وقت التعديل
        WHERE room_name = NEW.room_name;
        RETURN NEW;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- عند تحديث بيانات المشارك (مثل last_seen)
        UPDATE public.voice_rooms 
        SET updated_at = NOW()
        WHERE room_name = NEW.room_name;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        -- عند حذف مشارك
        UPDATE public.voice_rooms 
        SET participants_count = (
            SELECT count(*) 
            FROM public.voice_room_participants 
            WHERE room_name = OLD.room_name
        ),
        updated_at = NOW()
        WHERE room_name = OLD.room_name;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء trigger جديد يشمل جميع العمليات
CREATE TRIGGER trigger_update_participant_count
AFTER INSERT OR UPDATE OR DELETE ON public.voice_room_participants
FOR EACH ROW EXECUTE FUNCTION public.update_room_participant_count();


-- ==================== المشكلة 2: إضافة عمود updated_at ====================
-- إضافة عمود updated_at إذا لم يكن موجوداً
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'voice_rooms' AND column_name = 'updated_at'
    ) THEN
        ALTER TABLE public.voice_rooms 
        ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- تحديث القيم الحالية
UPDATE public.voice_rooms 
SET updated_at = created_at 
WHERE updated_at IS NULL;


-- ==================== المشكلة 3: تنظيف تلقائي للغرف الخاملة ====================
-- حذف الغرف التي لا يوجد بها مشاركين وانتهت منذ أكثر من ساعة
CREATE OR REPLACE FUNCTION public.cleanup_inactive_voice_rooms()
RETURNS void AS $$
BEGIN
    -- تعطيل الغرف الخالية التي مر عليها أكثر من 30 دقيقة
    UPDATE public.voice_rooms
    SET is_active = false
    WHERE participants_count = 0 
    AND is_active = true
    AND updated_at < NOW() - INTERVAL '30 minutes';
    
    -- حذف الغرف المعطلة التي مر عليها أكثر من 24 ساعة
    DELETE FROM public.voice_rooms
    WHERE is_active = false 
    AND updated_at < NOW() - INTERVAL '24 hours';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== المشكلة 4: تنظيف المشاركين الذين لم يحدثوا last_seen ====================
-- حذف المشاركين الذين لم يحدثوا last_seen منذ أكثر من 5 دقائق
-- (يعني أنهم خرجوا دون تنظيف صحيح)
CREATE OR REPLACE FUNCTION public.cleanup_stale_participants()
RETURNS void AS $$
BEGIN
    DELETE FROM public.voice_room_participants
    WHERE last_seen < NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- ==================== المشكلة 5: جدولة التنظيف التلقائي ====================
-- ملاحظة: يجب تشغيل هذه الدوال بشكل دوري من التطبيق أو باستخدام pg_cron
-- للتنفيذ اليدوي:
-- SELECT cleanup_inactive_voice_rooms();
-- SELECT cleanup_stale_participants();


-- ==================== المشكلة 6: إضافة فهرس لتحسين الأداء ====================
-- فهرس على updated_at لتسريع الاستعلامات
CREATE INDEX IF NOT EXISTS idx_voice_rooms_updated_at 
ON public.voice_rooms(updated_at) 
WHERE is_active = true;

-- فهرس على last_seen لتسريع التنظيف
CREATE INDEX IF NOT EXISTS idx_participants_last_seen 
ON public.voice_room_participants(last_seen);


-- ==================== المشكلة 7: إضافة قيود للتحقق ====================
-- التأكد من أن عدد المشاركين لا يكون سالباً
ALTER TABLE public.voice_rooms 
DROP CONSTRAINT IF EXISTS check_participants_count_positive;

ALTER TABLE public.voice_rooms 
ADD CONSTRAINT check_participants_count_positive 
CHECK (participants_count >= 0);


-- عرض الغرف الحالية
SELECT id, title, participants_count, is_active, created_at, updated_at
FROM public.voice_rooms
ORDER BY created_at DESC
LIMIT 10;

-- عرض المشاركين
SELECT room_name, user_id, last_seen
FROM public.voice_room_participants
ORDER BY last_seen DESC
LIMIT 10;
