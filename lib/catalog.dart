import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'version.dart';

/// Windows'ta bir uygulamanın nasıl bulunup kurulacağı.
class WinTarget {
  const WinTarget({required this.asset, this.key, this.displayName, this.exe, this.silent = const []});

  /// Sürüm dosyasının adı (düzenli ifade), örn. `^Pusula-Kurulum\.exe$`.
  final String asset;

  /// "Program ekle/kaldır" kaydındaki anahtar adı (Inno Setup: `{AppId}_is1`).
  final String? key;

  /// Anahtar bilinmiyorsa kayıttaki görünen ad (örn. "OA Radyo").
  final String? displayName;

  /// Kayıtta simge yolu yoksa kurulum klasöründe aranacak exe adı.
  final String? exe;

  /// Kurulum programına verilen sessiz kurulum parametreleri.
  final List<String> silent;

  static WinTarget? fromJson(Object? j) {
    if (j is! Map || j['asset'] is! String) return null;
    return WinTarget(
      asset: j['asset'] as String,
      key: j['key'] as String?,
      displayName: j['displayName'] as String?,
      exe: j['exe'] as String?,
      silent: (j['silent'] as List? ?? const []).map((e) => e.toString()).toList(),
    );
  }
}

/// Android'de bir uygulamanın paketi ve sürüm dosyası.
class AndroidTarget {
  const AndroidTarget({required this.asset, required this.package});
  final String asset;
  final String package;

  static AndroidTarget? fromJson(Object? j) {
    if (j is! Map || j['asset'] is! String || j['package'] is! String) return null;
    return AndroidTarget(asset: j['asset'] as String, package: j['package'] as String);
  }
}

/// Katalogdaki bir OA Labs uygulaması.
class OAApp {
  const OAApp({
    required this.id,
    required this.name,
    required this.tagline,
    required this.state,
    required this.page,
    this.taglineEn,
    this.pageEn,
    this.features = const [],
    this.featuresEn = const [],
    this.shots = const [],
    this.repo,
    this.icon,
    this.color = const Color(0xFF1C2030),
    this.ink = const Color(0xFFEEEAE2),
    this.win,
    this.android,
    this.self = false,
  });

  final String id;
  final String name;
  final String tagline;
  final String? taglineEn;

  /// "yayinda", "beta" ya da "yakinda".
  final String state;

  /// Uygulamanın oalabs.dev'deki sayfası.
  final String page;
  final String? pageEn;
  final List<String> features;
  final List<String> featuresEn;

  /// Ekran görüntüleri (https adresleri).
  final List<String> shots;

  /// GitHub deposu (sürümler buradan okunur), örn. "oguzhanaydiin1/oa-tarayici".
  final String? repo;

  /// Uygulamayla gelen ikonun adı (assets/apps/ad.png); yoksa baş harfli kare çizilir.
  final String? icon;
  final Color color;
  final Color ink;
  final WinTarget? win;
  final AndroidTarget? android;

  /// OA Labs Center'ın kendisi (listelerde görünmez, yalnız kendini güncellemek için).
  final bool self;

  bool get soon => state == 'yakinda';
  bool get beta => state == 'beta';

  String get localTagline => L.en && (taglineEn ?? '').isNotEmpty ? taglineEn! : tagline;
  String get localPage => L.en && (pageEn ?? '').isNotEmpty ? pageEn! : page;
  List<String> get localFeatures => L.en && featuresEn.isNotEmpty ? featuresEn : features;

  /// Bu cihazda kurulabilir mi (bu platform için dosyası var mı)?
  bool get onThisPlatform => Platform.isWindows ? win != null : android != null;

  /// Bu platformdaki sürüm dosyasının adı (düzenli ifade).
  String? get asset => Platform.isWindows ? win?.asset : android?.asset;

  /// Yalnız öbür platformda varsa onun adı ("Windows" ya da "Android").
  String? get onlyOn {
    if (soon || onThisPlatform) return null;
    if (win != null) return 'Windows';
    if (android != null) return 'Android';
    return null;
  }

  static Color _hex(Object? v, Color fallback) {
    if (v is! String) return fallback;
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(v.trim());
    return m == null ? fallback : Color(int.parse('FF${m.group(1)}', radix: 16));
  }

  static List<String> _list(Object? v) => (v as List? ?? const []).map((e) => e.toString()).toList();

  static OAApp? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    if (id is! String || name is! String || id.isEmpty || name.isEmpty) return null;
    return OAApp(
      id: id,
      name: name,
      tagline: (j['tagline'] ?? '').toString(),
      taglineEn: j['tagline_en'] as String?,
      state: (j['state'] ?? 'yayinda').toString(),
      page: (j['page'] ?? 'https://oalabs.dev/').toString(),
      pageEn: j['page_en'] as String?,
      features: _list(j['features']),
      featuresEn: _list(j['features_en']),
      shots: _list(j['shots']).where((u) => u.startsWith('https://')).toList(),
      repo: j['repo'] as String?,
      icon: j['icon'] as String?,
      color: _hex(j['color'], const Color(0xFF1C2030)),
      ink: _hex(j['ink'], const Color(0xFFEEEAE2)),
      win: WinTarget.fromJson(j['windows']),
      android: AndroidTarget.fromJson(j['android']),
    );
  }
}

const _inno = ['/SILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CLOSEAPPLICATIONS'];

/// OA Labs Center'ın kendisi.
const centerApp = OAApp(
  id: 'center',
  name: 'OA Labs Center',
  tagline: 'OA Labs uygulamalarını tek yerden kur, güncelle ve aç.',
  taglineEn: 'Install, update and open OA Labs apps in one place.',
  state: 'yayinda',
  page: 'https://oalabs.dev/',
  repo: 'oguzhanaydiin1/oa-labs-center',
  win: WinTarget(
    asset: r'^OA-Labs-Center-Kurulum\.exe$',
    key: '{3E7A9C54-1D2B-4F68-A0C3-7B5E9D1F2A46}_is1',
    exe: 'oa_center.exe',
    silent: [..._inno, '/NOCANCEL'],
  ),
  android: AndroidTarget(asset: r'^OA-Labs-Center-Android\.apk$', package: 'dev.oalabs.oa_center'),
  self: true,
);

/// Katalog: oalabs.dev/center/apps.json okunabilirse o, yoksa son okunan, o da yoksa uygulamayla gelen
/// (assets/catalog.json, sitedekinin kopyası). Yeni bir uygulama eklemek için Center'ı güncellemek gerekmez.
class Catalog {
  Catalog._();
  static const _url = 'https://oalabs.dev/center/apps.json';
  static const _prefKey = 'katalog';

  static List<OAApp>? parse(String body) {
    try {
      final j = jsonDecode(body);
      final list = j is Map ? j['apps'] : j;
      if (list is! List) return null;
      final apps = list.map(OAApp.fromJson).whereType<OAApp>().where((a) => a.id != centerApp.id).toList();
      return apps.isEmpty ? null : apps;
    } catch (_) {
      return null;
    }
  }

  static List<OAApp> _bundled = const [];

  /// Uygulamayla gelen liste (her zaman vardır).
  static List<OAApp> get bundled => _bundled;

  static Future<void> loadBundled() async {
    try {
      _bundled = parse(await rootBundle.loadString('assets/catalog.json')) ?? const [];
    } catch (_) {
      _bundled = const [];
    }
  }

  /// Önce elde olanı (son okunan ya da uygulamayla gelen) verir.
  static Future<List<OAApp>> cached() async {
    if (_bundled.isEmpty) await loadBundled();
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_prefKey);
      if (s != null) return parse(s) ?? _bundled;
    } catch (_) {}
    return _bundled;
  }

  /// Sunucudaki listeyi dener; okunamazsa null.
  static Future<List<OAApp>?> remote() async {
    try {
      final r = await http
          .get(Uri.parse(_url), headers: {'User-Agent': 'OALabsCenter/$appVersion', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final body = utf8.decode(r.bodyBytes);
      final apps = parse(body);
      if (apps == null) return null;
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, body);
      return apps;
    } catch (_) {
      return null;
    }
  }
}
