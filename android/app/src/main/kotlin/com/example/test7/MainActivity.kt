package com.example.test7

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.test7/battery"
    private var wakeLock: PowerManager.WakeLock? = null
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
        acquireWakeLock()
        configureAudioForVoice()
    }
    
    private fun configureAudioForVoice() {
        // Set audio mode to optimize for voice communication
        try {
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as android.media.AudioManager
            audioManager.mode = android.media.AudioManager.MODE_IN_COMMUNICATION
            android.util.Log.d("MainActivity", "Audio mode set to COMMUNICATION for better voice quality")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to configure audio: ${e.message}")
        }
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // عند العودة من Jitsi أو أي activity خارجي، نستخدم نفس الـ intent
        // هذا يمنع إعادة تشغيل التطبيق مع singleTask
        setIntent(intent)
        android.util.Log.d("MainActivity", "onNewIntent called - handling return from external activity")
    }
    
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimization" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isBatteryOptimizationDisabled" -> {
                    result.success(isBatteryOptimizationDisabled())
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "remote_commands_channel",
                "مراقبة نشطة",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "إشعارات خدمة المراقبة"
                
                // 🔔 تفعيل الصوت
                setSound(
                    android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                    android.media.AudioAttributes.Builder()
                        .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                        .build()
                )
                
                // 📳 تفعيل الاهتزاز
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 250, 250)
                
                // 🔴 إظهار البادج
                setShowBadge(true)
                
                // 🔒 إظهار على شاشة القفل
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                
                // 💡 إضاءة الشاشة
                enableLights(true)
                lightColor = android.graphics.Color.GREEN
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager?.createNotificationChannel(channel)
        }
    }
    
    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ParentalMonitor::BackgroundServiceLock"
            )
            wakeLock?.acquire()
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Failed to acquire wake lock: ${e.message}")
        }
    }
    
    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!isBatteryOptimizationDisabled()) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Failed to request battery optimization: ${e.message}")
                }
            }
        }
    }
    
    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }
    
    override fun onDestroy() {
        super.onDestroy()
        wakeLock?.release()
    }
}
