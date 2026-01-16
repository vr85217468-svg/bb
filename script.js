// File Upload Website - JavaScript
// Modern file upload system with drag & drop support

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

// Files storage (in-memory for demo, will be replaced with actual backend)
let uploadedFiles = [];

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

// Upload File
async function uploadFile(file) {
    // Show progress
    uploadProgress.classList.remove('hidden');
    uploadFileName.textContent = file.name;

    // Simulate upload progress
    await simulateUpload();

    // Create file object
    const fileObj = {
        id: generateId(),
        name: file.name,
        size: file.size,
        type: file.type,
        date: new Date().toISOString(),
        url: URL.createObjectURL(file), // For demo purposes
        file: file // Store actual file
    };

    // Add to storage
    uploadedFiles.push(fileObj);
    saveFiles();

    // Hide progress
    uploadProgress.classList.add('hidden');
    progressFill.style.width = '0%';

    // Show success toast
    showToast(`تم رفع ${file.name} بنجاح!`, 'success');

    // Render files
    renderFiles();
}

// Simulate Upload Progress
function simulateUpload() {
    return new Promise((resolve) => {
        let progress = 0;
        const interval = setInterval(() => {
            progress += Math.random() * 30;
            if (progress >= 100) {
                progress = 100;
                clearInterval(interval);
                progressFill.style.width = '100%';
                uploadPercent.textContent = '100%';
                setTimeout(resolve, 300);
            } else {
                progressFill.style.width = progress + '%';
                uploadPercent.textContent = Math.floor(progress) + '%';
            }
        }, 200);
    });
}

// Generate Unique ID
function generateId() {
    return Date.now().toString(36) + Math.random().toString(36).substr(2);
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

// Render Files
function renderFiles() {
    if (uploadedFiles.length === 0) {
        emptyState.classList.remove('hidden');
        filesGrid.innerHTML = '';
        fileCount.textContent = '0';
        return;
    }

    emptyState.classList.add('hidden');
    fileCount.textContent = uploadedFiles.length;

    filesGrid.innerHTML = uploadedFiles.map(file => `
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
    const file = uploadedFiles.find(f => f.id === id);
    if (!file) return;

    const a = document.createElement('a');
    a.href = file.url;
    a.download = file.name;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);

    showToast(`جاري تحميل ${file.name}`, 'success');
}

// Copy Link
function copyLink(id) {
    const file = uploadedFiles.find(f => f.id === id);
    if (!file) return;

    // In a real application, this would be the actual download URL
    const link = `${window.location.origin}/download/${file.id}`;

    navigator.clipboard.writeText(link).then(() => {
        showToast('تم نسخ الرابط!', 'success');
    }).catch(() => {
        showToast('فشل نسخ الرابط', 'error');
    });
}

// Delete File
function deleteFile(id) {
    if (!confirm('هل أنت متأكد من حذف هذا الملف؟')) return;

    const index = uploadedFiles.findIndex(f => f.id === id);
    if (index === -1) return;

    const fileName = uploadedFiles[index].name;
    uploadedFiles.splice(index, 1);
    saveFiles();
    renderFiles();

    showToast(`تم حذف ${fileName}`, 'success');
}

// Clear All Files
function clearAllFiles() {
    if (uploadedFiles.length === 0) return;

    if (!confirm('هل أنت متأكد من حذف جميع الملفات؟')) return;

    uploadedFiles = [];
    saveFiles();
    renderFiles();

    showToast('تم حذف جميع الملفات', 'success');
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

// Save Files to LocalStorage
function saveFiles() {
    try {
        // Note: We can't store File objects in localStorage
        // In production, files would be on server
        const filesToSave = uploadedFiles.map(f => ({
            id: f.id,
            name: f.name,
            size: f.size,
            type: f.type,
            date: f.date
        }));
        localStorage.setItem('uploadedFiles', JSON.stringify(filesToSave));
    } catch (e) {
        console.error('Error saving files:', e);
    }
}

// Load Files from LocalStorage
function loadFiles() {
    try {
        const saved = localStorage.getItem('uploadedFiles');
        if (saved) {
            const files = JSON.parse(saved);
            uploadedFiles = files.map(f => ({
                ...f,
                url: '#', // Placeholder since we can't restore the blob URL
                file: null
            }));
            renderFiles();
        } else {
            renderFiles();
        }
    } catch (e) {
        console.error('Error loading files:', e);
        renderFiles();
    }
}
