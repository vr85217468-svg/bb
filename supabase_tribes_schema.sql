-- ============================================
-- نظام القبائل - Tribes System
-- قاعدة البيانات الكاملة
-- ============================================

-- ============================================
-- 1. جدول القبائل (Tribes)
-- ============================================
CREATE TABLE IF NOT EXISTS tribes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tribe_code VARCHAR(5) UNIQUE NOT NULL,
  name TEXT NOT NULL,
  name_en TEXT,
  description TEXT,
  icon TEXT NOT NULL DEFAULT '⚔️',
  is_private BOOLEAN DEFAULT false,
  leader_id UUID REFERENCES users(id) ON DELETE CASCADE,
  member_count INT DEFAULT 1 CHECK (member_count >= 0 AND member_count <= 12),
  max_members INT DEFAULT 12,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes للبحث السريع
CREATE INDEX IF NOT EXISTS idx_tribes_code ON tribes(tribe_code);
CREATE INDEX IF NOT EXISTS idx_tribes_name ON tribes USING gin(to_tsvector('arabic', name));
CREATE INDEX IF NOT EXISTS idx_tribes_leader ON tribes(leader_id);
CREATE INDEX IF NOT EXISTS idx_tribes_private ON tribes(is_private);

-- ============================================
-- 2. جدول أعضاء القبائل (Tribe Members)
-- ============================================
CREATE TABLE IF NOT EXISTS tribe_members (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tribe_id UUID REFERENCES tribes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  is_leader BOOLEAN DEFAULT false,
  joined_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tribe_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tribe_members_tribe ON tribe_members(tribe_id);
CREATE INDEX IF NOT EXISTS idx_tribe_members_user ON tribe_members(user_id);
CREATE INDEX IF NOT EXISTS idx_tribe_members_leader ON tribe_members(tribe_id, is_leader) WHERE is_leader = true;

-- ============================================
-- 3. جدول طلبات الانضمام (Join Requests)
-- ============================================
CREATE TABLE IF NOT EXISTS tribe_join_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tribe_id UUID REFERENCES tribes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(tribe_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tribe_requests_tribe ON tribe_join_requests(tribe_id, status);
CREATE INDEX IF NOT EXISTS idx_tribe_requests_user ON tribe_join_requests(user_id);

-- ============================================
-- 4. جدول رسائل القبائل (Tribe Messages)
-- ============================================
CREATE TABLE IF NOT EXISTS tribe_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tribe_id UUID REFERENCES tribes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  message TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'sticker')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tribe_messages_tribe ON tribe_messages(tribe_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_tribe_messages_user ON tribe_messages(user_id);

-- ============================================
-- 5. دالة توليد الكود الفريد
-- ============================================
CREATE OR REPLACE FUNCTION generate_tribe_code()
RETURNS TEXT AS $$
DECLARE
  chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- بدون أحرف مربكة
  result TEXT := '';
  i INT;
BEGIN
  FOR i IN 1..5 LOOP
    result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
  END LOOP;
  
  -- التحقق من عدم التكرار
  WHILE EXISTS (SELECT 1 FROM tribes WHERE tribe_code = result) LOOP
    result := '';
    FOR i IN 1..5 LOOP
      result := result || substr(chars, floor(random() * length(chars) + 1)::int, 1);
    END LOOP;
  END LOOP;
  
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- 6. دالة تحديث عدد الأعضاء تلقائياً
-- ============================================
CREATE OR REPLACE FUNCTION update_tribe_member_count()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE tribes 
    SET member_count = member_count + 1,
        updated_at = NOW()
    WHERE id = NEW.tribe_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE tribes 
    SET member_count = member_count - 1,
        updated_at = NOW()
    WHERE id = OLD.tribe_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Trigger للأعضاء
DROP TRIGGER IF EXISTS tribe_member_count_trigger ON tribe_members;
CREATE TRIGGER tribe_member_count_trigger
AFTER INSERT OR DELETE ON tribe_members
FOR EACH ROW EXECUTE FUNCTION update_tribe_member_count();

-- ============================================
-- 7. دالة منع تجاوز الحد الأقصى للأعضاء
-- ============================================
CREATE OR REPLACE FUNCTION check_tribe_capacity()
RETURNS TRIGGER AS $$
DECLARE
  current_count INT;
  max_count INT;
BEGIN
  SELECT member_count, max_members 
  INTO current_count, max_count
  FROM tribes 
  WHERE id = NEW.tribe_id;
  
  IF current_count >= max_count THEN
    RAISE EXCEPTION 'القبيلة ممتلئة - الحد الأقصى % أعضاء', max_count;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger للتحقق من السعة
DROP TRIGGER IF EXISTS check_capacity_trigger ON tribe_members;
CREATE TRIGGER check_capacity_trigger
BEFORE INSERT ON tribe_members
FOR EACH ROW EXECUTE FUNCTION check_tribe_capacity();

-- ============================================
-- 8. دالة تحديث timestamp تلقائياً
-- ============================================
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers للتحديث التلقائي
DROP TRIGGER IF EXISTS tribes_updated_at ON tribes;
CREATE TRIGGER tribes_updated_at
BEFORE UPDATE ON tribes
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

DROP TRIGGER IF EXISTS requests_updated_at ON tribe_join_requests;
CREATE TRIGGER requests_updated_at
BEFORE UPDATE ON tribe_join_requests
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- 9. Row Level Security (RLS) - اختياري
-- ============================================
-- يمكنك تفعيل RLS للأمان الإضافي

-- ALTER TABLE tribes ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE tribe_members ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE tribe_join_requests ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE tribe_messages ENABLE ROW LEVEL SECURITY;

-- ============================================
-- 10. بيانات تجريبية (اختياري)
-- ============================================
-- يمكنك حذف هذا القسم بعد الاختبار

-- INSERT INTO tribes (tribe_code, name, name_en, description, icon, is_private, leader_id)
-- VALUES 
--   (generate_tribe_code(), 'محاربو النور', 'Light Warriors', 'قبيلة للمحاربين الشجعان', '⚔️', false, 'USER_ID_HERE'),
--   (generate_tribe_code(), 'حماة القرآن', 'Quran Guardians', 'نحفظ ونتدارس القرآن', '📿', false, 'USER_ID_HERE');

-- ============================================
-- تم! ✅
-- ============================================
-- الآن قم بتنفيذ هذا الكود في Supabase SQL Editor

-- ============================================
-- ============================================
-- الميزات المتقدمة - Advanced Features
-- ============================================
-- ============================================

-- ============================================
-- 11. جدول الحظر (Tribe Bans)
-- ============================================
CREATE TABLE IF NOT EXISTS tribe_bans (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  tribe_id UUID REFERENCES tribes(id) ON DELETE CASCADE NOT NULL,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  banned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  banned_at TIMESTAMPTZ DEFAULT NOW(),
  reason TEXT,
  UNIQUE(tribe_id, user_id)
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_tribe_bans_tribe ON tribe_bans(tribe_id);
CREATE INDEX IF NOT EXISTS idx_tribe_bans_user ON tribe_bans(user_id);

-- ============================================
-- 12. دالة نقل القيادة التلقائي
-- ============================================
CREATE OR REPLACE FUNCTION transfer_leadership_on_leave()
RETURNS TRIGGER AS $$
DECLARE
  tribe_rec RECORD;
  new_leader_id UUID;
  remaining_members INT;
BEGIN
  -- فحص إذا كان المغادر هو القائد
  SELECT t.id, t.leader_id INTO tribe_rec
  FROM tribes t
  WHERE t.id = OLD.tribe_id AND t.leader_id = OLD.user_id;
  
  IF FOUND THEN
    -- حساب عدد الأعضاء المتبقين (غير القائد)
    SELECT COUNT(*) INTO remaining_members
    FROM tribe_members
    WHERE tribe_id = OLD.tribe_id AND user_id != OLD.user_id;
    
    IF remaining_members > 0 THEN
      -- اختيار عضو عشوائي جديد كقائد
      SELECT user_id INTO new_leader_id
      FROM tribe_members  
      WHERE tribe_id = OLD.tribe_id AND user_id != OLD.user_id
      ORDER BY RANDOM()
      LIMIT 1;
      
      -- تحديث القائد الجديد
      UPDATE tribes SET leader_id = new_leader_id WHERE id = OLD.tribe_id;
      UPDATE tribe_members SET is_leader = true 
      WHERE tribe_id = OLD.tribe_id AND user_id = new_leader_id;
      
      RAISE NOTICE 'تم نقل القيادة للعضو %', new_leader_id;
    ELSE
      -- لا يوجد أعضاء آخرون، حذف القبيلة
      DELETE FROM tribes WHERE id = OLD.tribe_id;
      RAISE NOTICE 'تم حذف القبيلة % لعدم وجود أعضاء', OLD.tribe_id;
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Trigger لنقل القيادة عند المغادرة
DROP TRIGGER IF EXISTS auto_transfer_leadership ON tribe_members;
CREATE TRIGGER auto_transfer_leadership
BEFORE DELETE ON tribe_members
FOR EACH ROW EXECUTE FUNCTION transfer_leadership_on_leave();

-- ============================================
-- 13. دالة منع تعدد العضوية
-- ============================================
CREATE OR REPLACE FUNCTION prevent_multiple_tribes()
RETURNS TRIGGER AS $$
DECLARE
  existing_tribe_id UUID;
BEGIN
  -- فحص إذا كان المستخدم عضو في قبيلة أخرى
  SELECT tribe_id INTO existing_tribe_id
  FROM tribe_members
  WHERE user_id = NEW.user_id
  LIMIT 1;
  
  IF FOUND THEN
    RAISE EXCEPTION 'المستخدم عضو بالفعل في قبيلة أخرى (%)، يجب المغادرة أولاً', existing_tribe_id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger لمنع تعدد العضوية
DROP TRIGGER IF EXISTS prevent_multi_tribe_membership ON tribe_members;
CREATE TRIGGER prevent_multi_tribe_membership
BEFORE INSERT ON tribe_members
FOR EACH ROW EXECUTE FUNCTION prevent_multiple_tribes();

-- ============================================
-- 14. دالة فحص الحظر عند الانضمام
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

-- Trigger لفحص الحظر
DROP TRIGGER IF EXISTS check_user_ban ON tribe_members;
CREATE TRIGGER check_user_ban
BEFORE INSERT ON tribe_members
FOR EACH ROW EXECUTE FUNCTION check_ban_status();

-- ============================================
-- نهاية الميزات المتقدمة ✅
-- ============================================
