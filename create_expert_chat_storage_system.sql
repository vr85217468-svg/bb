-- ==========================================
-- نظام تخزين متعدد لصور محادثات المستشارين
-- 30 Bucket منفصل مع تبديل تلقائي
-- ==========================================

-- ========================================
-- 1. جدول تتبع Buckets
-- ========================================

CREATE TABLE IF NOT EXISTS expert_chat_storage_buckets (
    id SERIAL PRIMARY KEY,
    bucket_name TEXT UNIQUE NOT NULL,
    bucket_number INTEGER UNIQUE NOT NULL,
    total_size_bytes BIGINT DEFAULT 0,
    total_files INTEGER DEFAULT 0,
    max_size_bytes BIGINT DEFAULT 943718400, -- 900MB (تحويل: 900 * 1024 * 1024)
    is_active BOOLEAN DEFAULT FALSE,
    is_full BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- 2. جدول إشعارات الأدمن
-- ========================================

CREATE TABLE IF NOT EXISTS admin_notifications (
    id SERIAL PRIMARY KEY,
    type TEXT NOT NULL,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT FALSE,
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- 3. إضافة 30 Bucket للتتبع
-- ========================================

DO $$
BEGIN
    FOR i IN 1..30 LOOP
        INSERT INTO expert_chat_storage_buckets (bucket_name, bucket_number, is_active)
        VALUES (
            'expert_chat_images_' || i,
            i,
            CASE WHEN i = 1 THEN TRUE ELSE FALSE END
        )
        ON CONFLICT (bucket_name) DO NOTHING;
    END LOOP;
    
    RAISE NOTICE '✅ تم إنشاء 30 bucket للتتبع';
END $$;

-- ========================================
-- 4. الفهارس لتحسين الأداء
-- ========================================

CREATE INDEX IF NOT EXISTS idx_expert_buckets_active 
    ON expert_chat_storage_buckets(is_active) WHERE is_active = TRUE;

CREATE INDEX IF NOT EXISTS idx_expert_buckets_number 
    ON expert_chat_storage_buckets(bucket_number);

CREATE INDEX IF NOT EXISTS idx_expert_buckets_full 
    ON expert_chat_storage_buckets(is_full);

CREATE INDEX IF NOT EXISTS idx_admin_notifications_unread 
    ON admin_notifications(is_read, created_at DESC) WHERE is_read = FALSE;

CREATE INDEX IF NOT EXISTS idx_admin_notifications_type 
    ON admin_notifications(type, created_at DESC);

-- ========================================
-- 5. دالة: زيادة استخدام Bucket
-- ========================================

CREATE OR REPLACE FUNCTION increment_expert_bucket_usage(
    bucket_name_param TEXT,
    file_size_bytes BIGINT
)
RETURNS void AS $$
DECLARE
    new_total_size BIGINT;
    bucket_max_size BIGINT;
BEGIN
    -- تحديث الإحصائيات
    UPDATE expert_chat_storage_buckets
    SET 
        total_size_bytes = total_size_bytes + file_size_bytes,
        total_files = total_files + 1,
        updated_at = NOW()
    WHERE bucket_name = bucket_name_param
    RETURNING total_size_bytes, max_size_bytes INTO new_total_size, bucket_max_size;
    
    -- التحقق إذا أصبح ممتلئاً
    IF new_total_size >= bucket_max_size THEN
        UPDATE expert_chat_storage_buckets
        SET is_full = TRUE
        WHERE bucket_name = bucket_name_param;
        
        RAISE NOTICE '⚠️ Bucket % is now full (%/%)', bucket_name_param, new_total_size, bucket_max_size;
    END IF;
    
    RAISE NOTICE '📊 Bucket % updated: +% bytes (Total: % bytes)', 
        bucket_name_param, file_size_bytes, new_total_size;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 6. دالة: الحصول على البكت النشط
-- ========================================

CREATE OR REPLACE FUNCTION get_active_expert_bucket()
RETURNS TEXT AS $$
DECLARE
    active_bucket TEXT;
BEGIN
    SELECT bucket_name INTO active_bucket
    FROM expert_chat_storage_buckets
    WHERE is_active = TRUE
    LIMIT 1;
    
    -- إذا لم يوجد bucket نشط، نفعل الأول
    IF active_bucket IS NULL THEN
        UPDATE expert_chat_storage_buckets
        SET is_active = TRUE
        WHERE bucket_number = 1;
        
        active_bucket := 'expert_chat_images_1';
        
        RAISE NOTICE '⚠️ لم يوجد bucket نشط، تم تفعيل expert_chat_images_1';
    END IF;
    
    RETURN active_bucket;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 7. دالة: الانتقال للبكت التالي
-- ========================================

CREATE OR REPLACE FUNCTION switch_to_next_expert_bucket()
RETURNS TABLE(
    success BOOLEAN,
    new_bucket_name TEXT,
    old_bucket_name TEXT,
    message TEXT
) AS $$
DECLARE
    current_bucket_num INTEGER;
    current_bucket_name TEXT;
    next_bucket_num INTEGER;
    next_bucket_name TEXT;
BEGIN
    -- الحصول على البكت الحالي
    SELECT bucket_number, bucket_name INTO current_bucket_num, current_bucket_name
    FROM expert_chat_storage_buckets
    WHERE is_active = TRUE
    LIMIT 1;
    
    -- إذا لم يوجد bucket نشط
    IF current_bucket_num IS NULL THEN
        RETURN QUERY SELECT 
            FALSE, 
            'expert_chat_images_1'::TEXT, 
            NULL::TEXT,
            'لم يوجد bucket نشط'::TEXT;
        RETURN;
    END IF;
    
    -- تعطيل البكت الحالي وتحديده كممتلئ
    UPDATE expert_chat_storage_buckets
    SET 
        is_active = FALSE, 
        is_full = TRUE,
        updated_at = NOW()
    WHERE bucket_number = current_bucket_num;
    
    -- الانتقال للبكت التالي
    next_bucket_num := current_bucket_num + 1;
    
    -- التحقق من عدم تجاوز الحد الأقصى
    IF next_bucket_num > 30 THEN
        -- إنشاء إشعار عاجل للأدمن
        INSERT INTO admin_notifications (type, message, metadata)
        VALUES (
            'storage_critical',
            '🔴 تحذير عاجل: جميع مساحات التخزين (30/30) ممتلئة!',
            jsonb_build_object(
                'severity', 'critical',
                'last_bucket', current_bucket_name,
                'action_required', 'add_more_buckets_or_cleanup'
            )
        );
        
        RETURN QUERY SELECT 
            FALSE, 
            NULL::TEXT, 
            current_bucket_name,
            'جميع الـ 30 bucket ممتلئة! يرجى الاتصال بالدعم الفني'::TEXT;
        RETURN;
    END IF;
    
    next_bucket_name := 'expert_chat_images_' || next_bucket_num;
    
    -- تفعيل البكت الجديد
    UPDATE expert_chat_storage_buckets
    SET 
        is_active = TRUE,
        updated_at = NOW()
    WHERE bucket_number = next_bucket_num;
    
    -- إنشاء إشعار للأدمن
    INSERT INTO admin_notifications (type, message, metadata)
    VALUES (
        'storage_bucket_switch',
        format('تم الانتقال تلقائياً من %s إلى %s', current_bucket_name, next_bucket_name),
        jsonb_build_object(
            'old_bucket', current_bucket_name,
            'old_bucket_number', current_bucket_num,
            'new_bucket', next_bucket_name,
            'new_bucket_number', next_bucket_num,
            'total_buckets_used', next_bucket_num,
            'remaining_buckets', 30 - next_bucket_num
        )
    );
    
    RAISE NOTICE '✅ تم الانتقال من % إلى %', current_bucket_name, next_bucket_name;
    
    RETURN QUERY SELECT 
        TRUE, 
        next_bucket_name, 
        current_bucket_name,
        format('تم الانتقال بنجاح إلى %s', next_bucket_name)::TEXT;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 8. دالة: التحقق والانتقال التلقائي إذا لزم
-- ========================================

CREATE OR REPLACE FUNCTION check_and_switch_bucket_if_needed()
RETURNS TEXT AS $$
DECLARE
    current_bucket TEXT;
    bucket_info RECORD;
    switch_result RECORD;
BEGIN
    -- الحصول على البكت النشط
    current_bucket := get_active_expert_bucket();
    
    -- جلب معلومات البكت
    SELECT 
        total_size_bytes,
        max_size_bytes,
        is_full,
        (total_size_bytes::DECIMAL / max_size_bytes * 100) as usage_percent
    INTO bucket_info
    FROM expert_chat_storage_buckets
    WHERE bucket_name = current_bucket;
    
    -- إذا كان ممتلئاً أو قارب على الامتلاء (>= 95%)
    IF bucket_info.is_full OR bucket_info.usage_percent >= 95 THEN
        RAISE NOTICE '⚠️ Bucket % is full or nearly full (%.2f%%), switching...', 
            current_bucket, bucket_info.usage_percent;
        
        -- الانتقال للبكت التالي
        SELECT * INTO switch_result FROM switch_to_next_expert_bucket();
        
        IF switch_result.success THEN
            RETURN switch_result.new_bucket_name;
        ELSE
            -- إذا فشل التبديل (كل البكتات ممتلئة)
            RAISE EXCEPTION '%', switch_result.message;
        END IF;
    END IF;
    
    RETURN current_bucket;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 9. Trigger: تحديث updated_at تلقائياً
-- ========================================

CREATE OR REPLACE FUNCTION update_expert_bucket_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS expert_buckets_updated_at ON expert_chat_storage_buckets;

CREATE TRIGGER expert_buckets_updated_at
    BEFORE UPDATE ON expert_chat_storage_buckets
    FOR EACH ROW
    EXECUTE FUNCTION update_expert_bucket_timestamp();

-- ========================================
-- 10. View: ملخص إحصائيات Buckets
-- ========================================

CREATE OR REPLACE VIEW expert_buckets_summary AS
SELECT 
    bucket_number,
    bucket_name,
    ROUND((total_size_bytes::NUMERIC / (1024*1024))::NUMERIC, 2) as size_mb,
    ROUND((max_size_bytes::NUMERIC / (1024*1024))::NUMERIC, 2) as max_size_mb,
    ROUND((total_size_bytes::NUMERIC / NULLIF(max_size_bytes, 0)::NUMERIC * 100)::NUMERIC, 2) as usage_percent,
    total_files,
    is_active,
    is_full,
    created_at,
    updated_at
FROM expert_chat_storage_buckets
ORDER BY bucket_number;

-- ========================================
-- 11. View: إحصائيات عامة
-- ========================================

CREATE OR REPLACE VIEW expert_storage_stats AS
SELECT 
    COUNT(*) as total_buckets,
    COUNT(*) FILTER (WHERE is_active) as active_buckets,
    COUNT(*) FILTER (WHERE is_full) as full_buckets,
    COUNT(*) FILTER (WHERE NOT is_full AND NOT is_active) as available_buckets,
    SUM(total_size_bytes) as total_size_bytes,
    ROUND((SUM(total_size_bytes)::NUMERIC / (1024*1024*1024))::NUMERIC, 2) as total_size_gb,
    SUM(total_files) as total_files,
    ROUND((SUM(total_size_bytes)::NUMERIC / SUM(max_size_bytes)::NUMERIC * 100)::NUMERIC, 2) as overall_usage_percent
FROM expert_chat_storage_buckets;

-- ========================================
-- 12. RLS Policies
-- ========================================

ALTER TABLE expert_chat_storage_buckets ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_notifications ENABLE ROW LEVEL SECURITY;

-- السماح بجميع العمليات (التحكم من الكود)
DROP POLICY IF EXISTS "Allow all operations on expert buckets" ON expert_chat_storage_buckets;
CREATE POLICY "Allow all operations on expert buckets"
    ON expert_chat_storage_buckets
    FOR ALL
    USING (true)
    WITH CHECK (true);

DROP POLICY IF EXISTS "Allow all operations on admin notifications" ON admin_notifications;
CREATE POLICY "Allow all operations on admin notifications"
    ON admin_notifications
    FOR ALL
    USING (true)
    WITH CHECK (true);

-- ========================================
-- 13. التعليقات التوضيحية
-- ========================================

COMMENT ON TABLE expert_chat_storage_buckets IS 
    'تتبع استخدام 30 bucket لتخزين صور محادثات المستشارين مع تبديل تلقائي';

COMMENT ON TABLE admin_notifications IS 
    'إشعارات للأدمن بشأن أحداث مهمة مثل تبديل الـ buckets';

COMMENT ON FUNCTION increment_expert_bucket_usage IS 
    'زيادة استخدام bucket معين بحجم ملف مرفوع';

COMMENT ON FUNCTION get_active_expert_bucket IS 
    'الحصول على اسم البكت النشط حالياً';

COMMENT ON FUNCTION switch_to_next_expert_bucket IS 
    'الانتقال تلقائياً للبكت التالي عند امتلاء الحالي';

COMMENT ON FUNCTION check_and_switch_bucket_if_needed IS 
    'التحقق من سعة البكت والانتقال التلقائي إذا كان ممتلئاً';

COMMENT ON VIEW expert_buckets_summary IS 
    'عرض ملخص لجميع الـ buckets مع الإحصائيات';

COMMENT ON VIEW expert_storage_stats IS 
    'إحصائيات عامة عن نظام التخزين';

-- ========================================
-- 14. بيانات اختبارية (اختياري)
-- ========================================

-- إضافة إشعار ترحيبي
INSERT INTO admin_notifications (type, message, metadata)
VALUES (
    'system_info',
    '✅ تم تفعيل نظام التخزين المتعدد لصور محادثات المستشارين (30 bucket)',
    jsonb_build_object(
        'total_capacity_gb', 27,
        'bucket_count', 30,
        'active_bucket', 'expert_chat_images_1'
    )
);

-- ========================================
-- 15. عرض ملخص النظام
-- ========================================

DO $$
DECLARE
    stats RECORD;
BEGIN
    SELECT * INTO stats FROM expert_storage_stats;
    
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '✅ نظام التخزين المتعدد جاهز!';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '📦 إجمالي Buckets: %', stats.total_buckets;
    RAISE NOTICE '✅ Buckets نشطة: %', stats.active_buckets;
    RAISE NOTICE '🔴 Buckets ممتلئة: %', stats.full_buckets;
    RAISE NOTICE '⚪ Buckets متاحة: %', stats.available_buckets;
    RAISE NOTICE '📊 إجمالي الحجم: % GB', stats.total_size_gb;
    RAISE NOTICE '📁 إجمالي الملفات: %', stats.total_files;
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️ تذكير: يجب إنشاء 30 bucket يدوياً في Supabase Dashboard:';
    RAISE NOTICE '   expert_chat_images_1 إلى expert_chat_images_30';
    RAISE NOTICE '   (كل bucket يجب أن يكون Public)';
    RAISE NOTICE '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━';
END $$;
