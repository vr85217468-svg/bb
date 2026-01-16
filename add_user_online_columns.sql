-- ================================================
-- إضافة أعمدة حالة الاتصال لجدول المستخدمين
-- Add online status columns to users table
-- ================================================

-- 1. إضافة عمود is_online إذا لم يكن موجوداً
ALTER TABLE users ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT false;

-- 2. إضافة عمود last_seen إذا لم يكن موجوداً
ALTER TABLE users ADD COLUMN IF NOT EXISTS last_seen TIMESTAMP WITH TIME ZONE;

-- 3. إنشاء فهرس لتحسين الأداء عند البحث عن المستخدمين المتصلين
CREATE INDEX IF NOT EXISTS idx_users_is_online ON users(is_online);

-- 4. تحديث جميع المستخدمين ليكونوا غير متصلين افتراضياً
UPDATE users SET is_online = false WHERE is_online IS NULL;

-- 5. ملاحظة: بعد تشغيل هذا الكود، يجب إعادة تشغيل التطبيق
SELECT 'تم إضافة أعمدة حالة الاتصال بنجاح!' as message;
