const express = require('express');
const multer = require('multer');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../client')));

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Configure Multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, uploadsDir);
    },
    filename: (req, file, cb) => {
        const uniqueName = `${uuidv4()}-${file.originalname}`;
        cb(null, uniqueName);
    }
});

const upload = multer({
    storage: storage,
    limits: {
        fileSize: 150 * 1024 * 1024 // 150MB limit
    },
    fileFilter: (req, file, cb) => {
        // Accept all file types
        cb(null, true);
    }
});

// In-memory files database (replace with real DB in production)
let filesDatabase = [];

// Load existing files database if exists
const dbPath = path.join(__dirname, 'files-db.json');
if (fs.existsSync(dbPath)) {
    try {
        filesDatabase = JSON.parse(fs.readFileSync(dbPath, 'utf8'));
    } catch (err) {
        console.error('Error loading database:', err);
        filesDatabase = [];
    }
}

// Save database function
function saveDatabase() {
    try {
        fs.writeFileSync(dbPath, JSON.stringify(filesDatabase, null, 2));
    } catch (err) {
        console.error('Error saving database:', err);
    }
}

// Routes

// Upload file
app.post('/api/upload', upload.single('file'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'لم يتم رفع أي ملف' });
        }

        const fileInfo = {
            id: uuidv4(),
            name: req.file.originalname,
            filename: req.file.filename,
            size: req.file.size,
            type: req.file.mimetype,
            date: new Date().toISOString(),
            path: req.file.path
        };

        filesDatabase.push(fileInfo);
        saveDatabase();

        res.json({
            success: true,
            message: 'تم رفع الملف بنجاح',
            file: {
                id: fileInfo.id,
                name: fileInfo.name,
                size: fileInfo.size,
                type: fileInfo.type,
                date: fileInfo.date
            }
        });
    } catch (error) {
        console.error('Upload error:', error);
        res.status(500).json({ error: 'خطأ في رفع الملف' });
    }
});

// Get all files
app.get('/api/files', (req, res) => {
    try {
        const files = filesDatabase.map(file => ({
            id: file.id,
            name: file.name,
            size: file.size,
            type: file.type,
            date: file.date
        }));
        res.json({ files });
    } catch (error) {
        console.error('Get files error:', error);
        res.status(500).json({ error: 'خطأ في جلب الملفات' });
    }
});

// Download file
app.get('/api/download/:id', (req, res) => {
    try {
        const file = filesDatabase.find(f => f.id === req.params.id);

        if (!file) {
            return res.status(404).json({ error: 'الملف غير موجود' });
        }

        const filePath = path.join(uploadsDir, file.filename);

        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'الملف غير موجود على السيرفر' });
        }

        res.download(filePath, file.name);
    } catch (error) {
        console.error('Download error:', error);
        res.status(500).json({ error: 'خطأ في تحميل الملف' });
    }
});

// Delete file
app.delete('/api/files/:id', (req, res) => {
    try {
        const fileIndex = filesDatabase.findIndex(f => f.id === req.params.id);

        if (fileIndex === -1) {
            return res.status(404).json({ error: 'الملف غير موجود' });
        }

        const file = filesDatabase[fileIndex];
        const filePath = path.join(uploadsDir, file.filename);

        // Delete file from disk
        if (fs.existsSync(filePath)) {
            fs.unlinkSync(filePath);
        }

        // Remove from database
        filesDatabase.splice(fileIndex, 1);
        saveDatabase();

        res.json({
            success: true,
            message: 'تم حذف الملف بنجاح'
        });
    } catch (error) {
        console.error('Delete error:', error);
        res.status(500).json({ error: 'خطأ في حذف الملف' });
    }
});

// Get file info
app.get('/api/files/:id', (req, res) => {
    try {
        const file = filesDatabase.find(f => f.id === req.params.id);

        if (!file) {
            return res.status(404).json({ error: 'الملف غير موجود' });
        }

        res.json({
            id: file.id,
            name: file.name,
            size: file.size,
            type: file.type,
            date: file.date
        });
    } catch (error) {
        console.error('Get file error:', error);
        res.status(500).json({ error: 'خطأ في جلب معلومات الملف' });
    }
});

// Serve frontend
app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, '../client/index.html'));
});

// Error handling middleware
app.use((err, req, res, next) => {
    console.error('Server error:', err);

    if (err instanceof multer.MulterError) {
        if (err.code === 'LIMIT_FILE_SIZE') {
            return res.status(400).json({
                error: 'حجم الملف كبير جداً. الحد الأقصى 150 ميجابايت'
            });
        }
        return res.status(400).json({ error: err.message });
    }

    res.status(500).json({ error: 'خطأ في السيرفر' });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Server is running on http://localhost:${PORT}`);
    console.log(`📁 Upload directory: ${uploadsDir}`);
    console.log(`📊 Files in database: ${filesDatabase.length}`);
});
