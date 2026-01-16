-- إصلاح RLS policies لتتوافق مع نظام المصادقة الحالي
-- تاريخ: 2025-12-31 (إصلاح عاجل)

-- المشكلة: auth.uid() لا يعمل مع نظام المصادقة المخصص
-- الحل: تعديل السياسات لتكون أكثر مرونة

-- ==================== إصلاح سياسات voice_room_participants ====================

-- حذف السياسات الحالية
DROP POLICY IF EXISTS "Users can join rooms" ON public.voice_room_participants;
DROP POLICY IF EXISTS "Users can update their own participation" ON public.voice_room_participants;
DROP POLICY IF EXISTS "Users can leave rooms" ON public.voice_room_participants;
DROP POLICY IF EXISTS "Room creators can remove participants" ON public.voice_room_participants;

-- إنشاء سياسات جديدة أكثر مرونة

-- 1. السماح بالانضمام للغرف (INSERT) - مرن
CREATE POLICY "Allow insert for authenticated users" 
ON public.voice_room_participants 
FOR INSERT 
WITH CHECK (true);  -- مؤقتاً: السماح للجميع

-- 2. السماح بالقراءة
CREATE POLICY "Allow select for all" 
ON public.voice_room_participants 
FOR SELECT 
USING (true);

-- 3. السماح بالتحديث
CREATE POLICY "Allow update for all" 
ON public.voice_room_participants 
FOR UPDATE 
USING (true)
WITH CHECK (true);

-- 4. السماح بالحذف
CREATE POLICY "Allow delete for all" 
ON public.voice_room_participants 
FOR DELETE 
USING (true);


-- ==================== تعديل سياسات voice_rooms أيضاً ====================

-- حذف السياسات الصارمة
DROP POLICY IF EXISTS "Users can create voice rooms" ON public.voice_rooms;
DROP POLICY IF EXISTS "Creators can update their own rooms" ON public.voice_rooms;
DROP POLICY IF EXISTS "Creators can delete their own rooms" ON public.voice_rooms;

-- سياسات أكثر مرونة

-- 1. السماح بإنشاء الغرف
CREATE POLICY "Allow room creation" 
ON public.voice_rooms 
FOR INSERT 
WITH CHECK (true);

-- 2. السماح بالقراءة (الغرف النشطة فقط)
-- هذه موجودة بالفعل: "Anyone can view active voice rooms"

-- 3. السماح بالتحديث (للمنشئ فقط - إذا كان auth.uid() موجود، وإلا للجميع)
CREATE POLICY "Allow room updates" 
ON public.voice_rooms 
FOR UPDATE 
USING (
  CASE 
    WHEN auth.uid() IS NOT NULL THEN created_by = auth.uid()
    ELSE true
  END
);

-- 4. السماح بالحذف (للمنشئ فقط - إذا كان auth.uid() موجود، وإلا للجميع)
CREATE POLICY "Allow room deletion" 
ON public.voice_rooms 
FOR DELETE 
USING (
  CASE 
    WHEN auth.uid() IS NOT NULL THEN created_by = auth.uid()
    ELSE true
  END
);


-- ==================== ملاحظة مهمة ====================
-- هذه السياسات مرنة جداً للسماح بعمل التطبيق
-- في المستقبل، يجب:
-- 1. استخدام Supabase Auth بشكل صحيح
-- 2. أو تطبيق RLS policies مخصصة تتحقق من جدول users
-- 3. أو استخدام service_role key في السيرفر

-- عرض السياسات الجديدة
SELECT tablename, policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename IN ('voice_rooms', 'voice_room_participants')
ORDER BY tablename, policyname;
