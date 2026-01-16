-- إنشاء جدول إعدادات التطبيق
-- يستخدم لتخزين الإعدادات العامة للتطبيق مثل اسم التطبيق

CREATE TABLE IF NOT EXISTS app_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  setting_key TEXT UNIQUE NOT NULL,
  setting_value TEXT NOT NULL,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إضافة القيمة الافتراضية لاسم التطبيق
INSERT INTO app_settings (setting_key, setting_value) 
VALUES ('app_name', 'تطبيق تسجيل الدخول')
ON CONFLICT (setting_key) DO NOTHING;

-- تفعيل Row Level Security
ALTER TABLE app_settings ENABLE ROW LEVEL SECURITY;

-- Policy: السماح للجميع بقراءة الإعدادات
CREATE POLICY "Allow public read access on app_settings"
  ON app_settings FOR SELECT
  USING (true);

-- Policy: السماح بالتعديل فقط للمستخدمين المصادق عليهم
-- (سيتم التحقق من صلاحية المسؤول داخل دالة RPC)
CREATE POLICY "Allow admin update on app_settings"
  ON app_settings FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- إنشاء دالة RPC لتحديث اسم التطبيق
-- تتحقق من كلمة مرور المسؤول قبل السماح بالتعديل
CREATE OR REPLACE FUNCTION update_app_name(
  new_name TEXT,
  admin_password TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  stored_password TEXT;
BEGIN
  -- التحقق من كلمة مرور المسؤول
  SELECT password INTO stored_password 
  FROM admin_credentials 
  WHERE id = 'admin' 
  LIMIT 1;
  
  IF stored_password IS NULL OR stored_password != admin_password THEN
    RETURN FALSE;
  END IF;
  
  -- تحديث اسم التطبيق
  UPDATE app_settings 
  SET setting_value = new_name, 
      updated_at = NOW()
  WHERE setting_key = 'app_name';
  
  RETURN TRUE;
END;
$$;

-- إنشاء دالة لتحديث updated_at تلقائياً عند التعديل
CREATE OR REPLACE FUNCTION update_app_settings_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- إنشاء Trigger لتحديث updated_at تلقائياً
CREATE TRIGGER app_settings_updated_at
  BEFORE UPDATE ON app_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_app_settings_timestamp();

-- عرض النتيجة للتأكد من النجاح
SELECT * FROM app_settings WHERE setting_key = 'app_name';
