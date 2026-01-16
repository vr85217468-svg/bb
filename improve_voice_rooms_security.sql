-- تحسينات الأمان لنظام غرف الصوت  
-- تاريخ: 2025-12-31

-- ==================== إصلاح ثغرة الأمان في RLS Policies ====================

-- حذف السياسات الخطيرة الموجودة
DROP POLICY IF EXISTS "Anyone can manage voice rooms" ON public.voice_rooms;
DROP POLICY IF EXISTS "Anyone can create voice rooms" ON public.voice_rooms;

-- إنشاء سياسات محدودة وآمنة

-- 1. السماح لأي شخص بقراءة الغرف النشطة (لا تغيير)
-- CREATE POLICY "Anyone can view active voice rooms" -- موجودة بالفعل

-- 2. السماح لأي شخص بإنشاء غرفة (آمن)
CREATE POLICY "Users can create voice rooms" 
ON public.voice_rooms 
FOR INSERT 
WITH CHECK (auth.uid() IS NOT NULL); -- يجب أن يكون مسجل دخول

-- 3. السماح فقط لمن شئ الغرفة بتعديلها
CREATE POLICY "Creators can update their own rooms" 
ON public.voice_rooms 
FOR UPDATE 
USING (created_by = auth.uid())
WITH CHECK (created_by = auth.uid());

-- 4. السماح فقط لمنشئ الغرفة بحذفها
CREATE POLICY "Creators can delete their own rooms" 
ON public.voice_rooms 
FOR DELETE 
USING (created_by = auth.uid());


-- ==================== تحسينات إضافية للأمان ====================

-- إضافة constraint للتأكد من أن المنشئ لا يمكنه تغييره
ALTER TABLE public.voice_rooms 
DROP CONSTRAINT IF EXISTS voice_rooms_created_by_immutable;

-- Note: PostgreSQL لا يدعم immutable columns مباشرة
-- سنستخدم trigger بدلاً من ذلك

CREATE OR REPLACE FUNCTION prevent_created_by_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.created_by IS DISTINCT FROM NEW.created_by THEN
        RAISE EXCEPTION 'Cannot change the creator of a voice room';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prevent_created_by_modification ON public.voice_rooms;

CREATE TRIGGER prevent_created_by_modification
BEFORE UPDATE ON public.voice_rooms
FOR EACH ROW
EXECUTE FUNCTION prevent_created_by_change();


-- ==================== إضافة فحص limit للغرف ====================

-- منع إنشاء عدد كبير جداً من الغرف (DoS protection)
CREATE OR REPLACE FUNCTION check_room_creation_limit()
RETURNS TRIGGER AS $$
DECLARE
    active_rooms_count INTEGER;
BEGIN
    -- عد الغرف النشطة للمستخدم
    SELECT COUNT(*) INTO active_rooms_count
    FROM public.voice_rooms
    WHERE created_by = NEW.created_by
    AND is_active = true;
    
    -- الحد الأقصى: 3 غرف نشطة لكل مستخدم
    IF active_rooms_count >= 3 THEN
        RAISE EXCEPTION 'Cannot create more than 3 active voice rooms per user';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS limit_active_rooms ON public.voice_rooms;

CREATE TRIGGER limit_active_rooms
BEFORE INSERT ON public.voice_rooms
FOR EACH ROW
EXECUTE FUNCTION check_room_creation_limit();


-- ==================== تحسين سياسات voice_room_participants ====================

-- حذف السياسة الواسعة
DROP POLICY IF EXISTS "Anyone can join/leave rooms" ON public.voice_room_participants;

-- سياسات محددة:

-- 1. السماح للمستخدم بالانضمام (INSERT)
CREATE POLICY "Users can join rooms" 
ON public.voice_room_participants 
FOR INSERT 
WITH CHECK (
    auth.uid() IS NOT NULL 
    AND user_id = auth.uid()
);

-- 2. السماح للمستخدم بتحديث last_seen الخاص به فقط
CREATE POLICY "Users can update their own participation" 
ON public.voice_room_participants 
FOR UPDATE 
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- 3. السماح للمستخدم بمغادرة الغرفة (حذف سجله)
CREATE POLICY "Users can leave rooms" 
ON public.voice_room_participants 
FOR DELETE 
USING (user_id = auth.uid());

-- 4. السماح لمنشئ الغرفة بطرد المشاركين (اختياري)
CREATE POLICY "Room creators can remove participants" 
ON public.voice_room_participants 
FOR DELETE 
USING (
    EXISTS (
        SELECT 1 FROM public.voice_rooms
        WHERE voice_rooms.room_name = voice_room_participants.room_name
        AND voice_rooms.created_by = auth.uid()
    )
);


-- ==================== فحص التحسينات ====================

-- عرض جميع السياسات الحالية
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('voice_rooms', 'voice_room_participants')
ORDER BY tablename, policyname
LIMIT 20;
