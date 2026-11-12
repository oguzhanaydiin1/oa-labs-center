#!/usr/bin/env python3
"""flutter create'in ürettiği Android klasörüne OA Labs Center ayarlarını uygular.

- İzinler: internet ve indirilen APK'ları kurabilmek için REQUEST_INSTALL_PACKAGES.
- <queries>: Android 11+ başka uygulamaların kurulu olup olmadığını ancak adı burada geçiyorsa söyler.
  Kataloğa yeni bir Android uygulaması eklenince paketi PACKAGES listesine de eklenmeli.
- MainActivity platform/android/ klasöründen gelir ("oa/center" kanalı: kurulu sürüm, uygulamayı aç).
- OA_KEYSTORE_PATH ve OA_KEYSTORE_PASSWORD varsa yayın sürümü sabit OA anahtarıyla imzalanır.

Kullanım (proje kökünde): python3 scripts/android_ayarla.py
"""
import os
import re
import shutil
import sys

MANIFEST = 'android/app/src/main/AndroidManifest.xml'

PERMS = [
    'android.permission.INTERNET',
    'android.permission.REQUEST_INSTALL_PACKAGES',
    'android.permission.REQUEST_DELETE_PACKAGES',  # "Kaldır": sistemin kaldırma onayı
    'android.permission.POST_NOTIFICATIONS',       # günlük güncelleme ve duyuru bildirimi
]

# Kurulu olup olmadığına bakılan OA uygulamaları
PACKAGES = [
    'dev.oalabs.oa_tarayici',   # Pusula Browser
    'dev.oalabs.pusula_kopru',  # Pusula Köprü
    'dev.oalabs.radyo',         # OA Radyo
    'dev.oalabs.harrier',       # Harrier Cleaner
    'dev.oalabs.oa_score',
    'dev.oalabs.oa_barkod',
    'dev.oalabs.terazi',        # Terazi
]


def manifest():
    s = open(MANIFEST, encoding='utf-8').read()
    for p in PERMS:
        if p + '"' not in s:
            s = s.replace('<application', '<uses-permission android:name="%s"/>\n    <application' % p, 1)
    missing = [p for p in PACKAGES if 'android:name="%s"' % p not in s]
    if missing:
        lines = ''.join('        <package android:name="%s"/>\n' % p for p in missing)
        if '<queries>' in s:
            s = s.replace('<queries>', '<queries>\n' + lines.rstrip('\n'), 1)
        else:
            s = s.replace('<application', '<queries>\n' + lines + '    </queries>\n    <application', 1)
    if 'android:label="oa_center"' not in s and 'android:label="OA Labs Center"' not in s:
        sys.exit('AndroidManifest.xml içinde uygulama adı bulunamadı')
    s = s.replace('android:label="oa_center"', 'android:label="OA Labs Center"')
    open(MANIFEST, 'w', encoding='utf-8').write(s)
    print('Manifest: izinler, paket sorguları ve ad ayarlandı')


def native():
    for root, _, files in os.walk('android/app/src/main'):
        for f in files:
            if f in ('MainActivity.kt', 'MainActivity.java'):
                os.remove(os.path.join(root, f))
    shutil.copytree('platform/android/app/src/main', 'android/app/src/main', dirs_exist_ok=True)
    print('Android: MainActivity kopyalandı')


PROGUARD = '''
# WorkManager: yayın derlemesinde küçültme aracı Room veritabanı sınıfını silip yeniden adlandırıyordu;
# uygulama açılır açılmaz "Failed to create an instance of class androidx.work.impl.WorkDatabase" ile çöküyordu.
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class * extends androidx.work.ListenableWorker { public <init>(android.content.Context, androidx.work.WorkerParameters); }
-keep class dev.oalabs.oa_center.** { *; }
'''


def gradle_deps():
    """Günlük denetim (GuncellemeIsci) için Android WorkManager ve küçültme kuralları."""
    rules = 'android/app/proguard-rules.pro'
    old = open(rules, encoding='utf-8').read() if os.path.exists(rules) else ''
    if 'WorkDatabase_Impl' not in old:
        open(rules, 'w', encoding='utf-8').write(old + PROGUARD)
    kts = 'android/app/build.gradle.kts'
    groovy = 'android/app/build.gradle'
    if os.path.exists(kts):
        s = open(kts, encoding='utf-8').read()
        if 'androidx.work:work-runtime' not in s:
            s += '\ndependencies {\n    implementation("androidx.work:work-runtime-ktx:2.10.1")\n}\n'
            open(kts, 'w', encoding='utf-8').write(s)
    elif os.path.exists(groovy):
        s = open(groovy, encoding='utf-8').read()
        if 'androidx.work:work-runtime' not in s:
            s += "\ndependencies {\n    implementation 'androidx.work:work-runtime-ktx:2.10.1'\n}\n"
            open(groovy, 'w', encoding='utf-8').write(s)
    else:
        sys.exit('android/app/build.gradle(.kts) bulunamadı')
    print('Gradle: WorkManager eklendi')


def signing():
    path = os.environ.get('OA_KEYSTORE_PATH')
    if not path or not os.environ.get('OA_KEYSTORE_PASSWORD'):
        print('::warning title=imza::Sabit imza anahtarı yok (ANDROID_KEYSTORE_BASE64 secret). '
              'APK test anahtarıyla imzalanıyor; Android güncellemeyi eski sürümün üzerine kurmaz.')
        return
    kts = 'android/app/build.gradle.kts'
    groovy = 'android/app/build.gradle'
    if os.path.exists(kts):
        s = open(kts, encoding='utf-8').read()
        block = '''    signingConfigs {
        create("oa") {
            storeFile = file(System.getenv("OA_KEYSTORE_PATH"))
            storePassword = System.getenv("OA_KEYSTORE_PASSWORD")
            keyAlias = "oa"
            keyPassword = System.getenv("OA_KEYSTORE_PASSWORD")
        }
    }
'''
        if 'create("oa")' not in s:
            s = re.sub(r'(^android\s*\{\s*\n)', lambda m: m.group(1) + block, s, count=1, flags=re.M)
        s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                      'signingConfig = signingConfigs.getByName("oa")')
        open(kts, 'w', encoding='utf-8').write(s)
    elif os.path.exists(groovy):
        s = open(groovy, encoding='utf-8').read()
        block = '''    signingConfigs {
        oa {
            storeFile file(System.getenv("OA_KEYSTORE_PATH"))
            storePassword System.getenv("OA_KEYSTORE_PASSWORD")
            keyAlias "oa"
            keyPassword System.getenv("OA_KEYSTORE_PASSWORD")
        }
    }
'''
        if 'signingConfigs {' not in s:
            s = re.sub(r'(^android\s*\{\s*\n)', lambda m: m.group(1) + block, s, count=1, flags=re.M)
        s = s.replace('signingConfig signingConfigs.debug', 'signingConfig signingConfigs.oa')
        open(groovy, 'w', encoding='utf-8').write(s)
    else:
        sys.exit('android/app/build.gradle(.kts) bulunamadı')
    print('İmza: yayın sürümü sabit OA anahtarıyla imzalanacak')


if __name__ == '__main__':
    manifest()
    native()
    gradle_deps()
    signing()
