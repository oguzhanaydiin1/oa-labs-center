import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

/// OA uygulamalarının Windows'ta ortak kullandığı oturum: tek giriş.
///
/// Bir OA uygulamasında giriş yapılınca oturum anahtarı Windows'un kullanıcıya özel şifrelemesiyle
/// (DPAPI) `%LOCALAPPDATA%\OA Labs\oturum.dat` dosyasına yazılır. Girişsiz açılan öbür OA uygulaması
/// bu anahtarla sunucudan tek kullanımlık bir kod alır (/v1/auth/handoff) ve kendi oturumunu açar
/// (/v1/auth/redeem). Böylece her uygulamanın ayrı oturumu olur; anahtarı yalnız aynı Windows
/// kullanıcısı çözebilir. Aynı dosya OA Labs Center'da ve Pusula'da birebir aynıdır.
class SharedSession {
  SharedSession._();

  static bool get supported => Platform.isWindows;

  static File? get _file {
    final base = Platform.environment['LOCALAPPDATA'];
    if (base == null || base.isEmpty) return null;
    return File('$base\\OA Labs\\oturum.dat');
  }

  /// Ortak oturum: anahtar ve onu yazan uygulama. Yoksa ya da çözülemezse null.
  static Future<({String token, String app})?> read() async {
    if (!supported) return null;
    try {
      final f = _file;
      if (f == null || !f.existsSync()) return null;
      final plain = _dpapi(await f.readAsBytes(), protect: false);
      if (plain == null) return null;
      final j = jsonDecode(utf8.decode(plain));
      if (j is! Map) return null;
      final token = (j['token'] ?? '').toString();
      if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(token)) return null;
      return (token: token, app: (j['app'] ?? '').toString());
    } catch (_) {
      return null;
    }
  }

  static Future<void> write(String token, String app) async {
    if (!supported) return;
    try {
      final f = _file;
      if (f == null) return;
      final data = utf8.encode(jsonEncode({'token': token, 'app': app, 'at': DateTime.now().toUtc().toIso8601String()}));
      final enc = _dpapi(Uint8List.fromList(data), protect: true);
      if (enc == null) return;
      await f.parent.create(recursive: true);
      await f.writeAsBytes(enc, flush: true);
    } catch (_) {}
  }

  /// Ortak oturum [token] ise siler (çıkış yapan uygulama yalnız kendi anahtarını kaldırır).
  static Future<void> clearIf(String? token) async {
    if (!supported || token == null) return;
    try {
      final cur = await read();
      if (cur != null && cur.token == token) await _file?.delete();
    } catch (_) {}
  }
}

// ---------------------------------------------------------------- DPAPI (crypt32.dll)

final class _Blob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _ProtectNative = Int32 Function(
    Pointer<_Blob>, Pointer<Utf16>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Blob>);
typedef _ProtectDart = int Function(
    Pointer<_Blob>, Pointer<Utf16>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, int, Pointer<_Blob>);
typedef _UnprotectNative = Int32 Function(
    Pointer<_Blob>, Pointer<Pointer<Utf16>>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, Uint32, Pointer<_Blob>);
typedef _UnprotectDart = int Function(
    Pointer<_Blob>, Pointer<Pointer<Utf16>>, Pointer<_Blob>, Pointer<Void>, Pointer<Void>, int, Pointer<_Blob>);
typedef _LocalFreeNative = Pointer<Void> Function(Pointer<Void>);
typedef _LocalFreeDart = Pointer<Void> Function(Pointer<Void>);

const _uiForbidden = 0x1; // CRYPTPROTECT_UI_FORBIDDEN
final _entropyText = utf8.encode('OA Labs ortak oturum v1');

Uint8List? _dpapi(Uint8List data, {required bool protect}) {
  if (data.isEmpty) return null;
  final crypt32 = DynamicLibrary.open('crypt32.dll');
  final kernel32 = DynamicLibrary.open('kernel32.dll');
  final localFree = kernel32.lookupFunction<_LocalFreeNative, _LocalFreeDart>('LocalFree');

  final input = calloc<_Blob>();
  final entropy = calloc<_Blob>();
  final output = calloc<_Blob>();
  final inBuf = calloc<Uint8>(data.length);
  final entBuf = calloc<Uint8>(_entropyText.length);
  try {
    inBuf.asTypedList(data.length).setAll(0, data);
    entBuf.asTypedList(_entropyText.length).setAll(0, _entropyText);
    input.ref
      ..cbData = data.length
      ..pbData = inBuf;
    entropy.ref
      ..cbData = _entropyText.length
      ..pbData = entBuf;

    final int ok;
    if (protect) {
      final f = crypt32.lookupFunction<_ProtectNative, _ProtectDart>('CryptProtectData');
      ok = f(input, nullptr, entropy, nullptr, nullptr, _uiForbidden, output);
    } else {
      final f = crypt32.lookupFunction<_UnprotectNative, _UnprotectDart>('CryptUnprotectData');
      ok = f(input, nullptr, entropy, nullptr, nullptr, _uiForbidden, output);
    }
    if (ok == 0 || output.ref.pbData == nullptr) return null;
    final out = Uint8List.fromList(output.ref.pbData.asTypedList(output.ref.cbData));
    localFree(output.ref.pbData.cast());
    return out;
  } catch (_) {
    return null;
  } finally {
    calloc.free(input);
    calloc.free(entropy);
    calloc.free(output);
    calloc.free(inBuf);
    calloc.free(entBuf);
  }
}
