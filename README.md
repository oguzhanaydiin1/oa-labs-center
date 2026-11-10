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

## Sonraki adımlar

- Tek giriş: öbür OA uygulamalarının girişi OA Labs Center'dan alması
- Windows açılışında arka planda çalışma ve güncelleme bildirimi
- Yenilikler akışı ve Destek ekranı
