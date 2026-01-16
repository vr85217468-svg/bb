-- ============================================
-- نفذ هذا الاستعلام وأرسل لي النتيجة!
-- ============================================

SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members'
ORDER BY trigger_name;

-- ============================================
-- أرسل لي أسماء الـ triggers التي تظهر!
-- ============================================
