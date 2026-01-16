-- ========================================
-- إصلاح Row Level Security لنظام اسئلني
-- ========================================
-- المشكلة: التطبيق لا يستخدم Supabase Auth، بل جدول users مباشرة
-- الحل: تعطيل RLS مؤقتاً حتى يتم تطبيق نظام Auth صحيح
-- أو: استخدام سياسات أكثر تساهلاً

-- ==================== الخيار 1: تعطيل RLS (أسهل وأسرع) ====================

-- تعطيل RLS على جميع الجداول
ALTER TABLE ask_me_experts DISABLE ROW LEVEL SECURITY;
ALTER TABLE ask_me_conversations DISABLE ROW LEVEL SECURITY;
ALTER TABLE ask_me_messages DISABLE ROW LEVEL SECURITY;

-- ==================== الخيار 2: سياسات مفتوحة (إذا كنت تريد RLS) ====================
-- يمكنك استخدام هذا بدلاً من تعطيل RLS

/*
-- حذف السياسات القديمة
DROP POLICY IF EXISTS "Anyone can view active experts" ON ask_me_experts;
DROP POLICY IF EXISTS "Allow all operations on experts" ON ask_me_experts;
DROP POLICY IF EXISTS "Users can view their conversations" ON ask_me_conversations;
DROP POLICY IF EXISTS "Users can create conversations" ON ask_me_conversations;
DROP POLICY IF EXISTS "Users can update their conversations" ON ask_me_conversations;
DROP POLICY IF EXISTS "Users can view messages in their conversations" ON ask_me_messages;
DROP POLICY IF EXISTS "Users can send messages" ON ask_me_messages;
DROP POLICY IF EXISTS "Users can update messages" ON ask_me_messages;

-- سياسات جديدة مفتوحة للجميع (مؤقتاً)
CREATE POLICY "Allow all on experts" ON ask_me_experts FOR ALL USING (true);
CREATE POLICY "Allow all on conversations" ON ask_me_conversations FOR ALL USING (true);
CREATE POLICY "Allow all on messages" ON ask_me_messages FOR ALL USING (true);
*/

-- ==================== ملاحظات مهمة ====================
-- 1. الخيار 1 (تعطيل RLS) هو الأفضل حالياً لأن التطبيق لا يستخدم Supabase Auth
-- 2. إذا أردت أماناً أفضل في المستقبل، يجب تطبيق Supabase Auth بشكل صحيح
-- 3. يمكنك التحكم بالصلاحيات من الكود (middleware) بدلاً من RLS
