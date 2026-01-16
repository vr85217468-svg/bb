// =====================================================
// 🔐 نظام المصادقة - Authentication System
// =====================================================

// جلب بيانات تسجيل الدخول من Supabase
async function getLoginCredentials() {
    try {
        console.log('🔍 جاري جلب بيانات الدخول من Supabase...');

        const { data, error } = await supabase
            .from(CONFIG.TABLE_NAME)
            .select('setting_key, setting_value')
            .in('setting_key', [CONFIG.KEYS.SERVER_USERNAME, CONFIG.KEYS.SERVER_PASSWORD]);

        if (error) {
            console.error('❌ خطأ في جلب البيانات:', error);
            throw new Error('فشل الاتصال بقاعدة البيانات: ' + error.message);
        }

        console.log('📦 البيانات المستلمة:', data);

        if (!data || data.length === 0) {
            throw new Error('لا توجد بيانات دخول في قاعدة البيانات!');
        }

        const credentials = {};
        data.forEach(item => {
            if (item.setting_key === CONFIG.KEYS.SERVER_USERNAME) {
                credentials.username = item.setting_value;
            }
            if (item.setting_key === CONFIG.KEYS.SERVER_PASSWORD) {
                credentials.password = item.setting_value;
            }
        });

        if (!credentials.username || !credentials.password) {
            throw new Error('بيانات الدخول غير مكتملة في قاعدة البيانات!');
        }

        console.log('✅ تم جلب بيانات الدخول بنجاح');
        return credentials;

    } catch (error) {
        console.error('❌ خطأ:', error);
        throw error;
    }
}

// التحقق من بيانات الدخول
async function verifyLogin(inputUsername, inputPassword) {
    try {
        const credentials = await getLoginCredentials();

        console.log('🔐 التحقق من البيانات...');
        console.log('👤 اليوزر المدخل:', inputUsername);
        console.log('👤 اليوزر الصحيح:', credentials.username);

        if (credentials.username === inputUsername && credentials.password === inputPassword) {
            console.log('✅ تسجيل الدخول ناجح!');
            return { success: true, username: inputUsername };
        } else {
            console.log('❌ بيانات الدخول غير صحيحة');
            return {
                success: false,
                error: credentials.username !== inputUsername ? 'اسم المستخدم غير صحيح' : 'كلمة المرور غير صحيحة'
            };
        }
    } catch (error) {
        return { success: false, error: error.message };
    }
}

// حفظ جلسة المستخدم
function saveSession(username) {
    sessionStorage.setItem('adminUser', username);
    sessionStorage.setItem('loginTime', Date.now().toString());
}

// التحقق من وجود جلسة
function checkSession() {
    const user = sessionStorage.getItem('adminUser');
    const loginTime = sessionStorage.getItem('loginTime');

    if (user && loginTime) {
        // التحقق من انتهاء الجلسة (24 ساعة)
        const elapsed = Date.now() - parseInt(loginTime);
        const maxAge = 24 * 60 * 60 * 1000; // 24 hours

        if (elapsed < maxAge) {
            return { valid: true, username: user };
        }
    }

    return { valid: false };
}

// تسجيل الخروج
function logout() {
    sessionStorage.removeItem('adminUser');
    sessionStorage.removeItem('loginTime');
    console.log('👋 تم تسجيل الخروج');
}

// تصدير الدوال
window.Auth = {
    getLoginCredentials,
    verifyLogin,
    saveSession,
    checkSession,
    logout
};
