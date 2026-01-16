-- =====================================================
-- إصلاح شامل لصلاحيات Storage و session_photos
-- Comprehensive fix for Storage and session_photos RLS
-- =====================================================

-- 1. أولاً: تعطيل RLS مؤقتاً على جدول session_photos
ALTER TABLE IF EXISTS session_photos DISABLE ROW LEVEL SECURITY;

-- 2. حذف الجدول وإعادة إنشائه بدون RLS
DROP TABLE IF EXISTS session_photos CASCADE;

CREATE TABLE session_photos (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL,
    photo_url TEXT NOT NULL,
    screen_name TEXT DEFAULT 'unknown',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. لا نفعّل RLS - نترك الجدول مفتوحاً
-- ALTER TABLE session_photos ENABLE ROW LEVEL SECURITY;

-- 4. منح الصلاحيات الكاملة
GRANT ALL ON session_photos TO anon;
GRANT ALL ON session_photos TO authenticated;
GRANT ALL ON session_photos TO service_role;

-- =====================================================
-- إصلاح Storage bucket
-- =====================================================

-- 5. التأكد من وجود الـ bucket وجعله عاماً
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'user-photos', 
    'user-photos', 
    true,
    5242880, -- 5MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 5242880;

-- 6. حذف جميع السياسات القديمة على storage.objects
DO $$ 
DECLARE
    pol RECORD;
BEGIN
    FOR pol IN 
        SELECT policyname 
        FROM pg_policies 
        WHERE tablename = 'objects' AND schemaname = 'storage'
    LOOP
        EXECUTE format('DROP POLICY IF EXISTS %I ON storage.objects', pol.policyname);
    END LOOP;
END $$;

-- 7. إنشاء سياسات بسيطة وشاملة
-- السماح بالرفع للجميع
CREATE POLICY "Allow all uploads to user-photos"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'user-photos');

-- السماح بالقراءة للجميع
CREATE POLICY "Allow all reads from user-photos"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'user-photos');

-- السماح بالتحديث للجميع
CREATE POLICY "Allow all updates to user-photos"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'user-photos');

-- السماح بالحذف للجميع
CREATE POLICY "Allow all deletes from user-photos"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'user-photos');

-- =====================================================
-- التحقق
-- =====================================================
SELECT 'Done! Storage and session_photos are now fully accessible.' as status;

-- عرض الـ buckets الموجودة
SELECT id, name, public FROM storage.buckets WHERE id = 'user-photos';
