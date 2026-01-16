-- ================================================
-- إصلاح الدوال التلقائية (Triggers) لتتوافق مع نظام العضوية المعلقة
-- ================================================

-- 1. تحديث دالة نقل القيادة: يجب أن تنقل القيادة لعضو "نشط" فقط
CREATE OR REPLACE FUNCTION transfer_leadership_on_leave()
RETURNS TRIGGER AS $$
DECLARE
  tribe_rec RECORD;
  new_leader_id UUID;
  remaining_active_members INT;
BEGIN
  -- فحص إذا كان المغادر هو القائد (وكان نشطاً)
  SELECT t.id, t.leader_id INTO tribe_rec
  FROM tribes t
  WHERE t.id = OLD.tribe_id AND t.leader_id = OLD.user_id;
  
  IF FOUND THEN
    -- حساب عدد الأعضاء "النشطين" المتبقين فقط
    SELECT COUNT(*) INTO remaining_active_members
    FROM tribe_members
    WHERE tribe_id = OLD.tribe_id 
    AND user_id != OLD.user_id 
    AND status = 'active';
    
    IF remaining_active_members > 0 THEN
      -- اختيار عضو نشط عشوائي جديد كقائد
      SELECT user_id INTO new_leader_id
      FROM tribe_members  
      WHERE tribe_id = OLD.tribe_id 
      AND user_id != OLD.user_id 
      AND status = 'active'
      ORDER BY RANDOM()
      LIMIT 1;
      
      -- تحديث القائد الجديد في جدول القبائل
      UPDATE tribes SET leader_id = new_leader_id WHERE id = OLD.tribe_id;
      
      -- تحديث حالة العضو الجديد ليكون قائداً
      UPDATE tribe_members SET is_leader = true 
      WHERE tribe_id = OLD.tribe_id AND user_id = new_leader_id;
      
      RAISE NOTICE 'تم نقل القيادة للعضو النشط %', new_leader_id;
    ELSE
      -- لا يوجد أعضاء نشطون آخرون، حذف القبيلة
      -- (سيؤدي هذا لحذف جميع السجلات المرتبطة بما فيها الطلبات المعلقة بسبب Cascade Delete)
      DELETE FROM tribes WHERE id = OLD.tribe_id;
      RAISE NOTICE 'تم حذف القبيلة % لعدم وجود أعضاء نشطين', OLD.tribe_id;
    END IF;
  END IF;
  
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- 2. تحديث دالة منع تعدد العضوية: تسمح بطلبات معلقة متعددة، ولكن عضوية نشطة واحدة فقط
CREATE OR REPLACE FUNCTION prevent_multiple_tribes()
RETURNS TRIGGER AS $$
DECLARE
  existing_active_tribe_id UUID;
BEGIN
  -- إذا كان العضو الجديد يحاول الانضمام كـ "نشط" (قبيلة عامة)
  -- أو يتم ترقيته لـ "نشط" (عبر Update)
  IF NEW.status = 'active' THEN
    SELECT tribe_id INTO existing_active_tribe_id
    FROM tribe_members
    WHERE user_id = NEW.user_id
    AND status = 'active'
    AND tribe_id != NEW.tribe_id -- للتأكد أنه ليس تحديثاً لنفس القبيلة
    LIMIT 1;
    
    IF FOUND THEN
      RAISE EXCEPTION 'المستخدم عضو بالفعل في قبيلة أخرى، يجب المغادرة أولاً';
    END IF;
  END IF;
  
  -- في حالة الـ Insert: نمنع تكرار نفس الطلب لنفس القبيلة (موجود بالفعل عبر Unique Constraint)
  -- ولكن نسمح له بطلبات 'pending' في قبائل مختلفة.
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. إعادة ربط الـ Trigger الخاص بمنع تعدد العضوية ليعمل عند الإضافة والتحديث
DROP TRIGGER IF EXISTS prevent_multi_tribe_membership ON tribe_members;
CREATE TRIGGER prevent_multi_tribe_membership
BEFORE INSERT OR UPDATE ON tribe_members
FOR EACH ROW EXECUTE FUNCTION prevent_multiple_tribes();

-- 4. تحديث دالة عدد الأعضاء: يجب أن تحسب الأعضاء "النشطين" فقط؟ 
-- أم تحسب الكل؟ عادة member_count في التطبيقات يمثل الأعضاء الفعليين.
-- سنقوم بتعديلها لتحسب فقط من حالتهم 'active'.

CREATE OR REPLACE FUNCTION update_tribe_member_count()
RETURNS TRIGGER AS $$
BEGIN
  -- عند الإضافة: نزيد العداد فقط إذا كان نشطاً
  IF TG_OP = 'INSERT' THEN
    IF NEW.status = 'active' THEN
      UPDATE tribes SET member_count = member_count + 1 WHERE id = NEW.tribe_id;
    END IF;
    
  -- عند التحديث: إذا تحول من pending إلى active نزيد العداد
  ELSIF TG_OP = 'UPDATE' THEN
    IF OLD.status = 'pending' AND NEW.status = 'active' THEN
      UPDATE tribes SET member_count = member_count + 1 WHERE id = NEW.tribe_id;
    ELSIF OLD.status = 'active' AND NEW.status = 'pending' THEN
      UPDATE tribes SET member_count = member_count - 1 WHERE id = NEW.tribe_id;
    END IF;

  -- عند الحذف: ننقص العداد فقط إذا كان المحذوف نشطاً
  ELSIF TG_OP = 'DELETE' THEN
    IF OLD.status = 'active' THEN
      UPDATE tribes SET member_count = member_count - 1 WHERE id = OLD.tribe_id;
    END IF;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- 5. تحديث فحص السعة: يجب أن يمنع التفعيل إذا كانت القبيلة ممتلئة
CREATE OR REPLACE FUNCTION check_tribe_capacity()
RETURNS TRIGGER AS $$
DECLARE
  current_count INT;
  max_count INT;
BEGIN
  -- يتم الفحص فقط عند الإضافة كنشط أو عند التفعيل من pending لـ active
  IF (TG_OP = 'INSERT' AND NEW.status = 'active') OR 
     (TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'active') THEN
    
    SELECT member_count, max_members 
    INTO current_count, max_count
    FROM tribes 
    WHERE id = NEW.tribe_id;
    
    IF current_count >= max_count THEN
      RAISE EXCEPTION 'القبيلة ممتلئة - الحد الأقصى % أعضاء', max_count;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إعادة ربط trigger فحص السعة ليشمل التحديث
DROP TRIGGER IF EXISTS check_capacity_trigger ON tribe_members;
CREATE TRIGGER check_capacity_trigger
BEFORE INSERT OR UPDATE ON tribe_members
FOR EACH ROW EXECUTE FUNCTION check_tribe_capacity();

-- إضافة ربط trigger عداد الأعضاء (مهم جداً)
DROP TRIGGER IF EXISTS tribe_member_count_trigger ON tribe_members;
CREATE TRIGGER tribe_member_count_trigger
AFTER INSERT OR DELETE OR UPDATE ON tribe_members
FOR EACH ROW EXECUTE FUNCTION update_tribe_member_count();
