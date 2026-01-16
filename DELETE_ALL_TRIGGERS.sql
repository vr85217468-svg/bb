-- ============================================
-- حذف جميع triggers على DELETE
-- نفذ هذا مرة واحدة فقط
-- ============================================

-- حذف جميع triggers على tribe_members
DROP TRIGGER IF EXISTS tribe_member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS update_member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS transfer_leadership_on_leader_leave ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS handle_leader_leave_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS after_member_delete_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS tribe_member_insert_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS member_count_increment ON tribe_members CASCADE;

-- حذف الدوال
DROP FUNCTION IF EXISTS update_tribe_member_count() CASCADE;
DROP FUNCTION IF EXISTS transfer_leadership_on_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_tribe_member_delete() CASCADE;
DROP FUNCTION IF EXISTS leave_tribe_safe(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS increment_tribe_member_count() CASCADE;
DROP FUNCTION IF EXISTS increment_member_count() CASCADE;

-- التحقق: يجب أن يكون الناتج فارغاً
SELECT trigger_name FROM information_schema.triggers 
WHERE event_object_table = 'tribe_members';

-- ============================================
-- تم! الكود سيتولى كل شيء الآن
-- ============================================
