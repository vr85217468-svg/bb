-- ========================================
-- نظام اسئلني الاحترافي - قاعدة البيانات
-- ========================================

-- الجدول 1: المجيبين/المستشارين
CREATE TABLE IF NOT EXISTS ask_me_experts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    display_name TEXT NOT NULL,
    bio TEXT,
    specialization TEXT DEFAULT 'عام',
    profile_image TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    order_index INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id)
);

-- الجدول 2: المحادثات
CREATE TABLE IF NOT EXISTS ask_me_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    expert_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_message TEXT,
    last_message_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    unread_count_user INTEGER DEFAULT 0,
    unread_count_expert INTEGER DEFAULT 0,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'closed', 'archived')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- الجدول 3: الرسائل
CREATE TABLE IF NOT EXISTS ask_me_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES ask_me_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- الفهارس لتحسين الأداء
-- ========================================

-- فهارس للمجيبين
CREATE INDEX IF NOT EXISTS idx_experts_user_id ON ask_me_experts(user_id);
CREATE INDEX IF NOT EXISTS idx_experts_active ON ask_me_experts(is_active);
CREATE INDEX IF NOT EXISTS idx_experts_order ON ask_me_experts(order_index);

-- فهارس للمحادثات
CREATE INDEX IF NOT EXISTS idx_conversations_user ON ask_me_conversations(user_id);
CREATE INDEX IF NOT EXISTS idx_conversations_expert ON ask_me_conversations(expert_id);
CREATE INDEX IF NOT EXISTS idx_conversations_status ON ask_me_conversations(status);
CREATE INDEX IF NOT EXISTS idx_conversations_last_message ON ask_me_conversations(last_message_at DESC);

-- فهارس للرسائل
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON ask_me_messages(conversation_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON ask_me_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_created ON ask_me_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_messages_unread ON ask_me_messages(conversation_id, is_read);

-- ========================================
-- Triggers للتحديث التلقائي
-- ========================================

-- تحديث updated_at للمجيبين
CREATE OR REPLACE FUNCTION update_ask_me_experts_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER experts_updated_at
    BEFORE UPDATE ON ask_me_experts
    FOR EACH ROW
    EXECUTE FUNCTION update_ask_me_experts_updated_at();

-- تحديث آخر رسالة في المحادثة
CREATE OR REPLACE FUNCTION update_conversation_last_message()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE ask_me_conversations
    SET 
        last_message = NEW.message,
        last_message_at = NEW.created_at,
        updated_at = NOW(),
        -- زيادة عداد الرسائل غير المقروءة
        unread_count_user = CASE 
            WHEN NEW.sender_id != user_id THEN unread_count_user + 1
            ELSE unread_count_user
        END,
        unread_count_expert = CASE 
            WHEN NEW.sender_id != expert_id THEN unread_count_expert + 1
            ELSE unread_count_expert
        END
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER messages_update_conversation
    AFTER INSERT ON ask_me_messages
    FOR EACH ROW
    EXECUTE FUNCTION update_conversation_last_message();

-- ========================================
-- Row Level Security (RLS)
-- ========================================

-- تفعيل RLS على الجداول
ALTER TABLE ask_me_experts ENABLE ROW LEVEL SECURITY;
ALTER TABLE ask_me_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ask_me_messages ENABLE ROW LEVEL SECURITY;

-- ==================== المجيبين ====================

-- الجميع يمكنهم قراءة المجيبين النشطين
CREATE POLICY "Anyone can view active experts"
    ON ask_me_experts
    FOR SELECT
    USING (is_active = true);

-- الجميع يمكنهم إدارة المجيبين (سيتم التحكم من الكود)
CREATE POLICY "Allow all operations on experts"
    ON ask_me_experts
    FOR ALL
    USING (true);

-- ==================== المحادثات ====================

-- المستخدمون يمكنهم رؤية محادثاتهم فقط
CREATE POLICY "Users can view their conversations"
    ON ask_me_conversations
    FOR SELECT
    USING (
        auth.uid() IN (user_id, expert_id)
        OR user_id IN (SELECT id FROM users WHERE id = auth.uid())
        OR expert_id IN (SELECT id FROM users WHERE id = auth.uid())
    );

-- المستخدمون يمكنهم إنشاء محادثات
CREATE POLICY "Users can create conversations"
    ON ask_me_conversations
    FOR INSERT
    WITH CHECK (true);

-- المستخدمون يمكنهم تحديث محادثاتهم
CREATE POLICY "Users can update their conversations"
    ON ask_me_conversations
    FOR UPDATE
    USING (
        auth.uid() IN (user_id, expert_id)
        OR user_id IN (SELECT id FROM users WHERE id = auth.uid())
        OR expert_id IN (SELECT id FROM users WHERE id = auth.uid())
    );

-- ==================== الرسائل ====================

-- المستخدمون يمكنهم رؤية رسائل محادثاتهم فقط
CREATE POLICY "Users can view messages in their conversations"
    ON ask_me_messages
    FOR SELECT
    USING (
        conversation_id IN (
            SELECT id FROM ask_me_conversations
            WHERE user_id IN (SELECT id FROM users WHERE id = auth.uid())
               OR expert_id IN (SELECT id FROM users WHERE id = auth.uid())
        )
    );

-- المستخدمون يمكنهم إرسال رسائل
CREATE POLICY "Users can send messages"
    ON ask_me_messages
    FOR INSERT
    WITH CHECK (true);

-- المستخدمون يمكنهم تحديث رسائلهم (للقراءة)
CREATE POLICY "Users can update messages"
    ON ask_me_messages
    FOR UPDATE
    USING (
        conversation_id IN (
            SELECT id FROM ask_me_conversations
            WHERE user_id IN (SELECT id FROM users WHERE id = auth.uid())
               OR expert_id IN (SELECT id FROM users WHERE id = auth.uid())
        )
    );

-- ========================================
-- بيانات تجريبية (اختياري)
-- ========================================

-- يمكنك إضافة بيانات تجريبية هنا إذا أردت

COMMENT ON TABLE ask_me_experts IS 'جدول المستشارين/المجيبين المعينين من قبل الأدمن';
COMMENT ON TABLE ask_me_conversations IS 'جدول المحادثات بين المستخدمين والمستشارين';
COMMENT ON TABLE ask_me_messages IS 'جدول الرسائل داخل المحادثات';
