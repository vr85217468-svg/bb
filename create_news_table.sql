-- إنشاء جدول الأخبار
CREATE TABLE IF NOT EXISTS news (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    emoji TEXT DEFAULT '📰',
    is_important BOOLEAN DEFAULT FALSE,
    is_published BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- إنشاء فهرس لتحسين الأداء
CREATE INDEX IF NOT EXISTS idx_news_published ON news(is_published);
CREATE INDEX IF NOT EXISTS idx_news_created_at ON news(created_at DESC);

-- تفعيل Row Level Security
ALTER TABLE news ENABLE ROW LEVEL SECURITY;

-- سياسة للقراءة: الجميع يمكنهم قراءة الأخبار المنشورة
CREATE POLICY "Anyone can view published news"
    ON news
    FOR SELECT
    USING (is_published = true);

-- سياسة للإدارة: يمكن للمسؤولين إضافة وتحديث وحذف الأخبار
-- ملاحظة: ستحتاج إلى تعديل هذه السياسة حسب نظام الصلاحيات لديك
CREATE POLICY "Admins can manage news"
    ON news
    FOR ALL
    USING (true);

-- إضافة trigger لتحديث updated_at تلقائياً
CREATE OR REPLACE FUNCTION update_news_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER news_updated_at
    BEFORE UPDATE ON news
    FOR EACH ROW
    EXECUTE FUNCTION update_news_updated_at();

-- إضافة بعض الأخبار التجريبية
INSERT INTO news (title, content, emoji, is_important) VALUES
('مرحباً بكم في قسم الأخبار! 🎉', 'نحن سعداء بإطلاق قسم الأخبار الجديد! هنا ستجد آخر التحديثات والأخبار المهمة. ترقبوا المزيد من الأخبار المثيرة قريباً!', '🎉', true),
('تحديثات جديدة قادمة', 'نعمل حالياً على تحسينات كبيرة للتطبيق. انتظروا ميزات جديدة رائعة في التحديث القادم!', '🚀', false),
('نصيحة اليوم', 'تذكر دائماً أن الاستمرارية أهم من الكمال. خطوة صغيرة كل يوم خير من لا شيء.', '💡', false);
