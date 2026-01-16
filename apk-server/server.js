const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

// Serve static files (APK will be here)
app.use(express.static(path.join(__dirname, 'public')));

// Main route - download page
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Direct APK download
app.get('/download', (req, res) => {
    const apkPath = path.join(__dirname, 'public', 'app.apk');
    res.download(apkPath, 'app.apk', (err) => {
        if (err) {
            res.status(404).send('الملف غير موجود');
        }
    });
});

// Start server
app.listen(PORT, () => {
    console.log(`🚀 Server running on http://localhost:${PORT}`);
    console.log(`📱 APK download page ready!`);
});
