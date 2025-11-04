package com.example.capstone_project

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || 
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d("BootReceiver", "Device booted - checking if geofencing should restart")
            
            // Check if geofencing was active before reboot
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isMonitoring = prefs.getBoolean("flutter.is_monitoring", false)
            
            if (isMonitoring) {
                Log.d("BootReceiver", "Restarting geofencing service")
                
                // Start the foreground service
                val serviceIntent = Intent(context, ForegroundLocationService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
                
                // Optionally launch the Flutter app to reinitialize geofencing
                // val appIntent = Intent(context, MainActivity::class.java)
                // appIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                // context.startActivity(appIntent)
            }
        }
    }
}