-- جدول رسائل الدعم (المحادثات الخاصة مع القائد/الأدمن)
CREATE TABLE IF NOT EXISTS support_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  message TEXT NOT NULL,
  message_type TEXT DEFAULT 'text' CHECK (message_type IN ('text', 'image', 'voice')),
  media_url TEXT,
  is_from_admin BOOLEAN DEFAULT FALSE,
  is_read BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- إنشاء الفهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_support_messages_user_id ON support_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_support_messages_created_at ON support_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_messages_is_read ON support_messages(is_read) WHERE is_read = FALSE;

-- تفعيل Row Level Security
ALTER TABLE support_messages ENABLE ROW LEVEL SECURITY;

-- السياسات الأمنية
-- المستخدمون يمكنهم قراءة رسائلهم فقط
CREATE POLICY "Users can view their own support messages"
  ON support_messages FOR SELECT
  USING (auth.uid() = user_id);

-- المستخدمون يمكنهم إرسال رسائل
CREATE POLICY "Users can insert their own support messages"
  ON support_messages FOR INSERT
  WITH CHECK (auth.uid() = user_id AND is_from_admin = FALSE);

-- الجميع يمكنهم قراءة جميع الرسائل (للأدمن - يتم التحكم من جانب التطبيق)
-- سنستخدم service_role key في التطبيق للأدمن
CREATE POLICY "Allow service role to view all"
  ON support_messages FOR SELECT
  USING (true);

-- السماح بإدخال رسائل من الأدمن
CREATE POLICY "Allow service role to insert"
  ON support_messages FOR INSERT
  WITH CHECK (true);

-- السماح بالتحديث من الأدمن
CREATE POLICY "Allow service role to update"
  ON support_messages FOR UPDATE
  USING (true);

-- جدول لتتبع آخر محادثة لكل مستخدم (لعرض قائمة المحادثات)
CREATE TABLE IF NOT EXISTS support_conversations (
  user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  unread_admin_count INTEGER DEFAULT 0,
  unread_user_count INTEGER DEFAULT 0,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- تفعيل RLS
ALTER TABLE support_conversations ENABLE ROW LEVEL SECURITY;

-- السياسات
CREATE POLICY "Users can view their own conversation"
  ON support_conversations FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Allow service role for conversations"
  ON support_conversations FOR ALL
  USING (true)
  WITH CHECK (true);

-- دالة لتحديث آخر رسالة في المحادثة
CREATE OR REPLACE FUNCTION update_support_conversation()
RETURNS TRIGGER AS $$
BEGIN
  -- إنشاء أو تحديث سجل المحادثة
  INSERT INTO support_conversations (user_id, last_message_at, unread_admin_count, unread_user_count)
  VALUES (
    NEW.user_id,
    NEW.created_at,
    CASE WHEN NEW.is_from_admin THEN 0 ELSE 1 END,
    CASE WHEN NEW.is_from_admin THEN 1 ELSE 0 END
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    last_message_at = NEW.created_at,
    unread_admin_count = CASE
      WHEN NEW.is_from_admin THEN support_conversations.unread_admin_count
      ELSE support_conversations.unread_admin_count + 1
    END,
    unread_user_count = CASE
      WHEN NEW.is_from_admin THEN support_conversations.unread_user_count + 1
      ELSE support_conversations.unread_user_count
    END,
    updated_at = NOW();

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ترجر لتحديث المحادثة عند إضافة رسالة جديدة
DROP TRIGGER IF EXISTS trigger_update_support_conversation ON support_messages;
CREATE TRIGGER trigger_update_support_conversation
  AFTER INSERT ON support_messages
  FOR EACH ROW
  EXECUTE FUNCTION update_support_conversation();

-- دالة لتمييز الرسائل كمقروءة
CREATE OR REPLACE FUNCTION mark_support_messages_as_read(p_user_id UUID, p_is_admin BOOLEAN)
RETURNS VOID AS $$
BEGIN
  -- تحديث الرسائل كمقروءة
  UPDATE support_messages
  SET is_read = TRUE
  WHERE user_id = p_user_id
    AND is_from_admin = (NOT p_is_admin)
    AND is_read = FALSE;

  -- تحديث عداد عدم القراءة
  IF p_is_admin THEN
    UPDATE support_conversations
    SET unread_admin_count = 0
    WHERE user_id = p_user_id;
  ELSE
    UPDATE support_conversations
    SET unread_user_count = 0
    WHERE user_id = p_user_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON TABLE support_messages IS 'رسائل الدعم الخاصة بين المستخدمين والقائد';
COMMENT ON TABLE support_conversations IS 'تتبع آخر محادثة لكل مستخدم مع القائد';
