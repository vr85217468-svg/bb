-- ================================================
-- كود إنقاذ: إصلاح بيانات القادة والأعضاء
-- ================================================

-- 1. التأكد من أن كل قائد قبيلة موجود في جدول الأعضاء كـ "نشط" ومعه صلاحية القيادة
INSERT INTO tribe_members (tribe_id, user_id, is_leader, status)
SELECT id, leader_id, true, 'active'
FROM tribes
ON CONFLICT (tribe_id, user_id) 
DO UPDATE SET 
    is_leader = true,
    status = 'active';

-- 2. التأكد من أن جميع الأعضاء الحاليين (غير القادة) حالتهم نشطة إذا لم تكن معلقة
UPDATE tribe_members 
SET status = 'active' 
WHERE status IS NULL;

-- 3. تحديث عداد الأعضاء الفعليين في كل قبيلة بناءً على الحالة النشطة فقط
UPDATE tribes t
SET member_count = (
    SELECT COUNT(*) 
    FROM tribe_members m 
    WHERE m.tribe_id = t.id 
    AND m.status = 'active'
);
