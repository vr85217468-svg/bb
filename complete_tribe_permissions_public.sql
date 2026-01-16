-- ================================================
-- الإصلاح الشامل لصلاحيات الكتابة (للمنضمين والمنشئين)
-- نظرًا لاعتبار التطبيق "Anon/Public" من جهة Supabase
-- ================================================

-- 1. التأكد من تفعيل RLS (أو تعطيله مؤقتاً إذا استمرت المشكلة، لكن سنحاول ضبطه أولاً)
ALTER TABLE tribes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tribe_members ENABLE ROW LEVEL SECURITY;

-- 2. إزالة كل السياسات القديمة
DROP POLICY IF EXISTS "Authenticated users can create tribes" ON tribes;
DROP POLICY IF EXISTS "Leaders can update their tribes" ON tribes;
DROP POLICY IF EXISTS "Users can join tribes" ON tribe_members;
DROP POLICY IF EXISTS "Leaders can manage members" ON tribe_members;

-- 3. فتح صلاحيات "الإضافة" (INSERT) للجمهور
-- لكي يتمكن أي مستخدم من إنشاء قبيلة أو الانضمام لواحدة
CREATE POLICY "Public can create tribes" 
ON tribes FOR INSERT TO public 
WITH CHECK (true);

CREATE POLICY "Public can join tribes" 
ON tribe_members FOR INSERT TO public 
WITH CHECK (true);

-- 4. فتح صلاحيات "التحديث" (UPDATE) للجمهور
-- لكي يتمكن القائد من تعديل قبيلته، ولكي يعمل عداد الأعضاء التلقائي
CREATE POLICY "Public can update tribes" 
ON tribes FOR UPDATE TO public 
USING (true);

CREATE POLICY "Public can update members" 
ON tribe_members FOR UPDATE TO public 
USING (true);

-- 5. فتح صلاحيات "الحذف" (DELETE)
-- للمغادرة أو حذف القبيلة
CREATE POLICY "Public can delete tribes" 
ON tribes FOR DELETE TO public 
USING (true);

CREATE POLICY "Public can leave tribes" 
ON tribe_members FOR DELETE TO public 
USING (true);

-- 6. تقرير
SELECT 'Success! Writing permissions are now open for public.' as status;
