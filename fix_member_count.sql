-- ============================================
-- إصلاح عداد الأعضاء في القبائل
-- Fix Member Count Issue
-- ============================================

-- ============================================
-- 1. تصحيح العداد الحالي لجميع القبائل
-- ============================================
UPDATE tribes
SET member_count = (
  SELECT COUNT(*) 
  FROM tribe_members 
  WHERE tribe_members.tribe_id = tribes.id
);

-- ============================================
-- 2. التحقق من النتائج
-- ============================================
SELECT 
  t.id,
  t.name,
  t.member_count as current_count,
  (SELECT COUNT(*) FROM tribe_members WHERE tribe_id = t.id) as actual_count,
  CASE 
    WHEN t.member_count = (SELECT COUNT(*) FROM tribe_members WHERE tribe_id = t.id) 
    THEN '✅ صحيح'
    ELSE '❌ خطأ'
  END as status
FROM tribes t
ORDER BY t.created_at DESC;

-- ============================================
-- 3. إصلاح trigger update_tribe_member_count
-- (التأكد من أنه يحسب بشكل صحيح)
-- ============================================
CREATE OR REPLACE FUNCTION update_tribe_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE tribes 
    SET member_count = (SELECT COUNT(*) FROM tribe_members WHERE tribe_id = NEW.tribe_id),
        updated_at = NOW()
    WHERE id = NEW.tribe_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE tribes 
    SET member_count = (SELECT COUNT(*) FROM tribe_members WHERE tribe_id = OLD.tribe_id),
        updated_at = NOW()
    WHERE id = OLD.tribe_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 4. إعادة إنشاء الـ Trigger
-- ============================================
DROP TRIGGER IF EXISTS tribe_member_count_trigger ON tribe_members;
CREATE TRIGGER tribe_member_count_trigger
AFTER INSERT OR DELETE ON tribe_members
FOR EACH ROW EXECUTE FUNCTION update_tribe_member_count();

-- ============================================
-- 5. اختبار النظام
-- ============================================
-- بعد تنفيذ هذا الكود، جرب:
-- 1. إضافة عضو لقبيلة
-- 2. طرد عضو من قبيلة
-- 3. التحقق من أن العداد يتحدث بشكل صحيح

-- ============================================
-- تم! ✅
-- ============================================
