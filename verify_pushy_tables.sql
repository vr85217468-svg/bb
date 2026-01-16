-- التحقق من وجود جميع جداول Pushy في قاعدة البيانات

-- 1. التحقق من جدول fcm_tokens
SELECT 
    'fcm_tokens' as table_name,
    EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'fcm_tokens'
    ) as exists;

-- 2. التحقق من جدول notification_history
SELECT 
    'notification_history' as table_name,
    EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'notification_history'
    ) as exists;

-- 3. التحقق من جدول user_notifications
SELECT 
    'user_notifications' as table_name,
    EXISTS (
        SELECT FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_name = 'user_notifications'
    ) as exists;

-- 4. عرض جميع device tokens المحفوظة
SELECT 
    'Saved Tokens' as info,
    COUNT(*) as total_tokens
FROM fcm_tokens;

-- 5. عرض آخر 5 tokens مسجلة
SELECT 
    user_id,
    LEFT(token, 30) || '...' as token_preview,
    platform,
    created_at
FROM fcm_tokens
ORDER BY created_at DESC
LIMIT 5;

-- 6. عرض سجل الإشعارات المرسلة
SELECT 
    'Notification History' as info,
    COUNT(*) as total_notifications
FROM notification_history;

-- 7. عرض آخر 5 إشعارات مرسلة
SELECT 
    title,
    body,
    recipient_count,
    created_at
FROM notification_history
ORDER BY created_at DESC
LIMIT 5;
