# OA Labs Center

OA Labs uygulamalarını tek yerden kuran, güncelleyen ve açan uygulama. Windows ve Android; Flutter ile yazıldı,
arayüz OA Labs tasarım sistemini kullanır.

## Ne yapar

- **Ana sayfa:** Kurulu OA uygulamaları, sürümleri, "Aç" ve "Güncelle". Windows'ta "Hepsini güncelle".
- **Keşfet:** Kurulu olmayan uygulamalar ("Kur"), yakında çıkacaklar ("Çıkınca haber ver") ve yalnız öbür platformda olanlar.
- **Hesabım:** OA Labs hesabıyla giriş (e-postaya gelen 6 haneli kod), hesaba bağlı cihazlar.
- OA Labs Center kendini de günceller.

## Nasıl çalışır

| Konu | Windows | Android |
|---|---|---|
| Kurulu sürüm | "Program ekle/kaldır" kayıtları (`reg query`) | Paket adı (`oa/center` kanalı) |
| En yeni sürüm | Uygulamanın GitHub deposundaki sürümler | Aynı |
| Kurulum | Kurulum programı sessiz çalışır | APK iner, Android kurulum onayını ister |
| Açma | Kayıttaki exe | Paketin açılış ekranı |

Uygulama listesi `lib/catalog.dart` içindedir. `https://oalabs.dev/center/apps.json` yayımlanırsa uygulama onu
kullanır; böylece yeni bir uygulama eklemek için OA Labs Center'ı güncellemek gerekmez. Android'de yeni bir
paketin görülebilmesi için adı `scripts/android_ayarla.py` içindeki `PACKAGES` listesinde de olmalıdır.

## Derleme

Her `main` gönderiminde GitHub Actions (`.github/workflows/derle.yml`) şunları derler ve `pubspec.yaml`daki sürüm
numarasıyla Releases sayfasına ekler:

- `OA-Labs-Center-Kurulum.exe`: Windows kurulum programı (yönetici izni istemez)
- `OA-Labs-Center-Windows.zip`: kurmadan denemek için
- `OA-Labs-Center-Android.apk`

Yeni sürüm için `pubspec.yaml`da `version` satırını artır ve `release-notes.md`ye başlığını ekle.

`windows/` ve `android/` klasörleri depoda tutulmaz; derleme sırasında `scripts/platform_hazirla.sh` üretir.

**Android imzası:** Depo ayarlarında `ANDROID_KEYSTORE_BASE64` ve `ANDROID_KEYSTORE_PASSWORD` gizli değerleri varsa
her sürüm aynı OA anahtarıyla imzalanır. Yoksa test anahtarı kullanılır ve Android yeni sürümü eskisinin üzerine kurmaz.

## Tek giriş

Hesap şu an OA Labs Center ile Pusula Browser arasında paylaşılır; her uygulama kendi oturumunu açar.
Sunucu tarafı: `radyo-app/server/src/auth.js` (`/v1/auth/handoff`, `/v1/auth/redeem`).

- **Windows:** Giriş yapan uygulama oturum anahtarını Windows'un kullanıcıya özel şifrelemesiyle (DPAPI)
  `%LOCALAPPDATA%\OA Labs\oturum.dat` dosyasına yazar (`lib/shared_session.dart`, Pusula'da birebir aynısı).
  Girişsiz açılan öbür uygulama bu anahtarla tek kullanımlık kod alır ve kendi oturumunu açar.
- **Android:** Pusula, Center'ı `dev.oalabs.center.GIRIS` eylemiyle `startActivityForResult` ile açar. Center
  isteyen uygulamanın paket adını Android'den alır, kullanıcıya sorar, onaylanırsa tek kullanımlık kodu döndürür.

## Windows'ta arka planda çalışma

`lib/desktop.dart`: tepsi simgesi, `HKCU\...\Run` kaydıyla açılışta `--arka-plan` başlatma, 6 saatte bir denetim,
bildirim, isteğe bağlı kendiliğinden güncelleme (açık uygulamalara dokunmaz), 127.0.0.1:47613 ile tek kopya.

## Sonraki adımlar

- Yenilikler akışı ve Destek ekranı
