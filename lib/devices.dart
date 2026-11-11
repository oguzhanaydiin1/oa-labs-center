import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account.dart';
import 'i18n.dart';

/// Başka bir cihazdan gelen "şu uygulamayı kur" isteği.
class RemoteCommand {
  const RemoteCommand({required this.id, required this.app, required this.created, this.state = 'pending', this.from});
  final int id;
  final String app;
  final DateTime? created;

  /// pending, done, failed ya da cancelled.
  final String state;
  final String? from;

  static RemoteCommand? fromJson(Object? j) {
    if (j is! Map || j['id'] is! int || j['app'] is! String) return null;
    return RemoteCommand(
      id: j['id'] as int,
      app: j['app'] as String,
      created: DateTime.tryParse((j['created'] ?? '').toString()),
      state: (j['state'] ?? 'pending').toString(),
      from: j['from_device'] as String?,
    );
  }
}

/// Hesaba bağlı bir cihaz ve üzerindeki OA uygulamaları.
class OADevice {
  const OADevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.apps,
    required this.updated,
    required this.commands,
  });
  final String id;
  final String name;

  /// "windows" ya da "android".
  final String platform;

  /// Uygulama kimliği → sürüm.
  final Map<String, String> apps;
  final DateTime? updated;
  final List<RemoteCommand> commands;

  bool get isWindows => platform == 'windows';

  static OADevice? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String) return null;
    final apps = <String, String>{};
    for (final a in (j['apps'] as List? ?? const []).whereType<Map>()) {
      if (a['id'] is String) apps[a['id'] as String] = (a['version'] ?? '').toString();
    }
    return OADevice(
      id: j['id'] as String,
      name: (j['name'] ?? '').toString(),
      platform: (j['platform'] ?? '').toString(),
      apps: apps,
      updated: DateTime.tryParse((j['updated'] ?? '').toString()),
      commands: (j['commands'] as List? ?? const []).map(RemoteCommand.fromJson).whereType<RemoteCommand>().toList(),
    );
  }
}

/// Bu cihazın kimliği ve hesapla eşitlenmesi.
class DeviceSync {
  DeviceSync._();
  static const _ch = MethodChannel('oa/center');
  static String? _id;
  static String? _name;

  static String get platform => Platform.isWindows ? 'windows' : 'android';

  /// Bu kuruluma özel rastgele kimlik (ilk açılışta üretilir).
  static Future<String> id() async {
    if (_id != null) return _id!;
    final p = await SharedPreferences.getInstance();
    var v = p.getString('cihazKimligi');
    if (v == null || !RegExp(r'^[0-9a-f]{32}$').hasMatch(v)) {
      final r = Random.secure();
      v = List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await p.setString('cihazKimligi', v);
    }
    return _id = v;
  }

  /// Cihazın adı: Windows'ta bilgisayar adı, Android'de üretici ve model.
  static Future<String> name() async {
    if (_name != null) return _name!;
    var n = '';
    try {
      if (Platform.isAndroid) {
        n = await _ch.invokeMethod<String>('cihazAdi') ?? '';
      } else {
        n = Platform.environment['COMPUTERNAME'] ?? Platform.localHostname;
      }
    } catch (_) {}
    if (n.trim().isEmpty) n = Platform.isWindows ? t('Bilgisayar') : t('Telefon');
    return _name = n.trim();
  }

  /// Bu cihazı ve kurulu uygulamalarını kaydeder; bu cihaza bekleyen istekleri döndürür.
  static Future<List<RemoteCommand>?> sync(OAAccount account, Map<String, String> installed) async {
    if (!account.signedIn) return null;
    final r = await account.api('/v1/me/devices/sync', {
      'id': await id(),
      'name': await name(),
      'platform': platform,
      'apps': [for (final e in installed.entries) {'id': e.key, 'version': e.value}],
    });
    if (r['ok'] != true) return null;
    return (r['commands'] as List? ?? const []).map(RemoteCommand.fromJson).whereType<RemoteCommand>().toList();
  }

  static Future<List<OADevice>?> list(OAAccount account) async {
    if (!account.signedIn) return null;
    final r = await account.api('/v1/me/devices');
    if (r['ok'] != true) return null;
    return (r['devices'] as List? ?? const []).map(OADevice.fromJson).whereType<OADevice>().toList();
  }

  static Future<bool> send(OAAccount account, String deviceId, String app) async {
    final r = await account.api('/v1/me/commands', {'device': deviceId, 'app': app, 'from': await id()});
    return r['ok'] == true;
  }

  static Future<void> done(OAAccount account, int commandId, bool ok) async {
    await account.api('/v1/me/commands/done', {'id': commandId, 'ok': ok});
  }

  static Future<void> cancel(OAAccount account, int commandId) async {
    await account.api('/v1/me/commands/cancel', {'id': commandId});
  }

  static Future<bool> remove(OAAccount account, String deviceId) async {
    final r = await account.api('/v1/me/devices/remove', {'id': deviceId});
    return r['ok'] == true;
  }
}
