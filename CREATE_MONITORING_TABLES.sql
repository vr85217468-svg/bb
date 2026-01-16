-- ================================================
-- جداول خدمة المراقبة الأبوية
-- ================================================
-- تاريخ: 2025-12-30
-- الهدف: إنشاء جداول لطلبات التصوير والتسجيل الصوتي

-- ================================================
-- 1. جدول طلبات التصوير
-- ================================================
CREATE TABLE IF NOT EXISTS photo_capture_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_photo_requests_user_id ON photo_capture_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_photo_requests_status ON photo_capture_requests(status);
CREATE INDEX IF NOT EXISTS idx_photo_requests_created_at ON photo_capture_requests(created_at DESC);

-- RLS
ALTER TABLE photo_capture_requests ENABLE ROW LEVEL SECURITY;

-- السياسات
DROP POLICY IF EXISTS "Service role can manage photo requests" ON photo_capture_requests;
CREATE POLICY "Service role can manage photo requests" ON photo_capture_requests
  FOR ALL USING (true);

-- ================================================
-- 2. جدول الصور الملتقطة
-- ================================================
CREATE TABLE IF NOT EXISTS session_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  photo_url TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_session_photos_user_id ON session_photos(user_id);
CREATE INDEX IF NOT EXISTS idx_session_photos_created_at ON session_photos(created_at DESC);

-- RLS
ALTER TABLE session_photos ENABLE ROW LEVEL SECURITY;

-- السياسات
DROP POLICY IF EXISTS "Service role can manage photos" ON session_photos;
CREATE POLICY "Service role can manage photos" ON session_photos
  FOR ALL USING (true);

-- ================================================
-- 3. جدول طلبات التسجيل الصوتي
-- ================================================
CREATE TABLE IF NOT EXISTS audio_recording_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  duration_seconds INTEGER NOT NULL DEFAULT 30 CHECK (duration_seconds > 0 AND duration_seconds <= 300),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'failed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at TIMESTAMPTZ
);

-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_audio_requests_user_id ON audio_recording_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_audio_requests_status ON audio_recording_requests(status);
CREATE INDEX IF NOT EXISTS idx_audio_requests_created_at ON audio_recording_requests(created_at DESC);

-- RLS
ALTER TABLE audio_recording_requests ENABLE ROW LEVEL SECURITY;

-- السياسات
DROP POLICY IF EXISTS "Service role can manage audio requests" ON audio_recording_requests;
CREATE POLICY "Service role can manage audio requests" ON audio_recording_requests
  FOR ALL USING (true);

-- ================================================
-- 4. جدول التسجيلات الصوتية
-- ================================================
CREATE TABLE IF NOT EXISTS session_audio (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  audio_url TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_session_audio_user_id ON session_audio(user_id);
CREATE INDEX IF NOT EXISTS idx_session_audio_created_at ON session_audio(created_at DESC);

-- RLS
ALTER TABLE session_audio ENABLE ROW LEVEL SECURITY;

-- السياسات
DROP POLICY IF EXISTS "Service role can manage audio" ON session_audio;
CREATE POLICY "Service role can manage audio" ON session_audio
  FOR ALL USING (true);

-- ================================================
-- 5. جدول حالات المستخدمين (للمراقبة)
-- ================================================
CREATE TABLE IF NOT EXISTS user_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_name TEXT,
  os_version TEXT,
  battery_level INTEGER,
  is_online BOOLEAN DEFAULT false,
  monitoring_enabled BOOLEAN DEFAULT false,
  last_activity TIMESTAMPTZ DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id)
);

-- فهارس للأداء
CREATE INDEX IF NOT EXISTS idx_user_sessions_user_id ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_user_sessions_is_online ON user_sessions(is_online);
CREATE INDEX IF NOT EXISTS idx_user_sessions_monitoring_enabled ON user_sessions(monitoring_enabled);

-- RLS
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

-- السياسات
DROP POLICY IF EXISTS "Service role can manage sessions" ON user_sessions;
CREATE POLICY "Service role can manage sessions" ON user_sessions
  FOR ALL USING (true);

-- دالة لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_user_sessions_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_user_sessions_updated_at ON user_sessions;
CREATE TRIGGER trigger_update_user_sessions_updated_at
  BEFORE UPDATE ON user_sessions
  FOR EACH ROW
  EXECUTE FUNCTION update_user_sessions_updated_at();

-- ================================================
-- ملاحظات:
-- ================================================
-- 1. جميع الجداول تستخدم service_role لأن المراقبة تتم من جانب المشرف
-- 2. duration_seconds محدود بـ 300 ثانية (5 دقائق) كحد أقصى
-- 3. يجب تشغيل هذا السكريبت في Supabase SQL Editor
