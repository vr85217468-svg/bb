-- ================================================
-- اختبار نظام الإشعارات - Diagnostic Script
-- ================================================
-- تاريخ: 2025-12-31
-- الهدف: التحقق من أن جميع الجداول موجودة وجاهزة

-- ================================================
-- 1. التحقق من وجود جدول user_notifications
-- ================================================
SELECT 
  table_name,
  table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('user_notifications', 'notification_history', 'user_sessions');

-- ================================================
-- 2. التحقق من RLS policies
-- ================================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE tablename = 'user_notifications';

-- ================================================
-- 3. اختبار إدخال إشعار تجريبي
-- ================================================
-- ⚠️ استبدل 'YOUR_USER_ID' بـ user_id حقيقي من جدول users
-- للحصول على user_id: SELECT id, name FROM users LIMIT 5;

-- إدراج إشعار تجريبي (قم بتغيير USER_ID)
INSERT INTO user_notifications (user_id, title, body, is_read)
VALUES 
  ('YOUR_USER_ID_HERE', 'إشعار تجريبي', 'هذا إشعار للاختبار', false);

-- التحقق من الإدراج
SELECT 
  id,
  user_id,
  title,
  body,
  is_read,
  created_at
FROM user_notifications
WHERE user_id = 'YOUR_USER_ID_HERE'
ORDER BY created_at DESC
LIMIT 5;

-- ================================================
-- 4. التحقق من Realtime
-- ================================================
-- للتحقق من Realtime، افتح Supabase Dashboard → Database → Replication
-- تأكد من أن جدول user_notifications مُفعّل في Realtime
