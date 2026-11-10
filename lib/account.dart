import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'version.dart';

/// OA Labs üyeliği (oalabs.dev ile aynı hesap).
///
/// Sunucu: api.oalabs.dev. Giriş şifresiz: e-postaya 6 haneli kod gider, doğrulanınca sunucu
/// `oa_s` oturum çerezini verir. Uygulama bu çerezi cihazın güvenli deposunda saklar ve
/// isteklerde `Cookie` başlığıyla gönderir.
class OAUser {
  const OAUser({required this.name, required this.email, this.notify = const <String>{}});
  final String name;
  final String email;

  /// Çıkınca haber verilmesi istenen uygulamaların kimlikleri (örn. "score").
  final Set<String> notify;

  String get initial => name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();

  static OAUser? fromJson(Object? j) {
    if (j is! Map) return null;
    return OAUser(
      name: (j['name'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      notify: (j['notify'] as List? ?? const []).map((e) => e.toString()).toSet(),
    );
  }
}

/// Hesaba bağlı bir oturum (cihaz).
class OASession {
  const OASession({required this.id, required this.device, required this.lastSeen, required this.current});
  final String id;
  final String device;
  final DateTime? lastSeen;
  final bool current;

  static OASession? fromJson(Object? j) {
    if (j is! Map) return null;
    return OASession(
      id: (j['id'] ?? '').toString(),
      device: (j['device'] ?? 'Bilinmeyen cihaz').toString(),
      lastSeen: DateTime.tryParse((j['lastSeen'] ?? '').toString()),
      current: j['current'] == true,
    );
  }
}

/// Sunucunun hata kodları için sitedeki metinlerin aynısı.
const _errors = <String, String>{
  'eposta': 'Bu e-posta adresi geçerli görünmüyor.',
  'uye-yok': 'Bu e-postayla bir üyelik bulamadık. Önce oalabs.dev üzerinden üye ol.',
  'bekle': 'Az önce bir kod gönderdik. Bir dakika sonra yeniden isteyebilirsin.',
  'cok': 'Çok fazla deneme oldu, biraz sonra tekrar dene.',
  'kod': 'Kod yanlış. E-postadaki 6 haneli kodu kontrol et.',
  'sure': 'Kodun süresi doldu. Yeni bir kod iste.',
  'deneme': 'Çok fazla yanlış deneme oldu. Yeni bir kod iste.',
  'kapali': 'Üyelik çok yakında açılıyor. Biraz sonra tekrar dene.',
  'gonderilemedi': 'E-posta gönderilemedi, biraz sonra tekrar dene.',
  'giris': 'Oturumun kapanmış. Yeniden giriş yap.',
  'ag': 'Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.',
};

String accountError(String? code) => _errors[code] ?? 'Bir sorun çıktı, biraz sonra tekrar dene.';

class OAAccount extends ChangeNotifier {
  static const api = 'https://api.oalabs.dev';
  static const _cookieName = 'oa_s';
  static const _storeKey = 'oa_session';

  final _store = const FlutterSecureStorage();

  String? _token;
  OAUser? user;
  List<OASession> sessions = const [];
  bool loading = true;

  bool get signedIn => user != null;

  /// Sunucu, oturum listesindeki cihaz adını bu bilgiden çıkarır (Windows / Android).
  String get _userAgent {
    final os = Platform.isAndroid
        ? 'Linux; Android'
        : Platform.isWindows
            ? 'Windows NT 10.0'
            : Platform.operatingSystem;
    return 'OALabsCenter/$appVersion ($os)';
  }

  Map<String, String> _headers({bool json = false}) => {
        'User-Agent': _userAgent,
        'Accept': 'application/json',
        if (json) 'Content-Type': 'application/json',
        if (_token != null) 'Cookie': '$_cookieName=$_token',
      };

  Future<void> load() async {
    try {
      _token = await _store.read(key: _storeKey);
    } catch (_) {
      _token = null;
    }
    if (_token != null) await refresh(notify: false);
    loading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _call(String path, [Map<String, dynamic>? body]) async {
    try {
      final uri = Uri.parse('$api$path');
      final res = body == null
          ? await http.get(uri, headers: _headers()).timeout(const Duration(seconds: 12))
          : await http
              .post(uri, headers: _headers(json: true), body: jsonEncode({'lang': 'tr', ...body}))
              .timeout(const Duration(seconds: 12));
      _readCookie(res.headers['set-cookie']);
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return data is Map<String, dynamic> ? data : {'ok': false, 'error': 'sunucu'};
    } catch (_) {
      return {'ok': false, 'error': 'ag'};
    }
  }

  void _readCookie(String? header) {
    if (header == null) return;
    final m = RegExp('$_cookieName=([0-9a-f]{64})?').firstMatch(header);
    if (m == null) return;
    _token = m.group(1); // boş değer: sunucu oturumu kapattı
    _persist();
  }

  Future<void> _persist() async {
    try {
      if (_token == null) {
        await _store.delete(key: _storeKey);
      } else {
        await _store.write(key: _storeKey, value: _token);
      }
    } catch (_) {}
  }

  /// 1. adım: e-postaya giriş kodu gönder. Dönen değer hata kodu (başarılıysa null).
  Future<String?> start(String email) async {
    final r = await _call('/v1/auth/start', {
      'mode': 'login',
      'email': email.trim(),
      'website': '', // sitedeki bot tuzağı alanı; insanlar boş bırakır
    });
    return r['ok'] == true ? null : (r['error']?.toString() ?? 'sunucu');
  }

  /// 2. adım: kodu doğrula; başarılıysa oturum açılır. Dönen değer hata kodu (başarılıysa null).
  Future<String?> verify(String email, String code) async {
    final r = await _call('/v1/auth/verify', {'email': email.trim(), 'code': code.trim()});
    if (r['ok'] != true) return r['error']?.toString() ?? 'sunucu';
    await refresh();
    return null;
  }

  Future<void> refresh({bool notify = true}) async {
    if (_token == null) {
      user = null;
      sessions = const [];
    } else {
      final r = await _call('/v1/me');
      if (r['ok'] == true) {
        user = OAUser.fromJson(r['user']);
        await _loadSessions();
      } else if (r['error'] == 'giris') {
        // Oturum sunucuda kapanmış (süresi dolmuş ya da başka cihazdan kapatılmış).
        _token = null;
        user = null;
        sessions = const [];
        await _persist();
      }
    }
    if (notify) notifyListeners();
  }

  Future<void> _loadSessions([Map<String, dynamic>? body]) async {
    final r = await _call('/v1/me/sessions', body);
    if (r['ok'] == true && r['sessions'] is List) {
      sessions = (r['sessions'] as List).map(OASession.fromJson).whereType<OASession>().toList();
    }
  }

  /// "Çıkınca haber ver": yakında çıkacak bir uygulama için e-posta bildirimi aç ya da kapat.
  Future<bool> setNotify(String appId, bool on) async {
    if (_token == null) return false;
    final r = await _call('/v1/me', {
      'notify': {appId: on},
    });
    if (r['ok'] != true) return false;
    user = OAUser.fromJson(r['user']) ?? user;
    notifyListeners();
    return true;
  }

  /// Başka bir cihazdaki oturumu kapatır.
  Future<void> dropSession(OASession s) async {
    await _loadSessions({'id': s.id});
    notifyListeners();
  }

  Future<void> logout() async {
    if (_token != null) await _call('/v1/auth/logout', {});
    _token = null;
    user = null;
    sessions = const [];
    await _persist();
    notifyListeners();
  }
}
