-- ================================================
-- كود تجريبي لإنشاء قبيلة نظامية وفحص البيانات
-- ================================================

-- 1. محاولة إضافة قبيلة نظامية (إذا لم تكن موجودة)
-- سنستخدم ID عشوائي للقائد (أو أول مستخدم موجود)
DO $$ 
DECLARE
    first_user_id UUID;
    tribe_id UUID;
BEGIN 
    -- جلب أول مستخدم موجود في النظام
    SELECT id INTO first_user_id FROM users LIMIT 1;
    
    IF first_user_id IS NULL THEN
        RAISE NOTICE 'لا يوجد مستخدمون في النظام! يرجى التسجيل أولاً.';
    ELSE
        -- إنشاء قبيلة تجريبية
        INSERT INTO tribes (tribe_code, name, name_en, description, icon, is_private, leader_id, member_count)
        VALUES ('TEST1', 'قبيلة الاختبار', 'Test Tribe', 'هذه قبيلة تم إنشاؤها آلياً للتأكد من ظهور البيانات', '🧪', false, first_user_id, 1)
        ON CONFLICT (tribe_code) DO NOTHING
        RETURNING id INTO tribe_id;
        
        -- إضافة القائد كعضو
        IF tribe_id IS NOT NULL THEN
            INSERT INTO tribe_members (tribe_id, user_id, is_leader, status)
            VALUES (tribe_id, first_user_id, true, 'active')
            ON CONFLICT DO NOTHING;
        END IF;
    END IF;
END $$;

-- 2. الفحص النهائي والأهم: هل توجد بيانات؟
SELECT 'REPORT' as status;

SELECT 
    (SELECT count(*) FROM tribes) as "Total Tribes",
    (SELECT count(*) FROM tribe_members) as "Total Members",
    (SELECT count(*) FROM users) as "Total Users";

-- 3. عرض عينة من القبائل (للتأكد من أن الاستعلام يراها)
SELECT id, name, tribe_code, leader_id FROM tribes;
