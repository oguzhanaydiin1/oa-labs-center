# OA Labs Center

OA Labs uygulamalarını tek yerden kuran, güncelleyen ve açan uygulama. Windows ve Android; Flutter ile yazıldı,
arayüz OA Labs tasarım sistemini kullanır.

## Ne yapar

- **Ana sayfa:** Duyurular, öbür cihazdan gelen kurulum istekleri, güncellemeler ve kurulu uygulamalar.
- **Keşfet:** Kurulu olmayan uygulamalar, yakında çıkacaklar ve yalnız öbür platformda olanlar.
- **Uygulama sayfası:** Özellikler, ekran görüntüleri, sürüm bilgisi ve geçmişi; Kur, Aç, Güncelle, Kaldır.
- **Yenilikler:** Bütün uygulamaların GitHub sürüm notları tek akışta.
- **Cihazlarım:** Hesaba bağlı telefon ve bilgisayarlar, üzerlerindeki uygulamalar; uzaktan kurulum isteği.
- **Destek:** Geri bildirim formu (/v1/feedback) ve iletişim bilgileri.
- **Hesap ve ayarlar:** Giriş, oturumlar, deneme sürümleri, dil, Windows'ta arka plan, Android'de bildirimler.
- OA Labs Center kendini de günceller.

## Dil

Metinler Türkçe yazılır ve `t('...')` ile sarılır (`lib/i18n.dart`); İngilizce karşılıkları `lib/i18n_en.dart`
sözlüğündedir. Yeni bir metin eklenince İngilizcesini de oraya yaz, yoksa İngilizce arayüzde Türkçesi görünür.

## Nasıl çalışır

| Konu | Windows | Android |
|---|---|---|
| Kurulu sürüm | "Program ekle/kaldır" kayıtları (`reg query`) | Paket adı (`oa/center` kanalı) |
| En yeni sürüm | Uygulamanın GitHub deposundaki sürümler | Aynı |
| Kurulum | Kurulum programı sessiz çalışır | APK iner, Android kurulum onayını ister |
| Açma | Kayıttaki exe | Paketin açılış ekranı |

Uygulama listesi `https://oalabs.dev/center/apps.json` (radyo-app deposunda `docs/center/apps.json`): ad, tanıtım,
özellikler, ekran görüntüleri, GitHub deposu ve kurulum bilgisi. Uygulama bunu açılışta okur; okuyamazsa
`assets/catalog.json`daki kopyayı kullanır. Yeni bir uygulama eklemek için OA Labs Center'ı güncellemek gerekmez.

Sunucu tarafı (radyo-app/server/src/center.js): cihaz eşitleme ve uzaktan kurulum (`/v1/me/devices…`,
`/v1/me/commands…`), duyurular (`/v1/announcements`, panelden `/v1/admin/announcements`). Android'de yeni bir
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
