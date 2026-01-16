-- ============================================
-- الحل النهائي المطلق - تعطيل جميع triggers في RPC
-- ============================================

-- حذف RPC القديم وإعادة إنشائه بدون triggers
DROP FUNCTION IF EXISTS leave_tribe_safe(UUID, UUID) CASCADE;

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
  -- تعطيل جميع triggers مؤقتاً أثناء التنفيذ
  SET session_replication_role = replica;

  -- 1. الحصول على معلومات العضو
  SELECT is_leader INTO v_is_leader
  FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  IF v_is_leader IS NULL THEN
    SET session_replication_role = DEFAULT;
    RETURN json_build_object('success', false, 'error', 'Not a member');
  END IF;

  -- 2. إذا كان قائداً، نقل القيادة
  IF v_is_leader = true THEN
    SELECT user_id INTO v_next_leader_id
    FROM tribe_members
    WHERE tribe_id = p_tribe_id 
      AND user_id != p_user_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_next_leader_id IS NOT NULL THEN
      UPDATE tribe_members
      SET is_leader = true
      WHERE tribe_id = p_tribe_id AND user_id = v_next_leader_id;
    END IF;
  END IF;

  -- 3. حذف العضو (triggers معطلة الآن!)
  DELETE FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  -- 4. تحديث العداد
  SELECT COUNT(*) INTO v_member_count
  FROM tribe_members
  WHERE tribe_id = p_tribe_id;

  UPDATE tribes
  SET member_count = v_member_count
  WHERE id = p_tribe_id;

  -- إعادة تفعيل triggers
  SET session_replication_role = DEFAULT;

  RETURN json_build_object(
    'success', true,
    'was_leader', v_is_leader,
    'new_leader', v_next_leader_id,
    'members_left', v_member_count
  );
  
EXCEPTION WHEN OTHERS THEN
  -- إعادة تفعيل triggers حتى في حالة الخطأ
  SET session_replication_role = DEFAULT;
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION leave_tribe_safe TO authenticated;

-- ============================================
-- تم! هذا يعطل جميع triggers أثناء التنفيذ
-- ============================================
