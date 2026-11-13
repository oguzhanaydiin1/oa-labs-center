import 'dart:ffi';
import 'dart:io';

typedef _GetCurrentProcessN = IntPtr Function();
typedef _GetCurrentProcessD = int Function();
typedef _TerminateProcessN = Int32 Function(IntPtr, Uint32);
typedef _TerminateProcessD = int Function(int, int);

/// Kapanış adımlarını %TEMP%\oa-center-kapanis.log dosyasına yazar.
/// Kapanma sorunu yaşanırsa bu dosya neyin takıldığını gösterir.
void kapanisGunlugu(String adim) {
  if (!Platform.isWindows) return;
  try {
    final f = File('${Directory.systemTemp.path}${Platform.pathSeparator}oa-center-kapanis.log');
    f.writeAsStringSync('${DateTime.now().toIso8601String()} $adim\n',
        mode: adim == 'basladi' ? FileMode.write : FileMode.append, flush: true);
  } catch (_) {}
}

/// Süreci hemen sonlandırır. Windows'ta dart:io `exit` motor ve eklentiler
/// kapanırken takılabildiği için doğrudan TerminateProcess kullanılır;
/// Windows tüm pencereleri, fare yakalamasını ve kaynakları kendisi bırakır.
Never hemenKapat([int kod = 0]) {
  kapanisGunlugu('sonlandiriliyor');
  if (Platform.isWindows) {
    try {
      final k = DynamicLibrary.open('kernel32.dll');
      final cur = k.lookupFunction<_GetCurrentProcessN, _GetCurrentProcessD>('GetCurrentProcess');
      final term = k.lookupFunction<_TerminateProcessN, _TerminateProcessD>('TerminateProcess');
      term(cur(), kod);
    } catch (_) {}
  }
  exit(kod);
}
