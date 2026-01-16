// =====================================================
// 🎮 التطبيق الرئيسي - Main App
// =====================================================

// عناصر DOM
const elements = {
    loginCard: null,
    adminCard: null,
    loginForm: null,
    changeForm: null,
    loginBtn: null,
    changeBtn: null,
    showPassBtn: null,
    userName: null,
    passValue: null,
    passDisplay: null,
    loginAlert: null,
    adminAlert: null,
    loginAlertIcon: null,
    loginAlertMsg: null,
    adminAlertIcon: null,
    adminAlertMsg: null
};

// تهيئة العناصر
function initElements() {
    elements.loginCard = document.getElementById('loginCard');
    elements.adminCard = document.getElementById('adminCard');
    elements.loginForm = document.getElementById('loginForm');
    elements.changeForm = document.getElementById('changeForm');
    elements.loginBtn = document.getElementById('loginBtn');
    elements.changeBtn = document.getElementById('changeBtn');
    elements.showPassBtn = document.getElementById('showPassBtn');
    elements.userName = document.getElementById('userName');
    elements.passValue = document.getElementById('passValue');
    elements.passDisplay = document.getElementById('passDisplay');
    elements.loginAlert = document.getElementById('loginAlert');
    elements.adminAlert = document.getElementById('adminAlert');
    elements.loginAlertIcon = document.getElementById('loginAlertIcon');
    elements.loginAlertMsg = document.getElementById('loginAlertMsg');
    elements.adminAlertIcon = document.getElementById('adminAlertIcon');
    elements.adminAlertMsg = document.getElementById('adminAlertMsg');
}

// إنشاء جزيئات النار
function createParticles() {
    const container = document.getElementById('particles');
    if (!container) return;

    for (let i = 0; i < 30; i++) {
        const particle = document.createElement('div');
        particle.className = 'particle';
        particle.style.left = Math.random() * 100 + '%';
        particle.style.animationDelay = Math.random() * 8 + 's';
        particle.style.animationDuration = (Math.random() * 4 + 6) + 's';
        container.appendChild(particle);
    }
}

// عرض التنبيهات
function showAlert(message, type, isLogin = false) {
    const alert = isLogin ? elements.loginAlert : elements.adminAlert;
    const icon = isLogin ? elements.loginAlertIcon : elements.adminAlertIcon;
    const msg = isLogin ? elements.loginAlertMsg : elements.adminAlertMsg;

    if (!alert || !icon || !msg) return;

    alert.className = `alert alert-${type} show`;
    msg.textContent = message;
    icon.textContent = type === 'success' ? '✓' : '✕';

    setTimeout(() => alert.classList.remove('show'), 5000);
}

// التبديل بين الصفحات
function showAdminPage() {
    if (elements.loginCard) elements.loginCard.classList.add('hidden');
    if (elements.adminCard) elements.adminCard.classList.remove('hidden');
}

function showLoginPage() {
    if (elements.adminCard) elements.adminCard.classList.add('hidden');
    if (elements.loginCard) elements.loginCard.classList.remove('hidden');
}

// إظهار/إخفاء كلمة المرور
function togglePassword(inputId, btn) {
    const input = document.getElementById(inputId);
    if (!input) return;

    input.type = input.type === 'password' ? 'text' : 'password';
    btn.textContent = input.type === 'password' ? '👁️' : '🙈';
}

// معالجة تسجيل الدخول
async function handleLogin(e) {
    e.preventDefault();

    const userInput = document.getElementById('loginUser');
    const passInput = document.getElementById('loginPass');

    if (!userInput || !passInput) return;

    const username = userInput.value.trim();
    const password = passInput.value;

    if (!username || !password) {
        showAlert('يرجى إدخال اسم المستخدم وكلمة المرور', 'error', true);
        return;
    }

    elements.loginBtn.disabled = true;
    elements.loginBtn.innerHTML = '<div class="spinner"></div><span>جاري التحقق...</span>';

    try {
        const result = await Auth.verifyLogin(username, password);

        if (result.success) {
            Auth.saveSession(result.username);
            if (elements.userName) elements.userName.textContent = result.username;
            showAdminPage();
            showAlert('تم الدخول بنجاح! 🔥', 'success');
        } else {
            showAlert('⚠️ ' + result.error, 'error', true);
        }
    } catch (error) {
        showAlert('خطأ: ' + error.message, 'error', true);
    } finally {
        elements.loginBtn.disabled = false;
        elements.loginBtn.innerHTML = '<span>🔓</span><span>الدخول للمنطقة المحظورة</span>';
    }
}

// عرض المفتاح الحالي
async function showCurrentPassword() {
    elements.showPassBtn.disabled = true;
    elements.showPassBtn.innerHTML = '<div class="spinner"></div><span>جاري الكشف...</span>';

    try {
        const { data, error } = await supabase
            .from(CONFIG.TABLE_NAME)
            .select('setting_value')
            .eq('setting_key', CONFIG.KEYS.ADMIN_PASSWORD)
            .single();

        if (error) throw error;

        if (elements.passValue) elements.passValue.textContent = data.setting_value;
        if (elements.passDisplay) elements.passDisplay.classList.add('show');
        showAlert('تم كشف المفتاح السري ✓', 'success');
    } catch (error) {
        showAlert('فشل: ' + error.message, 'error');
    } finally {
        elements.showPassBtn.disabled = false;
        elements.showPassBtn.innerHTML = '<span>👁️</span><span>كشف المفتاح السري</span>';
    }
}

// تغيير المفتاح
async function handleChangePassword(e) {
    e.preventDefault();

    const newPassInput = document.getElementById('newPass');
    const confirmPassInput = document.getElementById('confirmPass');

    if (!newPassInput || !confirmPassInput) return;

    const newPass = newPassInput.value;
    const confirmPass = confirmPassInput.value;

    if (newPass !== confirmPass) {
        showAlert('المفتاحين غير متطابقين!', 'error');
        return;
    }

    if (newPass.length < 4) {
        showAlert('المفتاح يجب أن يكون 4 أحرف على الأقل', 'error');
        return;
    }

    elements.changeBtn.disabled = true;
    elements.changeBtn.innerHTML = '<div class="spinner"></div><span>جاري التحديث...</span>';

    try {
        // التحقق من وجود الإعداد
        const { data: existing } = await supabase
            .from(CONFIG.TABLE_NAME)
            .select()
            .eq('setting_key', CONFIG.KEYS.ADMIN_PASSWORD)
            .single();

        let result;
        if (existing) {
            result = await supabase
                .from(CONFIG.TABLE_NAME)
                .update({ setting_value: newPass })
                .eq('setting_key', CONFIG.KEYS.ADMIN_PASSWORD);
        } else {
            result = await supabase
                .from(CONFIG.TABLE_NAME)
                .insert({ setting_key: CONFIG.KEYS.ADMIN_PASSWORD, setting_value: newPass });
        }

        if (result.error) throw result.error;

        showAlert('تم تحديث المفتاح بنجاح! 🔥', 'success');
        if (elements.passValue) elements.passValue.textContent = newPass;
        newPassInput.value = '';
        confirmPassInput.value = '';
    } catch (error) {
        showAlert('فشل: ' + error.message, 'error');
    } finally {
        elements.changeBtn.disabled = false;
        elements.changeBtn.innerHTML = '<span>⚡</span><span>تحديث المفتاح</span>';
    }
}

// تسجيل الخروج
function handleLogout() {
    Auth.logout();
    showLoginPage();

    const userInput = document.getElementById('loginUser');
    const passInput = document.getElementById('loginPass');
    if (userInput) userInput.value = '';
    if (passInput) passInput.value = '';
}

// اختبار الاتصال بـ Supabase
async function testConnection() {
    console.log('🔌 جاري اختبار الاتصال بـ Supabase...');

    try {
        const { data, error } = await supabase
            .from(CONFIG.TABLE_NAME)
            .select('*');

        if (error) {
            console.error('❌ خطأ في الاتصال:', error);
            alert('❌ خطأ في الاتصال بقاعدة البيانات!\n\n' + error.message +
                '\n\nتأكد من:\n1. تفعيل RLS Policy في Supabase\n2. أو إيقاف RLS على الجدول');
            return false;
        }

        console.log('✅ الاتصال ناجح! البيانات:', data);

        if (!data || data.length === 0) {
            alert('⚠️ الجدول فارغ!\n\nأضف هذه البيانات في admin_settings:\n- server_username\n- server_password');
            return false;
        }

        return true;
    } catch (error) {
        console.error('❌ خطأ:', error);
        alert('فشل الاتصال: ' + error.message);
        return false;
    }
}

// تهيئة التطبيق
async function initApp() {
    console.log('🚀 جاري تهيئة التطبيق...');

    // تهيئة Supabase
    if (!initSupabase()) {
        alert('فشل إنشاء الاتصال بـ Supabase!');
        return;
    }

    // تهيئة العناصر
    initElements();

    // إنشاء جزيئات النار
    createParticles();

    // التحقق من الجلسة
    const session = Auth.checkSession();
    if (session.valid) {
        if (elements.userName) elements.userName.textContent = session.username;
        showAdminPage();
    }

    // اختبار الاتصال
    await testConnection();

    // ربط الأحداث
    if (elements.loginForm) {
        elements.loginForm.addEventListener('submit', handleLogin);
    }

    if (elements.changeForm) {
        elements.changeForm.addEventListener('submit', handleChangePassword);
    }

    if (elements.showPassBtn) {
        elements.showPassBtn.addEventListener('click', showCurrentPassword);
    }

    console.log('✅ تم تهيئة التطبيق بنجاح!');
}

// تشغيل التطبيق عند تحميل الصفحة
document.addEventListener('DOMContentLoaded', initApp);

// تصدير الدوال للاستخدام في HTML
window.togglePassword = togglePassword;
window.handleLogout = handleLogout;
