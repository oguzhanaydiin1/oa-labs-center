import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'i18n.dart';
import 'version.dart';

/// Yönetim panelinden yayımlanan OA Labs duyurusu.
class Announcement {
  const Announcement({
    required this.id,
    required this.created,
    required this.title,
    required this.body,
    this.app,
    this.url,
  });
  final int id;
  final DateTime? created;
  final String title;
  final String body;
  final String? app;
  final String? url;

  static Announcement? fromJson(Object? j) {
    if (j is! Map || j['id'] is! int) return null;
    String pick(String k) {
      final en = (j['${k}_en'] ?? '').toString().trim();
      return L.en && en.isNotEmpty ? en : (j[k] ?? '').toString();
    }

    return Announcement(
      id: j['id'] as int,
      created: DateTime.tryParse((j['created'] ?? '').toString()),
      title: pick('title'),
      body: pick('body'),
      app: j['app'] as String?,
      url: j['url'] as String?,
    );
  }
}

class Announcements {
  Announcements._();
  static const _url = 'https://api.oalabs.dev/v1/announcements';

  /// Yayındaki duyurular (en yeni önce). Ağ yoksa boş.
  static Future<List<Announcement>> fetch() async {
    try {
      final r = await http
          .get(Uri.parse(_url), headers: {'User-Agent': 'OALabsCenter/$appVersion', 'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final j = jsonDecode(utf8.decode(r.bodyBytes));
      final list = j is Map ? j['announcements'] : null;
      if (list is! List) return const [];
      return list.map(Announcement.fromJson).whereType<Announcement>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// Kullanıcının kapattığı duyurular.
  static Future<Set<int>> dismissed() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList('kapatilanDuyurular') ?? const []).map(int.tryParse).whereType<int>().toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> dismiss(int id) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = {...(p.getStringList('kapatilanDuyurular') ?? const <String>[]), '$id'};
      await p.setStringList('kapatilanDuyurular', s.toList());
    } catch (_) {}
  }

  /// Bildirimi gösterilmiş duyurular (aynı duyuru iki kez bildirilmesin).
  static Future<bool> markNotified(int id) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getStringList('bildirilenDuyurular') ?? const <String>[];
      if (s.contains('$id')) return false;
      await p.setStringList('bildirilenDuyurular', [...s, '$id']);
      return true;
    } catch (_) {
      return false;
    }
  }
}
