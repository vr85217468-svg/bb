-- ============================================
-- تشخيص مشكلة الحظر - Debugging Ban Issue
-- نفذ هذا الكود في Supabase SQL Editor للتحقق
-- ============================================

-- ============================================
-- 1. عرض جميع المحظورين
-- ============================================
SELECT 
  tb.id,
  tb.tribe_id,
  tb.user_id,
  tb.banned_by,
  tb.banned_at,
  tb.reason,
  t.name as tribe_name,
  u.name as banned_user_name
FROM tribe_bans tb
LEFT JOIN tribes t ON tb.tribe_id = t.id
LEFT JOIN users u ON tb.user_id = u.id
ORDER BY tb.banned_at DESC;

-- ============================================
-- 2. التحقق من Trigger
-- ============================================
-- عرض تعريف الدالة
SELECT pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'check_ban_status';

-- ============================================
-- 3. عرض جميع Triggers على tribe_members
-- ============================================
SELECT 
  trigger_name,
  event_manipulation,
  action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members';

-- ============================================
-- 4. حذف الـ Trigger المشكل (إن وجد)
-- ============================================
-- نفذ هذا فقط إذا كنت تريد تعطيل فحص الحظر مؤقتاً للاختبار
-- DROP TRIGGER IF EXISTS check_user_ban ON tribe_members;

-- ============================================
-- 5. إعادة إنشاء الـ Trigger بشكل صحيح
-- ============================================
DROP TRIGGER IF EXISTS check_user_ban ON tribe_members;

CREATE OR REPLACE FUNCTION check_ban_status()
RETURNS TRIGGER AS $$
BEGIN
  -- Debug: طباعة المعلومات
  RAISE NOTICE 'Checking ban for user % in tribe %', NEW.user_id, NEW.tribe_id;
  
  -- فحص إذا كان المستخدم المحدد محظور من القبيلة المحددة
  IF EXISTS (
    SELECT 1 FROM tribe_bans 
    WHERE tribe_id = NEW.tribe_id 
    AND user_id = NEW.user_id
  ) THEN
    RAISE NOTICE 'User % IS BANNED from tribe %', NEW.user_id, NEW.tribe_id;
    RAISE EXCEPTION 'أنت محظور من هذه القبيلة';
  END IF;
  
  RAISE NOTICE 'User % is NOT banned from tribe %', NEW.user_id, NEW.tribe_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_user_ban
BEFORE INSERT ON tribe_members
FOR EACH ROW EXECUTE FUNCTION check_ban_status();

-- ============================================
-- 6. اختبار الحظر
-- ============================================
-- استبدل USER_ID و TRIBE_ID بالقيم الحقيقية
-- SELECT * FROM tribe_bans 
-- WHERE tribe_id = 'TRIBE_ID_HERE' 
-- AND user_id = 'USER_ID_HERE';

-- ============================================
-- تم! ✅
-- ============================================
