-- ================================================
-- إصلاح صلاحيات القراءة في جدول المستخدمين
-- ================================================

-- 1. التأكد من تفعيل RLS
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- 2. السماح للمستخدمين برؤية بعضهم البعض (لأغراض القبيلة والدردشة)
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON users;
CREATE POLICY "Public profiles are viewable by everyone"
ON users
FOR SELECT
TO authenticated
USING (true);

-- 3. السماح للمستخدم برؤية بياناته الخاصة (للطمأنينة)
DROP POLICY IF EXISTS "Users can view their own data" ON users;
CREATE POLICY "Users can view their own data"
ON users
FOR SELECT
TO authenticated
USING (auth.uid() = id);

-- ملاحظة: السياسة رقم 2 (USING true) تغطي بالفعل رقم 3 إذا كان المستخدم مسجلاً،
-- ولكن رقم 2 ضرورية لنجاح الربط (JOIN) في قائمة الأعضاء.
