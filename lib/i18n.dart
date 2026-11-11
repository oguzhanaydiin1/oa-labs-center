import 'dart:ui' show PlatformDispatcher;

import 'i18n_en.dart';

/// Arayüz dili. Metinler Türkçe yazılır; İngilizcede [enStrings] sözlüğünden karşılığı alınır.
class L {
  L._();

  /// Arayüz İngilizce mi?
  static bool en = false;

  /// [lang]: "auto" (cihazın dili), "tr" ya da "en".
  static void apply(String lang) {
    if (lang == 'tr' || lang == 'en') {
      en = lang == 'en';
    } else {
      en = PlatformDispatcher.instance.locale.languageCode.toLowerCase() != 'tr';
    }
  }

  static String get code => en ? 'en' : 'tr';
}

/// Türkçe metni arayüz diline çevirir. `{ad}` biçimindeki yer tutucular [args] ile doldurulur:
/// `t('{n} güncelleme var', {'n': 3})`.
String t(String tr, [Map<String, Object?> args = const {}]) {
  var s = L.en ? (enStrings[tr] ?? tr) : tr;
  args.forEach((k, v) => s = s.replaceAll('{$k}', '${v ?? ''}'));
  return s;
}
