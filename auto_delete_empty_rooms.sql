-- إضافة Database Trigger لحذف الغرف الفارغة تلقائياً
-- يتم تنفيذ هذا Trigger عندما يصبح عدد المشاركين = 0

-- إنشاء دالة الحذف التلقائي
CREATE OR REPLACE FUNCTION auto_delete_empty_rooms()
RETURNS TRIGGER AS $$
BEGIN
    -- عندما يصبح عدد المشاركين 0، احذف الغرفة
    IF NEW.participants_count = 0 THEN
        DELETE FROM public.voice_rooms WHERE id = NEW.id;
        RAISE NOTICE 'Auto-deleted empty room: %', NEW.room_name;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- إنشاء Trigger يعمل بعد تحديث participants_count
DROP TRIGGER IF EXISTS trigger_auto_delete_empty_rooms ON public.voice_rooms;

CREATE TRIGGER trigger_auto_delete_empty_rooms
AFTER UPDATE OF participants_count ON public.voice_rooms
FOR EACH ROW
WHEN (NEW.participants_count = 0)
EXECUTE FUNCTION auto_delete_empty_rooms();

-- رسالة نجاح
DO $$
BEGIN
    RAISE NOTICE '✅ Auto-delete trigger created successfully';
    RAISE NOTICE 'Rooms with 0 participants will be deleted automatically';
END $$;
