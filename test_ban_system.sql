-- ============================================
-- اختبار نظام الطرد والحظر - Testing Kick & Ban System
-- نفذ هذا الكود في Supabase SQL Editor للتحقق
-- ============================================

-- ============================================
-- 1. عرض جميع المحظورين حالياً
-- ============================================
SELECT 
  tb.id,
  tb.user_id,
  tb.tribe_id,
  tb.banned_by,
  tb.banned_at,
  tb.reason,
  t.name as tribe_name,
  u.name as banned_user_name,
  b.name as banned_by_name
FROM tribe_bans tb
LEFT JOIN tribes t ON tb.tribe_id = t.id
LEFT JOIN users u ON tb.user_id = u.id
LEFT JOIN users b ON tb.banned_by = b.id
ORDER BY tb.banned_at DESC;

-- ============================================
-- 2. عد المحظورين لكل قبيلة
-- ============================================
SELECT 
  t.name as tribe_name,
  COUNT(tb.id) as banned_count
FROM tribes t
LEFT JOIN tribe_bans tb ON t.id = tb.tribe_id
GROUP BY t.id, t.name
ORDER BY banned_count DESC;

-- ============================================
-- 3. حذف جميع المحظورين (لإعادة الاختبار)
-- ============================================
-- ⚠️ تحذير: هذا سيحذف جميع السجلات!
-- نفذه فقط إذا كنت تريد مسح البيانات للاختبار
-- DELETE FROM tribe_bans;

-- ============================================
-- 4. اختبار إدراج يدوي (للتجربة)
-- ============================================
-- استبدل القيم بقيم حقيقية من قاعدة بياناتك
-- INSERT INTO tribe_bans (tribe_id, user_id, banned_by, reason)
-- VALUES (
--   'TRIBE_ID_HERE',
--   'USER_ID_HERE',
--   'LEADER_ID_HERE',
--   'اختبار يدوي'
-- );

-- ============================================
-- 5. التحقق من أن الـ UNIQUE constraint يعمل
-- ============================================
-- جرب إدراج نفس المستخدم مرتين - يجب أن يفشل
-- INSERT INTO tribe_bans (tribe_id, user_id, banned_by, reason)
-- VALUES (
--   'SAME_TRIBE_ID',
--   'SAME_USER_ID',
--   'LEADER_ID',
--   'محاولة ثانية'
-- );
-- Expected: ERROR: duplicate key value violates unique constraint

-- ============================================
-- 6. فحص الـ Triggers النشطة
-- ============================================
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_timing,
  action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('tribe_bans', 'tribe_members')
ORDER BY event_object_table, trigger_name;

-- ============================================
-- تم! ✅
-- ============================================
