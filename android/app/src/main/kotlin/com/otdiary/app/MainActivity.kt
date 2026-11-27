package com.otdiary.app

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingData: String? = null
    private val saveCode = 7101
    private val openCode = 7102
    private val maxBytes = 10 * 1024 * 1024

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.otdiary.app/tools")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidget" -> {
                        OtSummaryWidget.store(this, call.argument<String>("month") ?: "", call.argument<String>("hours") ?: "0", call.argument<String>("days") ?: "0")
                        result.success(null)
                    }
                    "clearWidget" -> { OtSummaryWidget.clear(this); result.success(null) }
                    "saveFile", "pickBackup" -> {
                        if (pending != null) {
                            result.error("BUSY", "Another file picker is open", null)
                            return@setMethodCallHandler
                        }
                        val save = call.method == "saveFile"
                        val data = call.argument<String>("data")
                        if (save && (data == null || data.toByteArray(Charsets.UTF_8).size > maxBytes)) {
                            result.error("SIZE", "File is too large", null)
                            return@setMethodCallHandler
                        }
                        pending = result
                        pendingData = data
                        try {
                            val intent = Intent(if (save) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = if (save) call.argument<String>("mime") ?: "application/octet-stream" else "*/*"
                                if (save) putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "ot-diary.json")
                            }
                            startActivityForResult(intent, if (save) saveCode else openCode)
                        } catch (e: Exception) {
                            pending = null; pendingData = null
                            result.error("PICKER", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    @Deprecated("Activity result compatibility for the system document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != saveCode && requestCode != openCode) return
        val result = pending ?: return
        val content = pendingData
        pending = null; pendingData = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(if (requestCode == saveCode) false else null)
            return
        }
        Thread {
            try {
                val response: Any = if (requestCode == saveCode) {
                    val stream = contentResolver.openOutputStream(uri, "wt") ?: error("Cannot open selected file")
                    stream.use { it.write((content ?: error("Missing content")).toByteArray(Charsets.UTF_8)) }
                    true
                } else {
                    val stream = contentResolver.openInputStream(uri) ?: error("Cannot read selected file")
                    stream.use { input ->
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val n = input.read(buffer)
                            if (n < 0) break
                            if (output.size() + n > maxBytes) error("Backup exceeds 10 MB")
                            output.write(buffer, 0, n)
                        }
                        output.toString("UTF-8")
                    }
                }
                runOnUiThread { result.success(response) }
            } catch (e: Exception) {
                runOnUiThread { result.error("FILE", e.message, null) }
            }
        }.start()
    }
}
