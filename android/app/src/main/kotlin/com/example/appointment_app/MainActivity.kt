package com.example.appointment_app

import android.content.ContentValues
import android.content.ClipData
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val reportPdfChannel = "appointment_app/report_pdf"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            reportPdfChannel
        ).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "savePdfToDownloads" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val filename = call.argument<String>("filename")
                        if (bytes == null || filename.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "PDF bytes and filename are required.",
                                null
                            )
                        } else {
                            result.success(savePdfToDownloads(bytes, filename).toString())
                        }
                    }
                    "sharePdfToApp" -> {
                        val uri = call.argument<String>("uri")
                        val target = call.argument<String>("target")
                        val recipient = call.argument<String>("recipient")
                        if (uri.isNullOrBlank() || target.isNullOrBlank()) {
                            result.error(
                                "INVALID_ARGUMENT",
                                "PDF URI and target app are required.",
                                null
                            )
                        } else {
                            sharePdfToApp(Uri.parse(uri), target, recipient)
                            result.success(null)
                        }
                    }
                    "openPdf" -> {
                        val uri = call.argument<String>("uri")
                        if (uri.isNullOrBlank()) {
                            result.error("INVALID_ARGUMENT", "PDF URI is required.", null)
                        } else {
                            openPdf(Uri.parse(uri))
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (error: Exception) {
                result.error("REPORT_PDF_ERROR", error.message, null)
            }
        }
    }

    private fun savePdfToDownloads(bytes: ByteArray, filename: String): Uri {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            throw IllegalStateException(
                "Saving reports to Downloads requires Android 10 or later."
            )
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, filename)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val uri = contentResolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            values
        ) ?: throw IllegalStateException("Could not create the PDF in Downloads.")

        try {
            val output = contentResolver.openOutputStream(uri)
                ?: throw IllegalStateException("Could not write the PDF to Downloads.")
            output.use { it.write(bytes) }
            val completedValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }
            contentResolver.update(uri, completedValues, null, null)
            return uri
        } catch (error: Exception) {
            contentResolver.delete(uri, null, null)
            throw error
        }
    }

    private fun sharePdfToApp(uri: Uri, target: String, recipient: String?) {
        val targetPackage = when (target) {
            "whatsapp" -> "com.whatsapp"
            "gmail" -> "com.google.android.gm"
            else -> throw IllegalArgumentException("Unsupported sharing target.")
        }
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "application/pdf"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newUri(contentResolver, "PDF attachment", uri)
            if (target == "gmail") {
                component = ComponentName(
                    targetPackage,
                    "$targetPackage.ComposeActivityGmailExternal"
                )
                putExtra(Intent.EXTRA_SUBJECT, "Combined Report")
                if (!recipient.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_EMAIL, arrayOf(recipient))
                }
            } else {
                setPackage(targetPackage)
            }
        }
        startActivity(intent)
    }

    private fun openPdf(uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/pdf")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            clipData = ClipData.newUri(contentResolver, "Report PDF", uri)
        }
        startActivity(Intent.createChooser(intent, "Open report"))
    }
}
