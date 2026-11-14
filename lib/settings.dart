import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'oa_theme.dart';

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

  /// Tema: 'dark', 'light' ya da 'system' (işletim sisteminin açık/koyu ayarına uyar).
  String theme = 'dark';

  /// [theme] ile sistemin parlaklığına göre OA.koyu'yu ayarlar. Değiştiyse true.
  bool applyTheme() {
    final was = OA.koyu;
    OA.koyu = theme == 'system'
        ? WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark
        : theme != 'light';
    return was != OA.koyu;
  }

  Future<void> load() async {
    try {
      _p = await SharedPreferences.getInstance();
      beta = _p!.getBool('beta') ?? false;
      androidNotify = _p!.getBool('androidBildirim') ?? true;
      lang = _p!.getString('dil') ?? 'auto';
      final th = _p!.getString('tema') ?? 'dark';
      theme = const ['dark', 'light', 'system'].contains(th) ? th : 'dark';
    } catch (_) {}
    L.apply(lang);
    applyTheme();
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

  Future<void> setTheme(String v) async {
    theme = v;
    await _p?.setString('tema', v);
    applyTheme();
    notifyListeners();
  }

  /// İşletim sisteminin açık/koyu ayarı değişti.
  void platformBrightnessChanged() {
    if (theme == 'system' && applyTheme()) notifyListeners();
  }
}
