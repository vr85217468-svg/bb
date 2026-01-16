-- ================================================
-- الحل النهائي والأكيد: فتح الصلاحيات للجمهور (Public)
-- نظرًا لأن التطبيق يستخدم نظام login مخصص وليس Supabase Auth
-- ================================================

-- 1. التأكد من أن الجداول مفعّل فيها الـ RLS
ALTER TABLE tribes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tribe_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. حذف كل السياسات السابقة لتجنب أي تعارض
DROP POLICY IF EXISTS "Anyone can view tribes" ON tribes;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
DROP POLICY IF EXISTS "Anyone can select tribe members" ON tribe_members;

-- 3. تفعيل سياسات القراءة للجمهور (public)
-- هذا سيسمح للتطبيق برؤية البيانات حتى لو لم يكن "مسجلاً" في نظام Supabase الرسمي

-- للقبائل
CREATE POLICY "Anyone can view tribes" 
ON tribes FOR SELECT TO public 
USING (true);

-- للمستخدمين
CREATE POLICY "Public profiles are viewable by everyone" 
ON users FOR SELECT TO public 
USING (true);

-- للأعضاء
CREATE POLICY "Anyone can select tribe members" 
ON tribe_members FOR SELECT TO public 
USING (true);

-- 4. تقرير الحالة
SELECT 'Success! RLS is now open for public select.' as status;
