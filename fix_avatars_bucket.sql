-- =====================================================
-- إصلاح صلاحيات bucket "avatars" الخاص بصور البروفايل
-- Fix Permissions for "avatars" storage bucket
-- =====================================================

-- 1. التأكد من وجود الـ bucket وجعله عاماً
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'avatars', 
    'avatars', 
    true,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 5242880;

-- 2. حذف السياسات القديمة الخاصة بـ avatars فقط لتجنب التضارب
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'objects' 
        AND schemaname = 'storage'
        AND policyname LIKE '%avatars%'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
    END LOOP;
END $$;

-- 3. السماح بالرفع للجميع (الموثقين وغير الموثقين مؤقتاً للتأكد)
CREATE POLICY "Allow all uploads to avatars"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'avatars');

-- 4. السماح بالقراءة للجميع
CREATE POLICY "Allow all reads from avatars"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'avatars');

-- 5. السماح بالتحديث للجميع (لتغيير الصورة)
CREATE POLICY "Allow all updates to avatars"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'avatars');

-- 6. السماح بالحذف للجميع
CREATE POLICY "Allow all deletes from avatars"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'avatars');

-- =====================================================
-- التحقق
-- =====================================================
SELECT 'Done! Avatars bucket is now fully accessible.' as status;
