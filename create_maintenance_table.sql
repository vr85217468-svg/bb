-- ======================================================
-- جدول إعدادات الصيانة
-- نفذ هذا الكود في Supabase SQL Editor
-- ======================================================

-- إنشاء جدول إعدادات الصيانة
CREATE TABLE IF NOT EXISTS maintenance_settings (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  is_enabled BOOLEAN DEFAULT false,
  message TEXT DEFAULT 'التطبيق تحت الصيانة حالياً، يرجى المحاولة لاحقاً',
  excluded_user_ids TEXT[] DEFAULT '{}',
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_by UUID
);

-- إدخال صف افتراضي
INSERT INTO maintenance_settings (is_enabled, message, excluded_user_ids)
SELECT false, 'التطبيق تحت الصيانة حالياً، يرجى المحاولة لاحقاً', '{}'
WHERE NOT EXISTS (SELECT 1 FROM maintenance_settings);

-- تعطيل RLS
ALTER TABLE maintenance_settings DISABLE ROW LEVEL SECURITY;

-- دالة لتحديث timestamp عند التعديل
CREATE OR REPLACE FUNCTION update_maintenance_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger لتحديث الـ timestamp
DROP TRIGGER IF EXISTS update_maintenance_timestamp_trigger ON maintenance_settings;
CREATE TRIGGER update_maintenance_timestamp_trigger
  BEFORE UPDATE ON maintenance_settings
  FOR EACH ROW
  EXECUTE FUNCTION update_maintenance_timestamp();
