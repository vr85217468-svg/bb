-- ================================================
-- حل مشكلة RLS في طلبات الانضمام (نسخة تصحيح الأخطاء)
-- ================================================

-- 1. التأكد من وجود الجدول والأعمدة
CREATE TABLE IF NOT EXISTS tribe_join_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tribe_id UUID NOT NULL REFERENCES tribes(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(tribe_id, user_id)
);

-- 2. إعادة ضبط الـ RLS بالكامل
ALTER TABLE tribe_join_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE tribe_join_requests ENABLE ROW LEVEL SECURITY;

-- 3. حذف جميع السياسات القديمة
DROP POLICY IF EXISTS "Users can view their own requests" ON tribe_join_requests;
DROP POLICY IF EXISTS "Leaders can view requests for their tribes" ON tribe_join_requests;
DROP POLICY IF EXISTS "Users can create join requests" ON tribe_join_requests;
DROP POLICY IF EXISTS "Leaders can update requests for their tribes" ON tribe_join_requests;
DROP POLICY IF EXISTS "Anyone authenticated can create join requests" ON tribe_join_requests;

-- 4. سياسة الإضافة (جعلناها عامة للمسجلين مؤقتاً لحل المشكلة)
CREATE POLICY "Allow authenticated inserts" ON tribe_join_requests
    FOR INSERT 
    TO authenticated
    WITH CHECK (true);

-- 5. سياسة القراءة
CREATE POLICY "Allow individuals to view their own requests" ON tribe_join_requests
    FOR SELECT 
    TO authenticated
    USING (auth.uid() = user_id OR EXISTS (
        SELECT 1 FROM tribes WHERE tribes.id = tribe_join_requests.tribe_id AND tribes.leader_id = auth.uid()
    ));

-- 6. سياسة التحديث (للقادة فقط)
CREATE POLICY "Allow leaders to update status" ON tribe_join_requests
    FOR UPDATE 
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM tribes 
            WHERE tribes.id = tribe_join_requests.tribe_id 
            AND tribes.leader_id = auth.uid()
        )
    );

-- 7. سياسة الحذف (للمستخدم لسحب طلبه)
CREATE POLICY "Allow users to delete their own requests" ON tribe_join_requests
    FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);
