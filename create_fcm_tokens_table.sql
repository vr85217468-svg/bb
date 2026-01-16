-- جدول لتخزين FCM tokens للأجهزة
CREATE TABLE IF NOT EXISTS fcm_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  device_info TEXT,
  platform TEXT, -- 'android', 'ios', 'web'
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(user_id, token)
);

-- فهرس للبحث السريع
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_user_id ON fcm_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_fcm_tokens_platform ON fcm_tokens(platform);

-- تفعيل Row Level Security
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- السياسات الأمنية
-- المستخدم يمكنه قراءة وتحديث tokens الخاصة به
CREATE POLICY "Users can manage their own tokens"
  ON fcm_tokens FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- السماح بالقراءة للجميع (للأدمن)
CREATE POLICY "Allow service role to read all tokens"
  ON fcm_tokens FOR SELECT
  USING (true);

-- دالة لتحديث أو إضافة token
CREATE OR REPLACE FUNCTION upsert_fcm_token(
  p_user_id UUID,
  p_token TEXT,
  p_device_info TEXT,
  p_platform TEXT
)
RETURNS void AS $$
BEGIN
  INSERT INTO fcm_tokens (user_id, token, device_info, platform)
  VALUES (p_user_id, p_token, p_device_info, p_platform)
  ON CONFLICT (user_id, token) DO UPDATE
  SET 
    device_info = EXCLUDED.device_info,
    platform = EXCLUDED.platform,
    updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- جدول لتخزين سجل الإشعارات المرسلة
CREATE TABLE IF NOT EXISTS notification_history (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  sent_by UUID REFERENCES users(id),
  recipient_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفعيل RLS
ALTER TABLE notification_history ENABLE ROW LEVEL SECURITY;

-- السماح للجميع بالقراءة
CREATE POLICY "Allow all to read notification history"
  ON notification_history FOR SELECT
  USING (true);

-- السماح بالإضافة للجميع (سيتم التحكم من التطبيق)
CREATE POLICY "Allow service role to insert"
  ON notification_history FOR INSERT
  WITH CHECK (true);

-- جدول لتخزين الإشعارات لكل مستخدم
CREATE TABLE IF NOT EXISTS user_notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  notification_id UUID REFERENCES notification_history(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الفهارس
CREATE INDEX IF NOT EXISTS idx_user_notifications_user_id ON user_notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_user_notifications_is_read ON user_notifications(is_read) WHERE is_read = FALSE;
CREATE INDEX IF NOT EXISTS idx_user_notifications_created_at ON user_notifications(created_at DESC);

-- تفعيل RLS
ALTER TABLE user_notifications ENABLE ROW LEVEL SECURITY;

-- المستخدم يقرأ إشعاراته فقط
CREATE POLICY "Users can read their own notifications"
  ON user_notifications FOR SELECT
  USING (auth.uid() = user_id);

-- المستخدم يمكنه تحديث حالة القراءة
CREATE POLICY "Users can update their notifications"
  ON user_notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- السماح للنظام بالإضافة
CREATE POLICY "Allow service role to insert user notifications"
  ON user_notifications FOR INSERT
  WITH CHECK (true);

COMMENT ON TABLE fcm_tokens IS 'رموز FCM للأجهزة لإرسال الإشعارات';
COMMENT ON TABLE notification_history IS 'سجل الإشعارات المرسلة';
COMMENT ON TABLE user_notifications IS 'الإشعارات المستلمة لكل مستخدم';
