-- ============================================
-- الحل النهائي: استخدام RPC بدلاً من DELETE المباشر
-- ============================================

-- حذف جميع triggers المتعلقة بنقل القيادة
DROP TRIGGER IF EXISTS transfer_leadership_on_leader_leave ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS handle_leader_leave_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS after_member_delete_trigger ON tribe_members CASCADE;

DROP FUNCTION IF EXISTS transfer_leadership_on_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_tribe_member_delete() CASCADE;

-- ============================================
-- إنشاء دالة RPC لمغادرة القبيلة بأمان
-- ============================================
CREATE OR REPLACE FUNCTION leave_tribe_safe(
  p_tribe_id UUID,
  p_user_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_is_leader BOOLEAN;
  v_next_leader_id UUID;
  v_member_count INT;
BEGIN
  -- 1. التحقق من العضوية والحصول على الدور
  SELECT is_leader INTO v_is_leader
  FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  IF v_is_leader IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not a member');
  END IF;

  -- 2. إذا كان قائداً، ابحث عن قائد جديد
  IF v_is_leader = true THEN
    SELECT user_id INTO v_next_leader_id
    FROM tribe_members
    WHERE tribe_id = p_tribe_id 
      AND user_id != p_user_id
    ORDER BY joined_at ASC
    LIMIT 1;

    -- نقل القيادة قبل الحذف
    IF v_next_leader_id IS NOT NULL THEN
      UPDATE tribe_members
      SET is_leader = true
      WHERE tribe_id = p_tribe_id AND user_id = v_next_leader_id;
    END IF;
  END IF;

  -- 3. حذف العضو
  DELETE FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  -- 4. تحديث عداد الأعضاء يدوياً
  SELECT COUNT(*) INTO v_member_count
  FROM tribe_members
  WHERE tribe_id = p_tribe_id;

  UPDATE tribes
  SET member_count = v_member_count
  WHERE id = p_tribe_id;

  -- 5. إذا لم يبقَ أحد، حذف القبيلة (اختياري)
  -- IF v_member_count = 0 THEN
  --   DELETE FROM tribes WHERE id = p_tribe_id;
  -- END IF;

  RETURN json_build_object(
    'success', true,
    'was_leader', v_is_leader,
    'new_leader', v_next_leader_id,
    'remaining_members', v_member_count
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- منح الصلاحيات
-- ============================================
GRANT EXECUTE ON FUNCTION leave_tribe_safe TO authenticated;

-- ============================================
-- تم! ✅
-- ============================================
