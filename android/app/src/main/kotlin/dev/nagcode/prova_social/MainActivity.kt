package dev.nagcode.prova_social

import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "dev.nagcode/prova_social/device",
        ).setMethodCallHandler { call, result ->
            if (call.method == "androidAbi") {
                result.success(Build.SUPPORTED_ABIS.firstOrNull())
            } else {
                result.notImplemented()
            }
        }
    }
}
