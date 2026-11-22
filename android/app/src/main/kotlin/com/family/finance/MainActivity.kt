package com.family.finance

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 앱 안 업데이트: 내려받은 APK 를 안드로이드 설치 화면으로 넘긴다 (Ninedogs 와 같은 방식).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "finance/install")
            .setMethodCallHandler { call, result ->
                if (call.method != "installApk") return@setMethodCallHandler result.notImplemented()
                val path = call.argument<String>("path")
                    ?: return@setMethodCallHandler result.error("no_path", "path 가 필요합니다", null)
                try {
                    installApk(path)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("install_failed", e.message, null)
                }
            }
    }

    /** Android 7+ 는 file:// 경로를 막으므로 FileProvider 의 content:// 로 넘긴다. 사용자가 "설치"를 눌러야 진행된다. */
    private fun installApk(path: String) {
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", File(path))
        startActivity(Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}
