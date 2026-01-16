-- =====================================================
-- إصلاح صلاحيات Storage لـ tribe-media bucket
-- Fix Storage RLS for tribe-media bucket
-- =====================================================

-- 1. التأكد من وجود الـ bucket وجعله عاماً
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'tribe-media', 
    'tribe-media', 
    true,
    10485760, -- 10MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/wav']
)
ON CONFLICT (id) DO UPDATE SET 
    public = true,
    file_size_limit = 10485760,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'image/jpg', 'audio/mp4', 'audio/m4a', 'audio/mpeg', 'audio/wav'];

-- 2. حذف السياسات القديمة لـ tribe-media
DROP POLICY IF EXISTS "Allow tribe media uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow tribe media reads" ON storage.objects;
DROP POLICY IF EXISTS "Allow tribe media updates" ON storage.objects;
DROP POLICY IF EXISTS "Allow tribe media deletes" ON storage.objects;
DROP POLICY IF EXISTS "Allow all uploads to tribe-media" ON storage.objects;
DROP POLICY IF EXISTS "Allow all reads from tribe-media" ON storage.objects;
DROP POLICY IF EXISTS "Allow all updates to tribe-media" ON storage.objects;
DROP POLICY IF EXISTS "Allow all deletes from tribe-media" ON storage.objects;

-- 3. إنشاء سياسات جديدة وشاملة
-- السماح بالرفع للجميع
CREATE POLICY "Allow all uploads to tribe-media"
ON storage.objects
FOR INSERT
TO public
WITH CHECK (bucket_id = 'tribe-media');

-- السماح بالقراءة للجميع
CREATE POLICY "Allow all reads from tribe-media"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'tribe-media');

-- السماح بالتحديث للجميع
CREATE POLICY "Allow all updates to tribe-media"
ON storage.objects
FOR UPDATE
TO public
USING (bucket_id = 'tribe-media');

-- السماح بالحذف للجميع
CREATE POLICY "Allow all deletes from tribe-media"
ON storage.objects
FOR DELETE
TO public
USING (bucket_id = 'tribe-media');

-- =====================================================
-- التحقق
-- =====================================================
SELECT 'Done! tribe-media bucket is now fully accessible.' as status;

-- عرض الـ bucket
SELECT id, name, public FROM storage.buckets WHERE id = 'tribe-media';
