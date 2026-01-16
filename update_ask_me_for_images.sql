-- ==========================================
-- تحديث جدول ask_me_messages لدعم الصور
-- ==========================================

-- 1. إضافة نوع الرسالة
ALTER TABLE ask_me_messages 
ADD COLUMN IF NOT EXISTS message_type TEXT DEFAULT 'text' 
CHECK (message_type IN ('text', 'image'));

-- 2. إنشاء فهرس مركّب للأداء الأمثل
CREATE INDEX IF NOT EXISTS idx_messages_conversation_type 
ON ask_me_messages(conversation_id, message_type, created_at DESC);

-- 3. تحديث البيانات الحالية لضمان التوافق
UPDATE ask_me_messages 
SET message_type = 'text' 
WHERE message_type IS NULL;

-- 4. إضافة قيد NOT NULL بعد التحديث
ALTER TABLE ask_me_messages 
ALTER COLUMN message_type SET NOT NULL;

-- 5. التعليقات التوضيحية
COMMENT ON COLUMN ask_me_messages.message_type IS 
'نوع الرسالة: text للنصوص، image للصور';

-- 6. إحصائيات للتحقق
SELECT 
    message_type,
    COUNT(*) as total_messages,
    COUNT(DISTINCT conversation_id) as conversations_count
FROM ask_me_messages
GROUP BY message_type;

-- ==========================================
-- تأكيد النجاح
-- ==========================================

DO $$
BEGIN
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ تم تحديث جدول ask_me_messages بنجاح';
    RAISE NOTICE '   - إضافة عمود message_type';
    RAISE NOTICE '   - إنشاء فهرس للأداء';
    RAISE NOTICE '   - تحديث البيانات الحالية';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
