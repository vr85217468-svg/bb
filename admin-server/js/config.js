// =====================================================
// ⚙️ إعدادات الاتصال بـ Supabase
// 🔧 غيّر هذه القيم إذا أردت تغيير الرابط
// =====================================================

const CONFIG = {
    // رابط Supabase
    SUPABASE_URL: 'https://jmtriazkllozwwgyuimw.supabase.co',

    // مفتاح Supabase (anon key)
    SUPABASE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImptdHJpYXprbGxvend3Z3l1aW13Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3MjY5MzUsImV4cCI6MjA4MTMwMjkzNX0.YqIPIjAAX5NN23vv48DF5MT9NLCZL6rccDpUh2fy-pw',

    // اسم الجدول
    TABLE_NAME: 'admin_settings',

    // مفاتيح الإعدادات
    KEYS: {
        SERVER_USERNAME: 'server_username',
        SERVER_PASSWORD: 'server_password',
        ADMIN_PASSWORD: 'admin_password'
    }
};

// إنشاء عميل Supabase
let supabase;

function initSupabase() {
    try {
        supabase = window.supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_KEY);
        console.log('✅ Supabase client created successfully!');
        return true;
    } catch (error) {
        console.error('❌ Failed to create Supabase client:', error);
        return false;
    }
}

// تصدير للاستخدام في ملفات أخرى
window.CONFIG = CONFIG;
window.initSupabase = initSupabase;
