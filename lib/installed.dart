import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import 'catalog.dart';
import 'version.dart';

/// Cihazda kurulu bir uygulama.
class Installed {
  const Installed(this.version, {this.exe});
  final String version;

  /// Windows: çalıştırılacak dosyanın yolu (bulunabildiyse).
  final String? exe;
}

const _channel = MethodChannel('oa/center');

/// Kurulu OA uygulamalarını bulur: Windows'ta "Program ekle/kaldır" kayıtlarından,
/// Android'de paket adından. Dönen eşlemede yalnız kurulu olanlar bulunur (anahtar: uygulama kimliği).
///
/// [userOnly]: Windows'ta yalnız kullanıcının kendi kayıtlarına bakar (hızlı; kurulum beklenirken).
Future<Map<String, Installed>> readInstalled(List<OAApp> apps, {bool userOnly = false}) async {
  final out = <String, Installed>{};
  if (Platform.isWindows) {
    final entries = await _uninstallEntries(userOnly: userOnly);
    for (final app in apps) {
      final t = app.win;
      if (t == null) continue;
      for (final e in entries) {
        if (!e.matches(t)) continue;
        final v = e.values['displayversion'];
        if (v == null || v.isEmpty) continue;
        out[app.id] = Installed(v, exe: e.exePath(t));
        break;
      }
    }
  } else if (Platform.isAndroid) {
    for (final app in apps) {
      final t = app.android;
      if (t == null) continue;
      try {
        final v = await _channel.invokeMethod<String>('surum', {'paket': t.package});
        if (v != null && v.isNotEmpty) out[app.id] = Installed(v);
      } catch (_) {}
    }
  }
  // OA Labs Center'ın kendisi: çalışan sürüm.
  for (final app in apps) {
    if (app.self) out[app.id] = Installed(appVersion, exe: out[app.id]?.exe);
  }
  return out;
}

/// Kurulu uygulamayı açar.
Future<bool> launchApp(OAApp app, Installed info) async {
  try {
    if (Platform.isWindows) {
      final exe = info.exe;
      if (exe == null) return false;
      await Process.start(exe, const [], mode: ProcessStartMode.detached, workingDirectory: File(exe).parent.path);
      return true;
    }
    if (Platform.isAndroid && app.android != null) {
      return await _channel.invokeMethod<bool>('ac', {'paket': app.android!.package}) ?? false;
    }
  } catch (_) {}
  return false;
}

// ---------------------------------------------------------------- Windows kayıt defteri

class _RegEntry {
  _RegEntry(this.key);
  final String key;
  final values = <String, String>{};

  bool matches(WinTarget t) {
    if (t.key != null && key.toLowerCase() == t.key!.toLowerCase()) return true;
    final dn = t.displayName;
    if (dn == null) return false;
    final name = values['displayname'] ?? '';
    return name == dn || name.startsWith('$dn ');
  }

  String? exePath(WinTarget t) {
    // Kurulum programları simge yolunu "C:\...\uygulama.exe,0" biçiminde yazar.
    var icon = (values['displayicon'] ?? '').replaceAll('"', '').trim();
    icon = icon.replaceFirst(RegExp(r',\s*-?\d+$'), '');
    if (icon.toLowerCase().endsWith('.exe') && File(icon).existsSync()) return icon;
    final dir = (values['inno setup: app path'] ?? values['installlocation'] ?? '').replaceAll('"', '').trim();
    if (dir.isNotEmpty && t.exe != null) {
      final base = dir.replaceFirst(_trailingSlash, '');
      final p = '$base\\${t.exe}';
      if (File(p).existsSync()) return p;
    }
    return null;
  }
}

final _trailingSlash = RegExp(r'[\\/]+$');
final _valueLine =RegExp(r'^\s{4}(.+?)\s{4}(REG_[A-Z_]+)\s{4}(.*)$');

Future<List<_RegEntry>> _uninstallEntries({required bool userOnly}) async {
  const tail = r'Microsoft\Windows\CurrentVersion\Uninstall';
  final roots = [
    'HKCU\\Software\\$tail',
    if (!userOnly) ...['HKLM\\Software\\$tail', 'HKLM\\Software\\WOW6432Node\\$tail'],
  ];
  final results = await Future.wait(roots.map((root) async {
    try {
      // reg.exe çıktısı konsolun kod sayfasında gelir; anahtar adları ve sürümler ASCII olduğu için latin1 yeter.
      final r = await Process.run('reg', ['query', root, '/s'], stdoutEncoding: latin1, stderrEncoding: latin1);
      return r.exitCode == 0 ? r.stdout.toString() : '';
    } catch (_) {
      return '';
    }
  }));
  final list = <_RegEntry>[];
  for (final text in results) {
    _RegEntry? cur;
    for (final line in const LineSplitter().convert(text)) {
      if (line.startsWith('HKEY_')) {
        cur = _RegEntry(line.trim().split('\\').last);
        list.add(cur);
        continue;
      }
      final m = _valueLine.firstMatch(line);
      if (m != null && cur != null) cur.values[m.group(1)!.trim().toLowerCase()] = m.group(3)!.trim();
    }
  }
  return list;
}
