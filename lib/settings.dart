import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';

/// Kullanıcı ayarları (cihazda saklanır).
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings i = Settings._();

  SharedPreferences? _p;

  /// Deneme (beta) sürümlerini de al.
  bool beta = false;

  /// Android: günde bir güncellemeleri ve duyuruları denetleyip bildirim göster.
  bool androidNotify = true;

  /// "auto", "tr" ya da "en".
  String lang = 'auto';

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      beta = _p!.getBool('beta') ?? false;
      androidNotify = _p!.getBool('androidBildirim') ?? true;
      lang = _p!.getString('dil') ?? 'auto';
    } catch (_) {}
    L.apply(lang);
  }

  Future<void> setBeta(bool v) async {
    beta = v;
    await _p?.setBool('beta', v);
    notifyListeners();
  }

  Future<void> setAndroidNotify(bool v) async {
    androidNotify = v;
    await _p?.setBool('androidBildirim', v);
    notifyListeners();
  }

  Future<void> setLang(String v) async {
    lang = v;
    await _p?.setString('dil', v);
    L.apply(v);
    notifyListeners();
  }
}
