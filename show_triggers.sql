-- ============================================
-- الخطوة 1: عرض جميع triggers على tribe_members
-- نفذ هذا أولاً وأخبرني بالنتيجة!
-- ============================================

SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members';
