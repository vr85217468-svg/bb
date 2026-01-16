-- ============================================
-- الحل النهائي البسيط - حذف trigger على DELETE فقط
-- ============================================

-- حذف trigger العداد القديم تماماً
DROP TRIGGER IF EXISTS tribe_member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS update_member_count_trigger ON tribe_members CASCADE;
DROP TRIGGER IF EXISTS member_count_trigger ON tribe_members CASCADE;

DROP FUNCTION IF EXISTS update_tribe_member_count() CASCADE;

-- ============================================
-- إنشاء trigger جديد فقط للإضافة (INSERT)
-- ============================================
CREATE OR REPLACE FUNCTION increment_tribe_member_count()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE tribes 
  SET member_count = member_count + 1
  WHERE id = NEW.tribe_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tribe_member_insert_trigger
AFTER INSERT ON tribe_members
FOR EACH ROW 
EXECUTE FUNCTION increment_tribe_member_count();

-- ============================================
-- RPC للمغادرة (يتولى تحديث العداد يدوياً)
-- ============================================
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
  -- 1. معلومات العضو
  SELECT is_leader INTO v_is_leader
  FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  IF v_is_leader IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'Not a member');
  END IF;

  -- 2. نقل القيادة إذا لزم
  IF v_is_leader = true THEN
    SELECT user_id INTO v_next_leader_id
    FROM tribe_members
    WHERE tribe_id = p_tribe_id AND user_id != p_user_id
    ORDER BY joined_at ASC
    LIMIT 1;

    IF v_next_leader_id IS NOT NULL THEN
      UPDATE tribe_members
      SET is_leader = true
      WHERE tribe_id = p_tribe_id AND user_id = v_next_leader_id;
    END IF;
  END IF;

  -- 3. حذف العضو (لن يشتغل أي trigger الآن!)
  DELETE FROM tribe_members
  WHERE tribe_id = p_tribe_id AND user_id = p_user_id;

  -- 4. تحديث العداد يدوياً
  SELECT COUNT(*) INTO v_member_count FROM tribe_members WHERE tribe_id = p_tribe_id;
  UPDATE tribes SET member_count = v_member_count WHERE id = p_tribe_id;

  RETURN json_build_object('success', true, 'members_left', v_member_count);
  
EXCEPTION WHEN OTHERS THEN
  RETURN json_build_object('success', false, 'error', SQLERRM);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION leave_tribe_safe TO authenticated;

-- ============================================
-- التحقق النهائي
-- ============================================
SELECT 
    trigger_name,
    event_manipulation
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members';

-- النتيجة: trigger واحد فقط على INSERT
-- ============================================
-- تم! ✅
-- ============================================
