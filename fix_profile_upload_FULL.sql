-- =====================================================
-- إصلاح شامل لمشكلة رفع صورة البروفايل (Storage + Database)
-- Comprehensive fix for Profile Image Upload
-- =====================================================

-- 1. إصلاح صلاحيات جدول المستخدمين (السماح بالتعديل)
-- Fix Users Table Permissions
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- حذف السياسات القديمة للتحديث لتجنب التضارب
DROP POLICY IF EXISTS "Users can update own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own data" ON users;

-- إنشاء سياسة تسمح للمستخدم بتحديث بياناته الخاصة
CREATE POLICY "Users can update own profile"
ON users
FOR UPDATE
TO authenticated
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- 2. إصلاح صلاحيات التخزين (Storage Bucket)
-- Fix Storage Bucket Permissions (avatars)

-- التأكد من وجود الـ bucket
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

-- حذف السياسات القديمة للـ storage
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

-- إنشاء سياسات شاملة للـ avatars
CREATE POLICY "Avatars Insert" ON storage.objects FOR INSERT TO public WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "Avatars Select" ON storage.objects FOR SELECT TO public USING (bucket_id = 'avatars');
CREATE POLICY "Avatars Update" ON storage.objects FOR UPDATE TO public USING (bucket_id = 'avatars');
CREATE POLICY "Avatars Delete" ON storage.objects FOR DELETE TO public USING (bucket_id = 'avatars');

-- =====================================================
-- التحقق النهائية
SELECT 'Done! Profile upload should work now.' as status;
