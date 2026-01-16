// File Upload Website - JavaScript (Connected to Backend)
// Modern file upload system with drag & drop support

// API Configuration
const API_URL = 'http://localhost:3000/api';

// DOM Elements
const dropZone = document.getElementById('dropZone');
const fileInput = document.getElementById('fileInput');
const selectFileBtn = document.getElementById('selectFileBtn');
const uploadProgress = document.getElementById('uploadProgress');
const progressFill = document.getElementById('progressFill');
const uploadFileName = document.getElementById('uploadFileName');
const uploadPercent = document.getElementById('uploadPercent');
const filesGrid = document.getElementById('filesGrid');
const emptyState = document.getElementById('emptyState');
const fileCount = document.getElementById('fileCount');
const clearAllBtn = document.getElementById('clearAllBtn');
const toast = document.getElementById('toast');
const toastMessage = document.getElementById('toastMessage');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    loadFiles();
    setupEventListeners();
});

// Setup Event Listeners
function setupEventListeners() {
    // Drop zone click
    dropZone.addEventListener('click', () => fileInput.click());

    // Select file button
    selectFileBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        fileInput.click();
    });

    // File input change
    fileInput.addEventListener('change', (e) => handleFiles(e.target.files));

    // Drag and drop events
    dropZone.addEventListener('dragover', handleDragOver);
    dropZone.addEventListener('dragleave', handleDragLeave);
    dropZone.addEventListener('drop', handleDrop);

    // Clear all button
    clearAllBtn.addEventListener('click', clearAllFiles);

    // Prevent default drag behaviors on document
    document.addEventListener('dragover', (e) => e.preventDefault());
    document.addEventListener('drop', (e) => e.preventDefault());
}

// Drag Over Handler
function handleDragOver(e) {
    e.preventDefault();
    e.stopPropagation();
    dropZone.classList.add('drag-over');
}

// Drag Leave Handler
function handleDragLeave(e) {
    e.preventDefault();
    e.stopPropagation();
    dropZone.classList.remove('drag-over');
}

// Drop Handler
function handleDrop(e) {
    e.preventDefault();
    e.stopPropagation();
    dropZone.classList.remove('drag-over');

    const files = e.dataTransfer.files;
    handleFiles(files);
}

// Handle Files
async function handleFiles(files) {
    if (files.length === 0) return;

    for (let file of files) {
        await uploadFile(file);
    }

    // Reset file input
    fileInput.value = '';
}

// Upload File to Server
async function uploadFile(file) {
    try {
        // Show progress
        uploadProgress.classList.remove('hidden');
        uploadFileName.textContent = file.name;
        progressFill.style.width = '0%';
        uploadPercent.textContent = '0%';

        // Create FormData
        const formData = new FormData();
        formData.append('file', file);

        // Upload with progress tracking
        const xhr = new XMLHttpRequest();

        // Track upload progress
        xhr.upload.addEventListener('progress', (e) => {
            if (e.lengthComputable) {
                const percentage = Math.round((e.loaded / e.total) * 100);
                progressFill.style.width = percentage + '%';
                uploadPercent.textContent = percentage + '%';
            }
        });

        // Handle completion
        xhr.addEventListener('load', () => {
            if (xhr.status === 200) {
                const response = JSON.parse(xhr.responseText);
                showToast(`تم رفع ${file.name} بنجاح!`, 'success');
                loadFiles(); // Reload files list
            } else {
                const error = JSON.parse(xhr.responseText);
                showToast(error.error || 'فشل رفع الملف', 'error');
            }
            // Hide progress
            uploadProgress.classList.add('hidden');
        });

        // Handle errors
        xhr.addEventListener('error', () => {
            showToast('خطأ في الاتصال بالسيرفر', 'error');
            uploadProgress.classList.add('hidden');
        });

        // Send request
        xhr.open('POST', `${API_URL}/upload`);
        xhr.send(formData);

    } catch (error) {
        console.error('Upload error:', error);
        showToast('خطأ في رفع الملف', 'error');
        uploadProgress.classList.add('hidden');
    }
}

// Format File Size
function formatFileSize(bytes) {
    if (bytes === 0) return '0 بايت';
    const k = 1024;
    const sizes = ['بايت', 'كيلوبايت', 'ميجابايت', 'جيجابايت'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i];
}

// Format Date
function formatDate(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const diff = now - date;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return 'الآن';
    if (minutes < 60) return `منذ ${minutes} دقيقة`;
    if (hours < 24) return `منذ ${hours} ساعة`;
    if (days < 7) return `منذ ${days} يوم`;

    return date.toLocaleDateString('ar-SA', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Get File Icon
function getFileIcon(type) {
    if (type.startsWith('image/')) return 'fa-file-image';
    if (type.startsWith('video/')) return 'fa-file-video';
    if (type.startsWith('audio/')) return 'fa-file-audio';
    if (type.includes('pdf')) return 'fa-file-pdf';
    if (type.includes('zip') || type.includes('rar')) return 'fa-file-archive';
    if (type.includes('word')) return 'fa-file-word';
    if (type.includes('excel') || type.includes('sheet')) return 'fa-file-excel';
    if (type.includes('powerpoint') || type.includes('presentation')) return 'fa-file-powerpoint';
    if (type.includes('text')) return 'fa-file-alt';
    if (type.includes('apk') || type.includes('application')) return 'fa-mobile-alt';
    return 'fa-file';
}

// Load Files from Server
async function loadFiles() {
    try {
        const response = await fetch(`${API_URL}/files`);

        if (!response.ok) {
            throw new Error('Failed to load files');
        }

        const data = await response.json();
        const files = data.files || [];

        renderFiles(files);
    } catch (error) {
        console.error('Load files error:', error);
        showToast('خطأ في جلب الملفات', 'error');
        renderFiles([]);
    }
}

// Render Files
function renderFiles(files) {
    if (files.length === 0) {
        emptyState.classList.remove('hidden');
        filesGrid.innerHTML = '';
        fileCount.textContent = '0';
        return;
    }

    emptyState.classList.add('hidden');
    fileCount.textContent = files.length;

    filesGrid.innerHTML = files.map(file => `
        <div class="file-card glass">
            <div class="file-header">
                <div class="file-icon">
                    <i class="fas ${getFileIcon(file.type)}"></i>
                </div>
                <div class="file-info">
                    <div class="file-name">${file.name}</div>
                    <div class="file-meta">
                        <span class="meta-item">
                            <i class="fas fa-hdd"></i>
                            ${formatFileSize(file.size)}
                        </span>
                        <span class="meta-item">
                            <i class="fas fa-clock"></i>
                            ${formatDate(file.date)}
                        </span>
                    </div>
                </div>
            </div>
            <div class="file-actions">
                <button class="btn-secondary btn-icon" onclick="downloadFile('${file.id}')" title="تحميل">
                    <i class="fas fa-download"></i>
                </button>
                <button class="btn-secondary btn-icon" onclick="copyLink('${file.id}')" title="نسخ الرابط">
                    <i class="fas fa-link"></i>
                </button>
                <button class="btn-danger btn-icon" onclick="deleteFile('${file.id}')" title="حذف">
                    <i class="fas fa-trash"></i>
                </button>
            </div>
        </div>
    `).join('');
}

// Download File
function downloadFile(id) {
    window.open(`${API_URL}/download/${id}`, '_blank');
    showToast('جاري تحميل الملف...', 'success');
}

// Copy Link
function copyLink(id) {
    const link = `${window.location.origin}/api/download/${id}`;

    navigator.clipboard.writeText(link).then(() => {
        showToast('تم نسخ الرابط!', 'success');
    }).catch(() => {
        showToast('فشل نسخ الرابط', 'error');
    });
}

// Delete File
async function deleteFile(id) {
    if (!confirm('هل أنت متأكد من حذف هذا الملف؟')) return;

    try {
        const response = await fetch(`${API_URL}/files/${id}`, {
            method: 'DELETE'
        });

        if (!response.ok) {
            throw new Error('Failed to delete file');
        }

        showToast('تم حذف الملف بنجاح', 'success');
        loadFiles(); // Reload files list
    } catch (error) {
        console.error('Delete error:', error);
        showToast('خطأ في حذف الملف', 'error');
    }
}

// Clear All Files
async function clearAllFiles() {
    if (!confirm('هل أنت متأكد من حذف جميع الملفات؟')) return;

    try {
        const response = await fetch(`${API_URL}/files`);
        const data = await response.json();
        const files = data.files || [];

        if (files.length === 0) {
            showToast('لا توجد ملفات لحذفها', 'error');
            return;
        }

        // Delete all files
        for (const file of files) {
            await fetch(`${API_URL}/files/${file.id}`, {
                method: 'DELETE'
            });
        }

        showToast('تم حذف جميع الملفات', 'success');
        loadFiles();
    } catch (error) {
        console.error('Clear all error:', error);
        showToast('خطأ في حذف الملفات', 'error');
    }
}

// Show Toast Notification
function showToast(message, type = 'success') {
    toastMessage.textContent = message;
    toast.classList.remove('hidden');

    // Trigger reflow
    void toast.offsetWidth;

    toast.classList.add('show');

    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => {
            toast.classList.add('hidden');
        }, 300);
    }, 3000);
}
