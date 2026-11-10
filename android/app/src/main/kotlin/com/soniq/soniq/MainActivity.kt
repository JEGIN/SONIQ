package com.soniq.soniq

import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.soniq.soniq.dsp.NativeAudioDspEngine

class MainActivity : AudioServiceActivity() {
    private var dspEngine: NativeAudioDspEngine? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        dspEngine = NativeAudioDspEngine(this, flutterEngine)
        dspEngine?.setup()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soniq.soniq/app_share")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppSourceApkPath" -> {
                        try {
                            val apkPath = applicationContext.applicationInfo.sourceDir
                            result.success(apkPath)
                        } catch (e: Exception) {
                            result.error("APK_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        dspEngine?.release()
        super.onDestroy()
    }
}
