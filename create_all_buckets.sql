-- ==========================================
-- SQL Function لإنشاء Bucket
-- (يتطلب صلاحيات Service Role)
-- ==========================================

-- إنشاء دالة لإنشاء bucket
CREATE OR REPLACE FUNCTION create_storage_bucket(
    bucket_name TEXT,
    is_public BOOLEAN DEFAULT true
)
RETURNS JSONB AS $$
DECLARE
    result JSONB;
BEGIN
    -- محاولة إنشاء البكت في جدول storage.buckets
    INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
    VALUES (
        bucket_name,
        bucket_name,
        is_public,
        52428800, -- 50MB
        ARRAY['image/jpeg', 'image/png', 'image/webp']
    )
    ON CONFLICT (id) DO NOTHING;
    
    -- التحقق من النجاح
    IF FOUND THEN
        result := jsonb_build_object(
            'success', true,
            'message', 'Bucket created: ' || bucket_name
        );
    ELSE
        result := jsonb_build_object(
            'success', false,
            'message', 'Bucket already exists: ' || bucket_name
        );
    END IF;
    
    RETURN result;
EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'success', false,
        'error', SQLERRM
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- منح الصلاحيات
GRANT EXECUTE ON FUNCTION create_storage_bucket TO authenticated;
GRANT EXECUTE ON FUNCTION create_storage_bucket TO anon;

-- ==========================================
-- تشغيل لإنشاء جميع الـ 30 Bucket
-- ==========================================

DO $$
DECLARE
    i INTEGER;
    bucket_name TEXT;
    result JSONB;
BEGIN
    FOR i IN 1..30 LOOP
        bucket_name := 'expert_chat_images_' || i;
        
        -- إنشاء البكت
        INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
        VALUES (
            bucket_name,
            bucket_name,
            true,
            52428800,
            ARRAY['image/jpeg', 'image/png', 'image/webp']
        )
        ON CONFLICT (id) DO NOTHING;
        
        IF FOUND THEN
            RAISE NOTICE '✅ Created: %', bucket_name;
        ELSE
            RAISE NOTICE 'ℹ️ Already exists: %', bucket_name;
        END IF;
    END LOOP;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ تم إنشاء/التحقق من جميع الـ 30 Bucket';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;

-- ==========================================
-- التحقق من Buckets المنشأة
-- ==========================================

SELECT 
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types,
    created_at
FROM storage.buckets
WHERE name LIKE 'expert_chat_images_%'
ORDER BY name;

-- عرض العدد الإجمالي
SELECT COUNT(*) as total_buckets
FROM storage.buckets
WHERE name LIKE 'expert_chat_images_%';
