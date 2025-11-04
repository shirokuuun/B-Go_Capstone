package com.example.capstone_project

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.util.Base64
import androidx.core.app.NotificationCompat
import androidx.core.app.ActivityCompat
import android.Manifest
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    // Channel for printer functionality
    private val PRINTER_CHANNEL = "com.bgo.printer/print"
    
    // Channel for foreground service (geofencing)
    private val GEOFENCING_CHANNEL = "com.example.capstone_project/foreground_service"
    
    // Notification configuration for foreground service
    private val NOTIFICATION_CHANNEL_ID = "geofencing_service_channel"
    private val NOTIFICATION_ID = 1
    private val REQUEST_LOCATION_PERMISSION = 1

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // ==========================================
        // PRINTER CHANNEL (Your existing functionality)
        // ==========================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRINTER_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isPrinterAvailable" -> {
                    result.success(true)
                }
                "printReceipt" -> {
                    val content = call.argument<String>("content")
                    val logoBytes = call.argument<ByteArray>("logoBytes")
                    
                    if (content != null) {
                        val printed = printToBuiltInPrinter(content, logoBytes)
                        result.success(printed)
                    } else {
                        result.error("INVALID_ARGUMENT", "Content is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        // ==========================================
        // GEOFENCING CHANNEL (New functionality)
        // ==========================================
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GEOFENCING_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    startForegroundService()
                    result.success(true)
                }
                "stopForegroundService" -> {
                    stopForegroundService()
                    result.success(true)
                }
                "requestBackgroundLocationPermission" -> {
                    requestBackgroundLocationPermission()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // ==========================================
    // PRINTER FUNCTIONALITY (Your existing code)
    // ==========================================
    private fun printToBuiltInPrinter(content: String, logoBytes: ByteArray?): Boolean {
        return try {
            // Method 1: Try direct print intent
            try {
                val printIntent = Intent("android.intent.action.PRINT")
                printIntent.putExtra("text", content)
                printIntent.putExtra("PRINT_TEXT", content)
                sendBroadcast(printIntent)
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // Method 2: Android Print Service with logo
            try {
                val printManager = getSystemService(PRINT_SERVICE) as PrintManager
                val webView = WebView(this)
                
                // Convert logo to base64 if available
                var logoBase64 = ""
                if (logoBytes != null) {
                    try {
                        val bitmap = BitmapFactory.decodeByteArray(logoBytes, 0, logoBytes.size)
                        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 200, 200, true)
                        val outputStream = ByteArrayOutputStream()
                        resizedBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                        logoBase64 = Base64.encodeToString(outputStream.toByteArray(), Base64.DEFAULT)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }
                
                val htmlContent = if (logoBase64.isNotEmpty()) {
                    """
                    <html>
                    <head>
                        <style>
                            body { 
                                font-family: monospace; 
                                font-size: 12px; 
                                margin: 10px;
                                text-align: center;
                            }
                            img { 
                                max-width: 200px; 
                                margin: 10px auto;
                                display: block;
                            }
                            pre { 
                                white-space: pre-wrap;
                                text-align: left;
                            }
                        </style>
                    </head>
                    <body>
                        <img src="data:image/png;base64,$logoBase64" />
                        <pre>$content</pre>
                    </body>
                    </html>
                    """.trimIndent()
                } else {
                    """
                    <html>
                    <head>
                        <style>
                            body { font-family: monospace; font-size: 12px; margin: 10px; }
                            pre { white-space: pre-wrap; }
                        </style>
                    </head>
                    <body>
                        <pre>$content</pre>
                    </body>
                    </html>
                    """.trimIndent()
                }
                
                webView.loadDataWithBaseURL(null, htmlContent, "text/html", "UTF-8", null)
                
                webView.webViewClient = object : WebViewClient() {
                    override fun onPageFinished(view: WebView?, url: String?) {
                        val printAdapter = webView.createPrintDocumentAdapter("BATRASCO Receipt")
                        printManager.print("Receipt", printAdapter, PrintAttributes.Builder().build())
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            // Method 3: Direct device file with ESC/POS commands
            try {
                val printerPaths = listOf(
                    "/dev/ttyS1",
                    "/dev/ttyS0",
                    "/dev/ttyUSB0",
                    "/dev/usb/lp0"
                )
                
                for (path in printerPaths) {
                    val file = File(path)
                    if (file.exists()) {
                        FileOutputStream(file).use { output ->
                            // Initialize printer
                            output.write(byteArrayOf(0x1B.toByte(), 0x40.toByte()))
                            
                            // Print logo if available
                            if (logoBytes != null) {
                                try {
                                    val bitmap = BitmapFactory.decodeByteArray(logoBytes, 0, logoBytes.size)
                                    val resizedBitmap = Bitmap.createScaledBitmap(bitmap, 384, 384, true)
                                    val imageBytes = convertBitmapToEscPos(resizedBitmap)
                                    output.write(imageBytes)
                                    output.write("\n\n".toByteArray())
                                } catch (e: Exception) {
                                    e.printStackTrace()
                                }
                            }
                            
                            // Print text content
                            output.write(content.toByteArray(Charsets.UTF_8))
                            
                            // Feed and cut
                            output.write(byteArrayOf(0x1D.toByte(), 0x56.toByte(), 0x00.toByte()))
                            output.flush()
                        }
                        break
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }

            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun convertBitmapToEscPos(bitmap: Bitmap): ByteArray {
        val width = bitmap.width
        val height = bitmap.height
        val bytes = mutableListOf<Byte>()
        
        // ESC/POS image command
        bytes.add(0x1D.toByte())
        bytes.add(0x76.toByte())
        bytes.add(0x30.toByte())
        bytes.add(0x00.toByte())
        
        val widthBytes = (width / 8)
        bytes.add((widthBytes and 0xFF).toByte())
        bytes.add(((widthBytes shr 8) and 0xFF).toByte())
        bytes.add((height and 0xFF).toByte())
        bytes.add(((height shr 8) and 0xFF).toByte())
        
        // Convert bitmap to monochrome
        for (y in 0 until height) {
            for (x in 0 until width step 8) {
                var byte = 0
                for (b in 0 until 8) {
                    if (x + b < width) {
                        val pixel = bitmap.getPixel(x + b, y)
                        val gray = (((pixel shr 16) and 0xFF) * 0.299 +
                                   ((pixel shr 8) and 0xFF) * 0.587 +
                                   (pixel and 0xFF) * 0.114).toInt()
                        if (gray < 128) {
                            byte = byte or (1 shl (7 - b))
                        }
                    }
                }
                bytes.add(byte.toByte())
            }
        }
        
        return bytes.toByteArray()
    }

    // ==========================================
    // GEOFENCING FUNCTIONALITY (New code)
    // ==========================================
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Geofencing Service"
            val descriptionText = "Tracking your location for passenger drop-off detection"
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(NOTIFICATION_CHANNEL_ID, name, importance).apply {
                description = descriptionText
            }
            
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        createNotificationChannel()

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            notificationIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("B-Go Conductor Active")
            .setContentText("Tracking location for passenger drop-off detection")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceIntent = Intent(this, ForegroundLocationService::class.java)
            startForegroundService(serviceIntent)
        }

        // Show notification
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

    private fun stopForegroundService() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceIntent = Intent(this, ForegroundLocationService::class.java)
            stopService(serviceIntent)
        }
    }

    private fun requestBackgroundLocationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            if (ActivityCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION),
                    REQUEST_LOCATION_PERMISSION
                )
            }
        }
    }
}