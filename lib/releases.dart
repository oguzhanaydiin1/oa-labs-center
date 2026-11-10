import 'dart:convert';

import 'package:http/http.dart' as http;

import 'catalog.dart';
import 'version.dart';

/// Bir uygulamanın bu cihaza uygun en yeni sürüm dosyası.
class ReleaseInfo {
  const ReleaseInfo({required this.version, required this.url, required this.fileName, required this.size});
  final String version;
  final String url;
  final String fileName;
  final int size;
}

class _Hit {
  _Hit(this.at, this.info);
  final DateTime at;
  final ReleaseInfo? info;
}

/// GitHub'daki sürümlere bakar. Sonuç 10 dakika bellekte tutulur
/// (GitHub, girişsiz isteklere saatte 60 istek sınırı koyar).
class Releases {
  Releases._();
  static final _cache = <String, _Hit>{};

  /// [app] için bu platformdaki en yeni dosya. Bulunamazsa ya da ağ yoksa null.
  static Future<ReleaseInfo?> latest(OAApp app, {bool force = false}) async {
    final repo = app.repo, pattern = app.asset;
    if (repo == null || pattern == null) return null;
    final hit = _cache[app.id];
    if (!force && hit != null && DateTime.now().difference(hit.at) < const Duration(minutes: 10)) return hit.info;
    try {
      final r = await http.get(Uri.parse('https://api.github.com/repos/$repo/releases?per_page=8'), headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'OALabsCenter/$appVersion',
      }).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return hit?.info;
      final list = jsonDecode(utf8.decode(r.bodyBytes));
      if (list is! List) return hit?.info;
      final re = RegExp(pattern);
      ReleaseInfo? found;
      // Liste en yeniden eskiye gelir; bu platformun dosyasını taşıyan ilk sürüm alınır.
      outer:
      for (final rel in list.whereType<Map>()) {
        if (rel['draft'] == true) continue;
        final tag = (rel['tag_name'] ?? '').toString();
        for (final a in (rel['assets'] as List? ?? const []).whereType<Map>()) {
          final name = (a['name'] ?? '').toString();
          if (re.hasMatch(name)) {
            found = ReleaseInfo(
              version: tag.replaceFirst(RegExp(r'^v'), ''),
              url: (a['browser_download_url'] ?? '').toString(),
              fileName: name,
              size: a['size'] is int ? a['size'] as int : 0,
            );
            break outer;
          }
        }
      }
      _cache[app.id] = _Hit(DateTime.now(), found);
      return found;
    } catch (_) {
      return hit?.info;
    }
  }
}
