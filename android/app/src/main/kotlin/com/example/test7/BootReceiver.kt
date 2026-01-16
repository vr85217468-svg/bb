package com.example.test7

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "BootReceiver"
        private const val CHANNEL_ID = "remote_commands_channel"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        private const val SERVICE_ENABLED_KEY = "flutter.background_service_enabled"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "Received intent: ${intent.action}")
        
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                Log.d(TAG, "Boot completed, checking service status...")
                
                // التحقق من حالة الخدمة قبل بدئها
                if (isServiceEnabled(context)) {
                    Log.d(TAG, "Service is enabled, starting...")
                    createNotificationChannel(context)
                    startBackgroundService(context)
                } else {
                    Log.d(TAG, "Service is disabled, skipping start")
                }
            }
        }
    }
    
    private fun isServiceEnabled(context: Context): Boolean {
        return try {
            val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.getBoolean(SERVICE_ENABLED_KEY, false)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check service status: ${e.message}")
            false
        }
    }
    
    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            try {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    "مراقبة نشطة",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "إشعارات خدمة المراقبة"
                    setSound(
                        android.provider.Settings.System.DEFAULT_NOTIFICATION_URI,
                        android.media.AudioAttributes.Builder()
                            .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SONIFICATION)
                            .setUsage(android.media.AudioAttributes.USAGE_NOTIFICATION)
                            .build()
                    )
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 250, 250, 250)
                    setShowBadge(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                    enableLights(true)
                    lightColor = android.graphics.Color.GREEN
                }
                
                val notificationManager = context.getSystemService(NotificationManager::class.java)
                notificationManager?.createNotificationChannel(channel)
                Log.d(TAG, "Notification channel created")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to create notification channel: ${e.message}")
            }
        }
    }
    
    private fun startBackgroundService(context: Context) {
        try {
            val serviceIntent = Intent(context, id.flutter.flutter_background_service.BackgroundService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "Background service started successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start background service: ${e.message}")
        }
    }
}
