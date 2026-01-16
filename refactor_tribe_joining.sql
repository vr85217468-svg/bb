-- ================================================
-- تطوير نظام الانضمام للقبائل (نظام العضوية المعلقة)
-- ================================================

-- 1. إضافة عمود الحالة لجدول الأعضاء
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='tribe_members' AND column_name='status') THEN
        ALTER TABLE tribe_members ADD COLUMN status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'pending'));
    END IF;
END $$;

-- 2. تحديث الأعضاء الحاليين ليكونوا "نشطين"
UPDATE tribe_members SET status = 'active' WHERE status IS NULL;

-- 3. تحديث RLS لجدول الأعضاء للسماح بالانضمام "المعلق"
ALTER TABLE tribe_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can join tribes" ON tribe_members;
CREATE POLICY "Users can join tribes" ON tribe_members
    FOR INSERT 
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Members can view their tribe" ON tribe_members;
CREATE POLICY "Members can view their tribe" ON tribe_members
    FOR SELECT 
    TO authenticated
    USING (true); -- السماح للجميع برؤية من هم في القوائم

-- 4. السماح للقادة بتحديث حالة العضو (من معلق إلى نشط)
DROP POLICY IF EXISTS "Leaders can manage members" ON tribe_members;
CREATE POLICY "Leaders can manage members" ON tribe_members
    FOR UPDATE
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM tribes 
            WHERE tribes.id = tribe_members.tribe_id 
            AND tribes.leader_id = auth.uid()
        )
    );

-- 5. حذف جدول الطلبات القديم (اختياري، للترتيب)
DROP TABLE IF EXISTS tribe_join_requests;
