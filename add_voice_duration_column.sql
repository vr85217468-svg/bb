-- إصلاح دعم الرسائل الصوتية في ask_me_messages

-- 1. إضافة عمود voice_duration إذا لم يكن موجوداً
ALTER TABLE ask_me_messages
ADD COLUMN IF NOT EXISTS voice_duration INTEGER DEFAULT 0;

-- 2. إزالة الـ constraint القديم على message_type
ALTER TABLE ask_me_messages 
DROP CONSTRAINT IF EXISTS ask_me_messages_message_type_check;

-- 3. إضافة constraint جديد يشمل 'text', 'image', 'voice'
ALTER TABLE ask_me_messages
ADD CONSTRAINT ask_me_messages_message_type_check 
CHECK (message_type IN ('text', 'image', 'voice'));

-- 4. إضافة تعليق توضيحي
COMMENT ON COLUMN ask_me_messages.voice_duration IS 'مدة الرسالة الصوتية بالثواني';
