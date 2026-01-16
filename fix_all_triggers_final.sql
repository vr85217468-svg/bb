-- ============================================
-- الحل النهائي الشامل - حذف جميع triggers
-- ============================================

-- الخطوة 1: عرض جميع triggers الموجودة على tribe_members
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members'
ORDER BY trigger_name;

-- ============================================
-- الخطوة 2: حذف جميع triggers على tribe_members
-- ============================================

-- قائمة شاملة بجميع الأسماء الممكنة
DROP TRIGGER IF EXISTS transfer_leadership_on_leader_leave ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS handle_leader_leave_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS after_member_delete_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS update_member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS update_tribe_member_count_on_insert ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS update_tribe_member_count_on_delete ON tribe_members CASCADE;

-- حذف جميع الدوال المتعلقة
DROP FUNCTION IF EXISTS transfer_leadership_on_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_tribe_member_delete() CASCADE;
DROP FUNCTION IF EXISTS update_tribe_member_count() CASCADE;

-- ============================================
-- الخطوة 3: إنشاء RPC لمغادرة القبيلة
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
  -- 1. الحصول على معلومات العضو
  SELECT is_leader INTO v_is_leader
  FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  IF v_is_leader IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not a member');
  END IF;

  -- 2. إذا كان قائداً، نقل القيادة أولاً
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

  -- 3. حذف العضو (بدون triggers الآن!)
  DELETE FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  -- 4. تحديث العداد يدوياً
  SELECT COUNT(*) INTO v_member_count
  FROM tribe_members
  WHERE tribe_id = p_tribe_id;

  UPDATE tribes
  SET member_count = v_member_count
  WHERE id = p_tribe_id;

  RETURN json_build_object(
    'success', true,
    'was_leader', v_is_leader,
    'new_leader', v_next_leader_id,
    'members_left', v_member_count
  );
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object(
    'success', false,
    'error', SQLERRM
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION leave_tribe_safe TO authenticated;

-- ============================================
-- الخطوة 4: trigger بسيط فقط لعداد الأعضاء عند الإضافة
-- (لن نستخدمه عند الحذف لأن RPC يتولى ذلك)
-- ============================================
CREATE OR REPLACE FUNCTION increment_member_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE tribes
  SET member_count = member_count + 1
  WHERE id = NEW.tribe_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER member_count_increment
AFTER INSERT ON tribe_members
FOR EACH ROW
EXECUTE FUNCTION increment_member_count();

-- ============================================
-- التحقق النهائي
-- ============================================
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members'
ORDER BY trigger_name;

-- يجب أن يظهر فقط: member_count_increment (INSERT)
-- ============================================
-- تم! ✅
-- ============================================
