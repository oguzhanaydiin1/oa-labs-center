import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

  /// "yayinda", "beta" ya da "yakinda".
  final String state;

  /// Uygulamanın oalabs.dev'deki sayfası.
  final String page;

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

  static OAApp? fromJson(Object? j) {
    if (j is! Map) return null;
    final id = j['id'], name = j['name'];
    if (id is! String || name is! String || id.isEmpty || name.isEmpty) return null;
    return OAApp(
      id: id,
      name: name,
      tagline: (j['tagline'] ?? '').toString(),
      state: (j['state'] ?? 'yayinda').toString(),
      page: (j['page'] ?? 'https://oalabs.dev/').toString(),
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

/// Uygulamayla gelen katalog. Sunucudaki liste okunabilirse onun yerine geçer.
const builtinCatalog = <OAApp>[
  OAApp(
    id: 'pusula',
    name: 'Pusula Browser',
    tagline: 'Hızlı, sade, reklamsız tarayıcı. Bilgisayarın ve telefonun eşitlenir.',
    state: 'yayinda',
    page: 'https://oalabs.dev/tarayici/',
    repo: 'oguzhanaydiin1/oa-tarayici',
    icon: 'pusula',
    win: WinTarget(
      asset: r'^Pusula-Kurulum\.exe$',
      key: '{5B0E2B3C-4F1A-4C7E-9A0F-0A1B2C3D4E5F}_is1',
      exe: 'oa_tarayici.exe',
      silent: _inno,
    ),
    android: AndroidTarget(asset: r'^Pusula-Android\.apk$', package: 'dev.oalabs.oa_tarayici'),
  ),
  OAApp(
    id: 'kopru',
    name: 'Pusula Köprü',
    tagline: 'Bilgisayarın ile telefonun arasında dosya, fotoğraf, bağlantı ve pano.',
    state: 'yayinda',
    page: 'https://oalabs.dev/kopru/',
    repo: 'oguzhanaydiin1/pusula-kopru',
    icon: 'kopru',
    win: WinTarget(
      asset: r'^Pusula-Kopru-Kurulum\.exe$',
      key: '{8C1F4E2A-6B3D-4A57-9E21-3F5D7C9A0B14}_is1',
      exe: 'pusula_kopru.exe',
      silent: _inno,
    ),
    android: AndroidTarget(asset: r'^Pusula-Kopru-Android\.apk$', package: 'dev.oalabs.pusula_kopru'),
  ),
  OAApp(
    id: 'radyo',
    name: 'OA Radyo',
    tagline: 'Türkiye’nin ve dünyanın radyoları tek uygulamada.',
    state: 'yayinda',
    page: 'https://oalabs.dev/radyo/',
    repo: 'oguzhanaydiin1/radyo-app',
    icon: 'radyo',
    color: Color(0xFFF2A541),
    ink: Color(0xFF14110A),
    win: WinTarget(asset: r'^Radyo-Setup\.exe$', displayName: 'OA Radyo', exe: 'Radyo.exe', silent: ['/S']),
  ),
  OAApp(
    id: 'harrier',
    name: 'Harrier Cleaner',
    tagline: 'Bilgisayarını derli toplu ve hızlı tutar.',
    state: 'beta',
    page: 'https://oalabs.dev/harrier/',
    repo: 'oguzhanaydiin1/cihaz_bakim',
    icon: 'harrier',
    color: Color(0xFF1E3A8A),
    win: WinTarget(
      asset: r'^HarrierCleaner-Setup-.*\.exe$',
      key: '{8C3B2C1E-6F1A-4C55-9E2E-6B8E0A4D1F21}_is1',
      exe: 'harrier_cleaner.exe',
      silent: _inno,
    ),
  ),
  OAApp(
    id: 'score',
    name: 'OA Score',
    tagline: 'Canlı skorlar ve maç haberleri.',
    state: 'yakinda',
    page: 'https://oalabs.dev/#uygulamalar',
    color: Color(0xFF5BC48C),
    ink: Color(0xFF0F2A1C),
  ),
  OAApp(
    id: 'barkod',
    name: 'OA Barkod',
    tagline: 'Hazırlanıyor.',
    state: 'yakinda',
    page: 'https://oalabs.dev/#uygulamalar',
    color: Color(0xFF6EA8FE),
    ink: Color(0xFF0E1A30),
  ),
];

/// Katalog: oalabs.dev/center/apps.json okunabilirse o, yoksa son okunan, o da yoksa uygulamayla gelen.
/// Böylece yeni bir uygulama eklemek için OA Labs Center'ı güncellemek gerekmez.
class Catalog {
  Catalog._();
  static const _url = 'https://oalabs.dev/center/apps.json';
  static const _prefKey = 'katalog';

  static List<OAApp>? _parse(String body) {
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

  /// Önce elde olanı (son okunan ya da uygulamayla gelen) verir.
  static Future<List<OAApp>> cached() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_prefKey);
      if (s != null) return _parse(s) ?? builtinCatalog;
    } catch (_) {}
    return builtinCatalog;
  }

  /// Sunucudaki listeyi dener; okunamazsa null.
  static Future<List<OAApp>?> remote() async {
    try {
      final r = await http
          .get(Uri.parse(_url), headers: {'User-Agent': 'OALabsCenter/$appVersion', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (r.statusCode != 200) return null;
      final body = utf8.decode(r.bodyBytes);
      final apps = _parse(body);
      if (apps == null) return null;
      final p = await SharedPreferences.getInstance();
      await p.setString(_prefKey, body);
      return apps;
    } catch (_) {
      return null;
    }
  }
}
