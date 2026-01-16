-- ============================================
-- إصلاح شامل لمشاكل المغادرة والجلسات
-- Comprehensive Fix for Leave/Session Issues
-- ============================================

-- 1. التأكد من وجود حقل updated_at في جدول الجلسات
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='user_sessions' AND column_name='updated_at') THEN
        ALTER TABLE user_sessions ADD COLUMN updated_at TIMESTAMPTZ DEFAULT NOW();
    END IF;
END $$;

-- 2. تحديث دالة نقل القيادة (إزالة الحقل غير الموجود tribe_members.updated_at)
CREATE OR REPLACE FUNCTION handle_leader_leave()
RETURNS TRIGGER AS $$
DECLARE
  next_leader_id UUID;
BEGIN
  -- فقط في حالة الحذف (المغادرة)
  IF TG_OP = 'DELETE' THEN
    -- التحقق: هل المغادر كان قائداً؟
    IF OLD.is_leader = true THEN
      
      -- البحث عن أقدم عضو (بعد القائد السابق)
      SELECT user_id INTO next_leader_id
      FROM tribe_members
      WHERE tribe_id = OLD.tribe_id
        AND user_id != OLD.user_id
      ORDER BY joined_at ASC
      LIMIT 1;

      -- إذا وُجد عضو آخر، نقل القيادة له
      IF next_leader_id IS NOT NULL THEN
        UPDATE tribe_members
        SET is_leader = true
        WHERE tribe_id = OLD.tribe_id
          AND user_id = next_leader_id;
          
        -- تحديث القائد في جدول القبائل أيضاً
        UPDATE tribes 
        SET leader_id = next_leader_id 
        WHERE id = OLD.tribe_id;
        
        RAISE NOTICE '👑 Leadership transferred to user %', next_leader_id;
      ELSE
        -- لا يوجد أعضاء آخرون - حذف القبيلة
        -- ملاحظة: هذا سيتم حذفه بواسطة CASCADE أو يدوياً، لكن للأمان:
        DELETE FROM tribes WHERE id = OLD.tribe_id;
        RAISE NOTICE '🗑️ Last member left, tribe deleted';
      END IF;
    END IF;
  END IF;

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 3. إعادة تعيين الـ Trigger للتأكد من استخدام النسخة الجديدة
DROP TRIGGER IF EXISTS handle_leader_leave_trigger ON tribe_members;
CREATE TRIGGER handle_leader_leave_trigger
AFTER DELETE ON tribe_members
FOR EACH ROW
EXECUTE FUNCTION handle_leader_leave();

-- 4. إزالة الـ Trigger القديم المتعارض (إن وجد)
DROP TRIGGER IF EXISTS auto_transfer_leadership ON tribe_members;

-- ============================================
-- تم الإصلاح! ✅
-- ============================================
