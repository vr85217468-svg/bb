-- ==========================================
-- سكريبت لإنشاء 30 Bucket تلقائياً
-- تشغيل عبر Supabase Management API
-- ==========================================

-- ملاحظة: هذا السكريبت يجب تنفيذه من خارج SQL Editor
-- استخدم Supabase CLI أو API مباشرة

-- البديل: استخدام كود Dart في التطبيق (لمرة واحدة فقط)

-- ==========================================
-- طريقة 1: باستخدام cURL
-- ==========================================

-- احصل على Service Role Key من Settings > API
-- استبدل YOUR_PROJECT_URL و YOUR_SERVICE_ROLE_KEY

/*
for i in {1..30}
do
  curl -X POST 'https://YOUR_PROJECT_URL.supabase.co/storage/v1/bucket' \
    -H "apikey: YOUR_SERVICE_ROLE_KEY" \
    -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
    -H "Content-Type: application/json" \
    -d "{
      \"id\": \"expert_chat_images_$i\",
      \"name\": \"expert_chat_images_$i\",
      \"public\": true,
      \"file_size_limit\": 52428800,
      \"allowed_mime_types\": [\"image/jpeg\", \"image/png\", \"image/webp\"]
    }"
done
*/

-- ==========================================
-- طريقة 2: SQL Function لإنشاء Bucket (محدودة)
-- ==========================================

-- لسوء الحظ، Supabase لا تسمح بإنشاء Buckets من SQL مباشرة
-- يجب استخدام Management API

-- ==========================================
-- طريقة 3: من Flutter (Initialization Script)
-- ==========================================

-- راجع ملف create_buckets_script.dart المرفق

-- ==========================================
-- التحقق من Buckets الموجودة
-- ==========================================

-- بعد الإنشاء، تحقق من عدد الـ Buckets:
SELECT 
    schemaname,
    tablename,
    COUNT(*) as bucket_count
FROM pg_tables
WHERE schemaname = 'storage'
  AND tablename = 'buckets';

-- أو من واجهة SQL:
SELECT name, public, file_size_limit
FROM storage.buckets
WHERE name LIKE 'expert_chat_images_%'
ORDER BY name;
