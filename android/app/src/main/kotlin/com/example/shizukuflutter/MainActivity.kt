package com.example.shizukuflutter

import android.os.Bundle
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "file_access"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getAppDocumentsPath") {
                val documentsPath = getExternalFilesDir(null)?.absolutePath
                if (documentsPath != null) {
                    result.success(documentsPath)
                } else {
                    result.error("UNAVAILABLE", "Could not get documents directory.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
