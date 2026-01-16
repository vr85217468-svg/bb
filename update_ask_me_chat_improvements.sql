-- =====================================================
-- تحسينات نظام الشات لـ "اسئلني"
-- =====================================================

-- 1. إضافة عمود مدة الصوت لجدول الرسائل (إذا لم يكن موجوداً)
ALTER TABLE ask_me_messages 
ADD COLUMN IF NOT EXISTS voice_duration INTEGER DEFAULT 0;

-- 2. إنشاء جدول مؤشر الكتابة
CREATE TABLE IF NOT EXISTS ask_me_typing (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID REFERENCES ask_me_conversations(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    is_typing BOOLEAN DEFAULT false,
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(conversation_id, user_id)
);

-- تمكين RLS
ALTER TABLE ask_me_typing ENABLE ROW LEVEL SECURITY;

-- سياسات الأمان لجدول الكتابة
CREATE POLICY "Users can view typing status in their conversations" 
ON ask_me_typing FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM ask_me_conversations 
        WHERE id = ask_me_typing.conversation_id 
        AND (user_id = auth.uid()::uuid OR expert_id = auth.uid()::uuid)
    )
);

CREATE POLICY "Users can update their typing status" 
ON ask_me_typing FOR INSERT 
WITH CHECK (user_id = auth.uid()::uuid);

CREATE POLICY "Users can modify their typing status" 
ON ask_me_typing FOR UPDATE 
USING (user_id = auth.uid()::uuid);

-- تمكين Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE ask_me_typing;

-- 3. إنشاء جدول ردود الفعل على الرسائل
CREATE TABLE IF NOT EXISTS ask_me_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES ask_me_messages(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    reaction VARCHAR(10) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(message_id, user_id)
);

-- تمكين RLS
ALTER TABLE ask_me_reactions ENABLE ROW LEVEL SECURITY;

-- سياسات الأمان لجدول ردود الفعل
CREATE POLICY "Users can view reactions in their conversations" 
ON ask_me_reactions FOR SELECT 
USING (
    EXISTS (
        SELECT 1 FROM ask_me_messages m
        JOIN ask_me_conversations c ON m.conversation_id = c.id
        WHERE m.id = ask_me_reactions.message_id 
        AND (c.user_id = auth.uid()::uuid OR c.expert_id = auth.uid()::uuid)
    )
);

CREATE POLICY "Users can add reactions to messages in their conversations" 
ON ask_me_reactions FOR INSERT 
WITH CHECK (
    user_id = auth.uid()::uuid AND
    EXISTS (
        SELECT 1 FROM ask_me_messages m
        JOIN ask_me_conversations c ON m.conversation_id = c.id
        WHERE m.id = ask_me_reactions.message_id 
        AND (c.user_id = auth.uid()::uuid OR c.expert_id = auth.uid()::uuid)
    )
);

CREATE POLICY "Users can remove their reactions" 
ON ask_me_reactions FOR DELETE 
USING (user_id = auth.uid()::uuid);

-- تمكين Realtime
ALTER PUBLICATION supabase_realtime ADD TABLE ask_me_reactions;

-- 4. إضافة أعمدة حالة الاتصال لجدول المستخدمين (إذا لم تكن موجودة)
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMPTZ;

-- 5. إنشاء فهارس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_ask_me_typing_conversation 
ON ask_me_typing(conversation_id);

CREATE INDEX IF NOT EXISTS idx_ask_me_reactions_message 
ON ask_me_reactions(message_id);

CREATE INDEX IF NOT EXISTS idx_ask_me_messages_type 
ON ask_me_messages(message_type);

-- 6. دالة لجلب الرسائل مع ردود الفعل
CREATE OR REPLACE FUNCTION get_message_with_reactions(p_message_id UUID)
RETURNS TABLE (
    message_id UUID,
    conversation_id UUID,
    sender_id UUID,
    message TEXT,
    message_type VARCHAR,
    voice_duration INTEGER,
    is_read BOOLEAN,
    created_at TIMESTAMPTZ,
    reactions JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id as message_id,
        m.conversation_id,
        m.sender_id,
        m.message,
        m.message_type,
        m.voice_duration,
        m.is_read,
        m.created_at,
        COALESCE(
            jsonb_agg(
                jsonb_build_object(
                    'user_id', r.user_id,
                    'reaction', r.reaction
                )
            ) FILTER (WHERE r.id IS NOT NULL),
            '[]'::jsonb
        ) as reactions
    FROM ask_me_messages m
    LEFT JOIN ask_me_reactions r ON m.id = r.message_id
    WHERE m.id = p_message_id
    GROUP BY m.id;
END;
$$;

-- 7. دالة لتنظيف حالات الكتابة القديمة (تشغيل دوري)
CREATE OR REPLACE FUNCTION cleanup_old_typing_status()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- إزالة حالات الكتابة الأقدم من 30 ثانية
    DELETE FROM ask_me_typing 
    WHERE updated_at < NOW() - INTERVAL '30 seconds';
END;
$$;

-- =====================================================
-- تم تثبيت التحسينات بنجاح! ✅
-- =====================================================
