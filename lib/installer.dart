import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import 'version.dart';

/// Kurulum dosyalarının indirildiği klasör. Android'de kurulum ekranının dosyayı
/// okuyabilmesi için uygulamanın dış depolama klasörü kullanılır.
Future<Directory> _downloadDir() async {
  Directory base;
  if (Platform.isAndroid) {
    base = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
  } else {
    base = Directory.systemTemp;
  }
  final dir = Directory('${base.path}${Platform.pathSeparator}OALabsCenter');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  return dir;
}

/// [url] adresindeki dosyayı indirir ([onProgress] 0..1). Başarısız olursa null.
Future<File?> downloadSetup(String url, String fileName, void Function(double) onProgress) async {
  final client = http.Client();
  try {
    final dir = await _downloadDir();
    final safe = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final f = File('${dir.path}${Platform.pathSeparator}$safe');
    if (f.existsSync()) f.deleteSync();
    final res = await client
        .send(http.Request('GET', Uri.parse(url))..headers['User-Agent'] = 'OALabsCenter/$appVersion')
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) return null;
    final sink = f.openWrite();
    final total = res.contentLength ?? 0;
    var got = 0;
    try {
      // 60 saniye hiç veri gelmezse indirme bırakılır (bağlantı takıldıysa).
      await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
        sink.add(chunk);
        got += chunk.length;
        if (total > 0) onProgress(got / total);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && got != total) return null;
    return f;
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Windows: kurulum programını verilen (sessiz kurulum) parametreleriyle başlatır.
Future<bool> runWindowsSetup(File setup, List<String> args) async {
  try {
    await Process.start(setup.path, args, mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}

/// Android: indirilen APK için sistemin kurulum ekranını açar. Onayı kullanıcı verir.
Future<bool> openApk(File apk) async {
  try {
    final r = await OpenFilex.open(apk.path, type: 'application/vnd.android.package-archive');
    return r.type == ResultType.done;
  } catch (_) {
    return false;
  }
}
