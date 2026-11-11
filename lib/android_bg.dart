import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'catalog.dart';
import 'i18n.dart';
import 'settings.dart';

/// Android: günde bir kez güncellemeleri ve duyuruları denetleyip bildirim gösteren arka plan işi.
///
/// İş Kotlin'de (GuncellemeIsci, Android WorkManager) uygulama kapalıyken çalışır. Neye bakacağını
/// uygulamanın dosya klasöründeki `izlenen.json`dan okur; bu dosyayı burası yazar.
class AndroidBackground {
  AndroidBackground._();
  static const _ch = MethodChannel('oa/center');
  static List<OAApp> _apps = const [];

  /// Katalog yenilenince çağrılır: izlenen listeyi günceller, ayara göre işi açar ya da kapatır.
  static Future<void> apply([List<OAApp>? apps]) async {
    if (!Platform.isAndroid) return;
    if (apps != null) _apps = apps;
    final on = Settings.i.androidNotify;
    try {
      if (on) {
        final dir = await getApplicationSupportDirectory();
        final list = [
          for (final a in [..._apps, centerApp])
            if (a.android != null && a.repo != null)
              {'name': a.name, 'package': a.android!.package, 'repo': a.repo, 'asset': a.android!.asset},
        ];
        await File('${dir.path}/izlenen.json').writeAsString(jsonEncode({
          'beta': Settings.i.beta,
          'lang': L.code,
          'title1': t('Güncelleme var'),
          'titleN': t('{n} güncelleme var'),
          'apps': list,
        }));
        await _ch.invokeMethod('bildirimIzni');
      }
      await _ch.invokeMethod('arkaPlan', {'acik': on});
    } catch (_) {}
  }
}
