package dev.oalabs.oa_center

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "oa/center" kanalı:
 *  - surum(paket): kurulu paketin sürüm adı, kurulu değilse null
 *  - ac(paket): paketi açar; açılamazsa false
 * Paketlerin görülebilmesi için adları AndroidManifest'teki <queries> listesinde olmalı
 * (scripts/android_ayarla.py ekler).
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "oa/center").setMethodCallHandler { call, result ->
            val pkg = call.argument<String>("paket") ?: ""
            when (call.method) {
                "surum" -> {
                    try {
                        @Suppress("DEPRECATION")
                        result.success(packageManager.getPackageInfo(pkg, 0).versionName)
                    } catch (e: PackageManager.NameNotFoundException) {
                        result.success(null)
                    }
                }
                "ac" -> {
                    val intent = packageManager.getLaunchIntentForPackage(pkg)
                    if (intent == null) {
                        result.success(false)
                    } else {
                        startActivity(intent)
                        result.success(true)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
