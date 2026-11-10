package dev.oalabs.oa_center

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "oa/center" kanalı:
 *  - surum(paket): kurulu paketin sürüm adı, kurulu değilse null
 *  - ac(paket): paketi açar; açılamazsa false
 *  - bekleyenGiris(): başka bir OA uygulaması giriş istiyorsa onun paket adı, yoksa null
 *  - girisSonuc(kod): isteğe cevap verir (kod null: vazgeçildi) ve ekranı kapatır
 *
 * Tek giriş (Android): öbür OA uygulaması bu ekranı startActivityForResult ile ACTION_GIRIS
 * eylemiyle açar. Kullanıcı onay verirse sunucudan alınan tek kullanımlık kod "kod" olarak döner;
 * isteyen uygulama kodu kendi oturumuna çevirir. İsteyenin paket adını Android bildirir
 * (callingActivity), uygulama kendisi söyleyemez.
 *
 * Paketlerin görülebilmesi için adları AndroidManifest'teki <queries> listesinde olmalı
 * (scripts/android_ayarla.py ekler).
 */
class MainActivity : FlutterActivity() {
    companion object {
        const val ACTION_GIRIS = "dev.oalabs.center.GIRIS"
    }

    private var bekleyen: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (intent?.action == ACTION_GIRIS) bekleyen = callingActivity?.packageName
    }

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
                    val launch = packageManager.getLaunchIntentForPackage(pkg)
                    if (launch == null) {
                        result.success(false)
                    } else {
                        startActivity(launch)
                        result.success(true)
                    }
                }
                "bekleyenGiris" -> result.success(bekleyen)
                "girisSonuc" -> {
                    val kod = call.argument<String>("kod")
                    if (kod != null && bekleyen != null) {
                        setResult(Activity.RESULT_OK, Intent().putExtra("kod", kod))
                    } else {
                        setResult(Activity.RESULT_CANCELED)
                    }
                    bekleyen = null
                    result.success(null)
                    finish()
                }
                else -> result.notImplemented()
            }
        }
    }
}
