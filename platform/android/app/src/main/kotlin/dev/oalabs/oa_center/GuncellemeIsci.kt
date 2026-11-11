package dev.oalabs.oa_center

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

/**
 * Günde bir kez (Android WorkManager) çalışır, OA Labs Center kapalıyken de:
 *  - Telefonda kurulu OA uygulamalarının GitHub'daki son sürümlerine bakar; yenisi varsa bildirim gösterir.
 *  - api.oalabs.dev'deki duyurulara bakar; yeni bir duyuru varsa bildirim gösterir.
 * Neye bakacağını uygulamanın yazdığı files/izlenen.json dosyasından okur (lib/android_bg.dart).
 * Aynı sürüm ya da duyuru iki kez bildirilmez.
 */
class GuncellemeIsci(context: Context, params: WorkerParameters) : Worker(context, params) {
    companion object {
        const val KANAL = "guncellemeler"
        const val IS_ADI = "oa_center_denetim"
        private const val TERCIH = "oa_center_arka_plan"
    }

    override fun doWork(): Result {
        val ctx = applicationContext
        val f = File(ctx.filesDir, "izlenen.json")
        if (!f.exists()) return Result.success()
        val cfg = try { JSONObject(f.readText()) } catch (e: Exception) { return Result.success() }
        val prefs = ctx.getSharedPreferences(TERCIH, Context.MODE_PRIVATE)
        val beta = cfg.optBoolean("beta", false)
        val en = cfg.optString("lang") == "en"

        // 1) Güncellemeler
        val apps = cfg.optJSONArray("apps") ?: JSONArray()
        val yeni = mutableListOf<String>()
        for (i in 0 until apps.length()) {
            val a = apps.optJSONObject(i) ?: continue
            val pkg = a.optString("package")
            val kurulu = surum(ctx, pkg) ?: continue
            val son = sonSurum(a.optString("repo"), a.optString("asset"), beta) ?: continue
            if (!yeniMi(son, kurulu)) continue
            val etiket = "$pkg@$son"
            if (prefs.getBoolean(etiket, false)) continue
            prefs.edit().putBoolean(etiket, true).apply()
            yeni.add("${a.optString("name")} $son")
        }
        if (yeni.isNotEmpty()) {
            val baslik = if (yeni.size == 1) cfg.optString("title1", "Güncelleme var")
            else cfg.optString("titleN", "{n} güncelleme var").replace("{n}", yeni.size.toString())
            bildir(ctx, 1001, baslik, yeni.joinToString(", "))
        }

        // 2) Duyurular: ilk çalışmada eskileri bildirmeden yalnız işaretle.
        try {
            val j = JSONObject(getir("https://api.oalabs.dev/v1/announcements") ?: return Result.success())
            val list = j.optJSONArray("announcements") ?: JSONArray()
            val enSon = prefs.getInt("duyuru", -1)
            var max = enSon
            for (i in 0 until list.length()) {
                val d = list.optJSONObject(i) ?: continue
                val id = d.optInt("id", -1)
                if (id > max) max = id
                if (enSon >= 0 && id > enSon) {
                    val baslik = (if (en) d.optString("title_en") else "").ifBlank { d.optString("title") }
                    val metin = (if (en) d.optString("body_en") else "").ifBlank { d.optString("body") }
                    bildir(ctx, 2000 + (id % 1000), baslik, if (metin == "null") "" else metin)
                }
            }
            if (max != enSon) prefs.edit().putInt("duyuru", max).apply()
        } catch (e: Exception) {
        }
        return Result.success()
    }

    private fun surum(ctx: Context, pkg: String): String? = try {
        @Suppress("DEPRECATION")
        ctx.packageManager.getPackageInfo(pkg, 0).versionName
    } catch (e: PackageManager.NameNotFoundException) {
        null
    }

    private fun sonSurum(repo: String, asset: String, beta: Boolean): String? {
        if (repo.isBlank() || asset.isBlank()) return null
        val body = getir("https://api.github.com/repos/$repo/releases?per_page=8") ?: return null
        val re = try { Regex(asset) } catch (e: Exception) { return null }
        val arr = try { JSONArray(body) } catch (e: Exception) { return null }
        for (i in 0 until arr.length()) {
            val r = arr.optJSONObject(i) ?: continue
            if (r.optBoolean("draft")) continue
            if (r.optBoolean("prerelease") && !beta) continue
            val assets = r.optJSONArray("assets") ?: continue
            for (k in 0 until assets.length()) {
                if (re.containsMatchIn(assets.optJSONObject(k)?.optString("name") ?: "")) {
                    return r.optString("tag_name").removePrefix("v")
                }
            }
        }
        return null
    }

    private fun getir(adres: String): String? {
        var c: HttpURLConnection? = null
        return try {
            c = URL(adres).openConnection() as HttpURLConnection
            c.connectTimeout = 15000
            c.readTimeout = 15000
            c.setRequestProperty("User-Agent", "OALabsCenter-Android")
            c.setRequestProperty("Accept", "application/json")
            if (c.responseCode != 200) null else c.inputStream.bufferedReader().use { it.readText() }
        } catch (e: Exception) {
            null
        } finally {
            c?.disconnect()
        }
    }

    private fun parca(v: String): List<Int> =
        v.removePrefix("v").split(Regex("[.+\\- ]")).take(3).map { it.toIntOrNull() ?: 0 }

    private fun yeniMi(uzak: String, yerel: String): Boolean {
        val a = parca(uzak)
        val b = parca(yerel)
        for (i in 0 until 3) {
            val x = a.getOrElse(i) { 0 }
            val y = b.getOrElse(i) { 0 }
            if (x != y) return x > y
        }
        return false
    }

    private fun bildir(ctx: Context, id: Int, baslik: String, metin: String) {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(KANAL) == null) {
            nm.createNotificationChannel(NotificationChannel(KANAL, "OA Labs Center", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val ac = Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val pi = PendingIntent.getActivity(ctx, id, ac, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val n = NotificationCompat.Builder(ctx, KANAL)
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle(baslik)
            .setContentText(metin)
            .setStyle(NotificationCompat.BigTextStyle().bigText(metin))
            .setContentIntent(pi)
            .setAutoCancel(true)
            .build()
        try {
            NotificationManagerCompat.from(ctx).notify(id, n)
        } catch (e: SecurityException) {
        }
    }
}
