-- ================================================
-- كود "إعادة الضبط الشامل" لظهور البيانات
-- Emergency Visibility Reset
-- ================================================

-- 1. التأكد من أن الجداول مفعّل فيها الـ RLS (لضبطها بشكل صحيح)
ALTER TABLE tribes ENABLE ROW LEVEL SECURITY;
ALTER TABLE tribe_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. مسح السياسات القديمة للجداول الثلاثة لضمان النظافة
DROP POLICY IF EXISTS "Anyone can view tribes" ON tribes;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
DROP POLICY IF EXISTS "Members can view their tribe" ON tribe_members;
DROP POLICY IF EXISTS "Anyone can select tribe members" ON tribe_members;

-- 3. تفعيل سياسات "القراءة المفتوحة" للمستخدمين المسجلين (SELECT)
-- هذا سيحل مشكلة "Found 0" فوراً

-- للي قبائل
CREATE POLICY "Anyone can view tribes" 
ON tribes FOR SELECT TO authenticated 
USING (true);

-- للمستخدمين (لمنع فشل الـ Join الخاص بالقائد)
CREATE POLICY "Public profiles are viewable by everyone" 
ON users FOR SELECT TO authenticated 
USING (true);

-- للأعضاء (لإظهار قائمة الأعضاء وعداد القبيلة)
CREATE POLICY "Anyone can select tribe members" 
ON tribe_members FOR SELECT TO authenticated 
USING (true);

-- 4. إظهار تقرير سريع للتأكد من وجود بيانات أصلاً
SELECT 'Tribes Count:' as label, count(*) as value FROM tribes
UNION ALL
SELECT 'Members Count:', count(*) FROM tribe_members
UNION ALL
SELECT 'Users Count:', count(*) FROM users;
