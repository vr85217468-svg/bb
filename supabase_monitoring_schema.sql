-- ============================================
-- نظام المراقبة الأبوية - Parental Monitoring System
-- قاعدة البيانات الكاملة
-- ============================================

-- ============================================
-- 1. جدول رموز المراقبة الأبوية
-- ============================================
CREATE TABLE IF NOT EXISTS parental_codes (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code VARCHAR(10) UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- إدراج الرمز الافتراضي
INSERT INTO parental_codes (code) VALUES ('123')
ON CONFLICT (code) DO NOTHING;

-- ============================================
-- 2. جدول جلسات المستخدمين
-- ============================================
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE UNIQUE NOT NULL,
  is_online BOOLEAN DEFAULT false,
  device_name TEXT,
  os_version TEXT,
  battery_level INT CHECK (battery_level >= 0 AND battery_level <= 100),
  monitoring_enabled BOOLEAN DEFAULT false,
  last_seen TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_user_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_monitoring ON user_sessions(monitoring_enabled);

-- ============================================
-- 3. جدول صور الجلسات
-- ============================================
CREATE TABLE IF NOT EXISTS session_photos (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  photo_url TEXT NOT NULL,
  screen_name TEXT DEFAULT 'qibla',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_session_photos_user ON session_photos(user_id, created_at DESC);

-- ============================================
-- 4. جدول التسجيلات الصوتية
-- ============================================
CREATE TABLE IF NOT EXISTS session_audio (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  audio_url TEXT NOT NULL,
  duration_seconds INT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_session_audio_user ON session_audio(user_id, created_at DESC);

-- ============================================
-- 5. جدول طلبات التقاط الصور
-- ============================================
CREATE TABLE IF NOT EXISTS photo_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_photo_requests_user ON photo_requests(user_id, status);

-- ============================================
-- 6. جدول طلبات التسجيل الصوتي
-- ============================================
CREATE TABLE IF NOT EXISTS audio_requests (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID REFERENCES users(id) ON DELETE CASCADE NOT NULL,
  duration_seconds INT DEFAULT 30 CHECK (duration_seconds >= 5 AND duration_seconds <= 120),
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- Index للبحث السريع
CREATE INDEX IF NOT EXISTS idx_audio_requests_user ON audio_requests(user_id, status);

-- ============================================
-- 7. تعطيل RLS لجميع الجداول (للاختبار)
-- ============================================
ALTER TABLE parental_codes DISABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions DISABLE ROW LEVEL SECURITY;
ALTER TABLE session_photos DISABLE ROW LEVEL SECURITY;
ALTER TABLE session_audio DISABLE ROW LEVEL SECURITY;
ALTER TABLE photo_requests DISABLE ROW LEVEL SECURITY;
ALTER TABLE audio_requests DISABLE ROW LEVEL SECURITY;

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

-- Trigger للتحديث التلقائي
DROP TRIGGER IF EXISTS user_sessions_updated_at ON user_sessions;
CREATE TRIGGER user_sessions_updated_at
BEFORE UPDATE ON user_sessions
FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ============================================
-- تم! ✅
-- ============================================
-- الآن قم بتنفيذ هذا الكود في Supabase SQL Editor
