-- ====================================================
-- نظام تتبع حالة اتصال المستشارين الذكي
-- ====================================================

-- 1. إضافة أعمدة تتبع الاتصال
ALTER TABLE ask_me_experts 
ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

ALTER TABLE ask_me_experts 
ADD COLUMN IF NOT EXISTS last_seen_at TIMESTAMPTZ DEFAULT NOW();

-- 2. إنشاء دالة لتحديث حالة الاتصال
CREATE OR REPLACE FUNCTION update_expert_online_status(
  expert_user_id UUID,
  online_status BOOLEAN
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE ask_me_experts 
  SET 
    is_online = online_status,
    last_seen_at = NOW()
  WHERE user_id = expert_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. إنشاء دالة للتحقق من المستشارين غير النشطين (أكثر من 5 دقائق)
CREATE OR REPLACE FUNCTION cleanup_inactive_experts()
RETURNS void AS $$
BEGIN
  UPDATE ask_me_experts 
  SET is_online = false 
  WHERE is_online = true 
    AND last_seen_at < NOW() - INTERVAL '5 minutes';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. إنشاء Cron Job لتنظيف المستشارين غير النشطين (كل دقيقة)
-- ملاحظة: يتطلب تفعيل pg_cron في Supabase
-- SELECT cron.schedule('cleanup_inactive_experts', '* * * * *', 'SELECT cleanup_inactive_experts()');

-- 5. دالة heartbeat - ينادى كل دقيقة من التطبيق
CREATE OR REPLACE FUNCTION expert_heartbeat(expert_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE ask_me_experts 
  SET 
    is_online = true,
    last_seen_at = NOW()
  WHERE user_id = expert_user_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. إعادة تعيين الجميع كـ "غير متصل" (تنظيف)
UPDATE ask_me_experts SET is_online = false;

-- 7. منح الصلاحيات
GRANT EXECUTE ON FUNCTION update_expert_online_status(UUID, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION expert_heartbeat(UUID) TO authenticated;
