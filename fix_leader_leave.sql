-- ============================================
-- إصلاح trigger المغادرة للقائد
-- Fix Leave Tribe Leader Issue
-- ============================================

-- المشكلة الحالية: 
-- "tuple to be deleted was already modified by an operation triggered by the current command"
-- السبب: الـ trigger يحاول تعديل نفس الصف الذي يتم حذفه

-- ============================================
-- 1. حذف الـ Trigger القديم
-- ============================================
DROP TRIGGER IF EXISTS transfer_leadership_on_leader_leave ON tribe_members;
DROP FUNCTION IF EXISTS transfer_leadership_on_leader_leave();

-- ============================================
-- 2. إنشاء دالة جديدة مُحسّنة
-- ============================================
CREATE OR REPLACE FUNCTION handle_leader_leave()
RETURNS TRIGGER AS $$
DECLARE
  next_leader_id UUID;
  next_leader_join_date TIMESTAMPTZ;
BEGIN
  -- فقط في حالة الحذف (المغادرة)
  IF TG_OP = 'DELETE' THEN
    -- التحقق: هل المغادر كان قائداً؟
    IF OLD.is_leader = true THEN
      
      -- البحث عن أقدم عضو (بعد القائد السابق)
      SELECT user_id, joined_at INTO next_leader_id, next_leader_join_date
      FROM tribe_members
      WHERE tribe_id = OLD.tribe_id
        AND user_id != OLD.user_id  -- استبعاد القائد المغادر
      ORDER BY joined_at ASC
      LIMIT 1;

      -- إذا وُجد عضو آخر، نقل القيادة له
      IF next_leader_id IS NOT NULL THEN
        UPDATE tribe_members
        SET is_leader = true,
            updated_at = NOW()
        WHERE tribe_id = OLD.tribe_id
          AND user_id = next_leader_id;
          
        RAISE NOTICE '👑 Leadership transferred to user % in tribe %', next_leader_id, OLD.tribe_id;
      ELSE
        -- لا يوجد أعضاء آخرون - يمكن حذف القبيلة أو تركها فارغة
        RAISE NOTICE '⚠️ No members left in tribe % after leader left', OLD.tribe_id;
      END IF;
    END IF;
  END IF;

  RETURN OLD; -- مهم: نُرجع OLD في حالة DELETE
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 3. إنشاء Trigger جديد - AFTER DELETE
-- ============================================
-- ✅ استخدام AFTER بدلاً من BEFORE لتجنب تعديل الصف أثناء الحذف
CREATE TRIGGER handle_leader_leave_trigger
AFTER DELETE ON tribe_members   -- ✅ AFTER DELETE
FOR EACH ROW
EXECUTE FUNCTION handle_leader_leave();

-- ============================================
-- 4. اختبار التحديث
-- ============================================
-- بعد تنفيذ هذا السكريبت، جرّب:
-- 1. إنشاء قبيلة جديدة (أنت القائد)
-- 2. انضمام عضو آخر
-- 3. القائد يغادر
-- 4. يجب أن ينتقل القائد للعضو الآخر تلقائياً ✅

-- ============================================
-- تم! ✅
-- ============================================
