-- ============================================
-- إصلاح نظام الحظر - Tribe Ban System Fix
-- نفذ هذا الكود في Supabase SQL Editor
-- ============================================

-- ============================================
-- 1. حذف الجدول القديم إن وجد (لإعادة إنشائه بشكل صحيح)
-- ============================================
DROP TABLE IF EXISTS tribe_bans CASCADE;

-- ============================================
-- 2. إنشاء جدول الحظر
-- ============================================
CREATE TABLE tribe_bans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tribe_id UUID REFERENCES tribes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  banned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  banned_at TIMESTAMPTZ DEFAULT NOW(),
  reason TEXT,
  UNIQUE(tribe_id, user_id)
);

-- ============================================
-- 3. إنشاء Indexes للبحث السريع
-- ============================================
CREATE INDEX idx_tribe_bans_tribe ON tribe_bans(tribe_id);
CREATE INDEX idx_tribe_bans_user ON tribe_bans(user_id);

-- ============================================
-- 4. تعطيل RLS (للاختبار)
-- ============================================
ALTER TABLE tribe_bans DISABLE ROW LEVEL SECURITY;

-- ============================================
-- 5. دالة فحص الحظر عند الانضمام
-- ============================================
CREATE OR REPLACE FUNCTION check_ban_status()
RETURNS TRIGGER AS $$
BEGIN
  -- فحص إذا كان المستخدم محظور
  IF EXISTS (
    SELECT 1 FROM tribe_bans 
    WHERE tribe_id = NEW.tribe_id AND user_id = NEW.user_id
  ) THEN
    RAISE EXCEPTION 'أنت محظور من هذه القبيلة';
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. Trigger لمنع المحظورين من الانضمام
-- ============================================
DROP TRIGGER IF EXISTS check_user_ban ON tribe_members;
CREATE TRIGGER check_user_ban
BEFORE INSERT ON tribe_members
FOR EACH ROW EXECUTE FUNCTION check_ban_status();

-- ============================================
-- تم! ✅
-- ============================================
-- الآن جرب طرد عضو وسيُضاف للمحظورين تلقائياً

-- ============================================
-- للتحقق من أن الجدول تم إنشاؤه بنجاح:
-- ============================================
SELECT * FROM tribe_bans LIMIT 1;
