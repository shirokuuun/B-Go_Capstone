package com.example.capstone_project

import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.ByteArrayOutputStream

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.bgo.printer/print"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
    }

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
}