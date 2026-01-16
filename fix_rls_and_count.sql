-- ================================================
-- الإصلاح النهائي لعداد الأعضاء وصلاحيات إنشاء القبيلة
-- ================================================

-- 1. التأكد من صلاحيات جدول القبائل (Tribes)
-- إذا كان الـ RLS مفعلاً، يجب السماح للقادة بتحديثه (لتحديث العداد تلقائياً عبر التريجر)
ALTER TABLE tribes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can view tribes" ON tribes;
CREATE POLICY "Anyone can view tribes" ON tribes FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "Leaders can update their tribes" ON tribes;
CREATE POLICY "Leaders can update their tribes" ON tribes 
FOR UPDATE TO authenticated 
USING (leader_id = auth.uid());

DROP POLICY IF EXISTS "Authenticated users can create tribes" ON tribes;
CREATE POLICY "Authenticated users can create tribes" ON tribes 
FOR INSERT TO authenticated 
WITH CHECK (leader_id = auth.uid());

-- 2. تحديث التريجر ليكون Security Definer (ليعمل بصلاحيات عالية)
CREATE OR REPLACE FUNCTION update_tribe_member_count()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.status = 'active') THEN
            UPDATE tribes SET member_count = member_count + 1 WHERE id = NEW.tribe_id;
        END IF;
    ELSIF (TG_OP = 'DELETE') THEN
        IF (OLD.status = 'active') THEN
            UPDATE tribes SET member_count = member_count - 1 WHERE id = OLD.tribe_id;
        END IF;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.status = 'pending' AND NEW.status = 'active') THEN
            UPDATE tribes SET member_count = member_count + 1 WHERE id = NEW.tribe_id;
        ELSIF (OLD.status = 'active' AND NEW.status = 'pending') THEN
            UPDATE tribes SET member_count = member_count - 1 WHERE id = NEW.tribe_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; -- ✅ تمت إضافة SECURITY DEFINER

-- 3. تصفير العدادات الخاطئة في كل القبائل لتبدأ من جديد بشكل صحيح
UPDATE tribes t
SET member_count = (
    SELECT COUNT(*) 
    FROM tribe_members m 
    WHERE m.tribe_id = t.id 
    AND m.status = 'active'
);
