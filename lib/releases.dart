import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalog.dart';
import 'version.dart';

/// GitHub'daki bir sürüm.
class Release {
  const Release({
    required this.version,
    required this.date,
    required this.notes,
    required this.prerelease,
    required this.assets,
    required this.url,
  });
  final String version;
  final DateTime? date;

  /// Sürüm notu (GitHub'daki metin).
  final String notes;
  final bool prerelease;

  /// Dosya adı → (indirme adresi, boyut).
  final Map<String, ({String url, int size})> assets;

  /// Sürümün GitHub sayfası.
  final String url;
}

/// Bir uygulamanın bu cihaza uygun en yeni sürüm dosyası.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.url, required this.fileName, required this.size, this.prerelease = false});
  final String version;
  final String url;
  final String fileName;
  final int size;
  final bool prerelease;
}

class _Hit {
  _Hit(this.at, this.list);
  final DateTime at;
  final List<Release> list;
}

/// GitHub'daki sürümlere bakar. Sonuç 10 dakika bellekte tutulur
/// (GitHub, girişsiz isteklere saatte 60 istek sınırı koyar).
class Releases {
  Releases._();
  static final _cache = <String, _Hit>{};
  static final _inFlight = <String, Future<List<Release>>>{};

  /// Uygulamanın son sürümleri (en yeni önce). Ağ yoksa son okunan, o da yoksa boş.
  /// Aynı anda gelen istekler tek GitHub isteğinde birleşir.
  static Future<List<Release>> list(OAApp app, {bool force = false}) {
    final repo = app.repo;
    if (repo == null) return Future.value(const []);
    final hit = _cache[app.id];
    if (!force && hit != null && DateTime.now().difference(hit.at) < const Duration(minutes: 10)) return Future.value(hit.list);
    return _inFlight[app.id] ??= _fetch(app, repo, hit).whenComplete(() => _inFlight.remove(app.id));
  }

  static Future<List<Release>> _fetch(OAApp app, String repo, _Hit? hit) async {
    try {
      final r = await http.get(Uri.parse('https://api.github.com/repos/$repo/releases?per_page=12'), headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'OALabsCenter/$appVersion',
      }).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return hit?.list ?? const [];
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      if (data is! List) return hit?.list ?? const [];
      final out = <Release>[];
      for (final rel in data.whereType<Map>()) {
        if (rel['draft'] == true) continue;
        final assets = <String, ({String url, int size})>{};
        for (final a in (rel['assets'] as List? ?? const []).whereType<Map>()) {
          assets[(a['name'] ?? '').toString()] =
              (url: (a['browser_download_url'] ?? '').toString(), size: a['size'] is int ? a['size'] as int : 0);
        }
        out.add(Release(
          version: (rel['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), ''),
          date: DateTime.tryParse((rel['published_at'] ?? rel['created_at'] ?? '').toString()),
          notes: (rel['body'] ?? '').toString(),
          prerelease: rel['prerelease'] == true,
          assets: assets,
          url: (rel['html_url'] ?? '').toString(),
        ));
      }
      _cache[app.id] = _Hit(DateTime.now(), out);
      return out;
    } catch (_) {
      return hit?.list ?? const [];
    }
  }

  /// [app] için bu platformdaki en yeni dosya. [beta]: deneme sürümleri de sayılır.
  static Future<ReleaseInfo?> latest(OAApp app, {bool force = false, bool beta = false}) async {
    final pattern = app.asset;
    if (pattern == null) return null;
    final re = RegExp(pattern);
    for (final rel in await list(app, force: force)) {
      if (rel.prerelease && !beta) continue;
      for (final e in rel.assets.entries) {
        if (re.hasMatch(e.key)) {
          return ReleaseInfo(version: rel.version, url: e.value.url, fileName: e.key, size: e.value.size, prerelease: rel.prerelease);
        }
      }
    }
    return null;
  }
}
