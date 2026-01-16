-- ============================================
-- إصلاح نهائي لـ trigger المغادرة
-- النسخة 2 - حل شامل
-- ============================================

-- الخطوة 1: عرض جميع الـ triggers الموجودة على tribe_members
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members'
ORDER BY trigger_name;

-- ============================================
-- الخطوة 2: حذف جميع الـ triggers القديمة
-- ============================================

-- حذف أي trigger قد يكون موجود
DROP TRIGGER IF EXISTS transfer_leadership_on_leader_leave ON tribe_members;
DROP TRIGGER IF EXISTS handle_leader_leave_trigger ON tribe_members;
DROP TRIGGER IF EXISTS update_member_count_trigger ON tribe_members;

-- حذف الدوال القديمة
DROP FUNCTION IF EXISTS transfer_leadership_on_leader_leave() CASCADE;
DROP FUNCTION IF EXISTS handle_leader_leave() CASCADE;

-- ============================================
-- الخطوة 3: إنشاء دالة جديدة محسّنة
-- ============================================
CREATE OR REPLACE FUNCTION handle_tribe_member_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_next_leader_id UUID;
BEGIN
  -- فقط إذا كان المحذوف قائداً
  IF OLD.is_leader = true THEN
    -- البحث عن أقدم عضو آخر
    SELECT user_id INTO v_next_leader_id
    FROM tribe_members
    WHERE tribe_id = OLD.tribe_id
      AND user_id != OLD.user_id
    ORDER BY joined_at ASC
    LIMIT 1;

    -- نقل القيادة إذا وُجد عضو
    IF v_next_leader_id IS NOT NULL THEN
      UPDATE tribe_members
      SET is_leader = true
      WHERE tribe_id = OLD.tribe_id
        AND user_id = v_next_leader_id;
    END IF;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- الخطوة 4: إنشاء AFTER DELETE trigger
-- ============================================
CREATE TRIGGER after_member_delete_trigger
AFTER DELETE ON tribe_members
FOR EACH ROW
EXECUTE FUNCTION handle_tribe_member_delete();

-- ============================================
-- الخطوة 5: إعادة إنشاء trigger عداد الأعضاء (AFTER)
-- ============================================
CREATE OR REPLACE FUNCTION update_tribe_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE tribes
    SET member_count = member_count + 1
    WHERE id = NEW.tribe_id;
    RETURN NEW;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE tribes
    SET member_count = GREATEST(member_count - 1, 0)
    WHERE id = OLD.tribe_id;
    RETURN OLD;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER member_count_trigger
AFTER INSERT OR DELETE ON tribe_members
FOR EACH ROW
EXECUTE FUNCTION update_tribe_member_count();

-- ============================================
-- تم! ✅
-- ============================================

-- للتحقق من الـ triggers الجديدة:
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'tribe_members'
ORDER BY action_timing, trigger_name;
