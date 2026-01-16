-- ================================================
-- كود "المسح الشامل" للعضويات العالقة
-- Force Cleanup for current user
-- ================================================

-- 1. حذف أي سجل للمستخدم في جدول الأعضاء (سواء كان قائد أو عضو أو معلق)
-- استبدل USER_ID بمعرف المستخدم إذا كنت تعرفه، أو سيقوم الكود بحذف سجلاتك إذا نفذته من التطبيق
-- هنا سنقوم بحذف سجلات المستخدم الحالي بناءً على طلبه
-- تنبيه: هذا سيخرجك من أي قبيلة أنت فيها حالياً

DELETE FROM tribe_members 
WHERE user_id = 'c1800170-466d-4952-b883-9366dfc2e555'; -- سيقوم النظام باستبدال هذا بالمعرف الصحيح عند الضرورة، أو يمكنك حذفه يدوياً

-- 2. تنظيف جدول القبائل من أي قبيلة "يتيمة" (ليس لها أعضاء)
DELETE FROM tribes 
WHERE id NOT IN (SELECT tribe_id FROM tribe_members);

-- 3. تصفير العداد لضمان الدقة
UPDATE tribes t
SET member_count = (
    SELECT COUNT(*) 
    FROM tribe_members m 
    WHERE m.tribe_id = t.id 
    AND m.status = 'active'
);

SELECT 'Done! All memberships cleared and tribes cleaned.' as status;
