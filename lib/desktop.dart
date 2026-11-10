import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'catalog.dart';
import 'center_state.dart';
import 'installed.dart';

/// Windows: arka planda çalışma.
///
/// - Pencere kapatılınca (ayar açıksa) saat yanındaki simgeye iner, çalışmaya devam eder.
/// - Windows açılınca "--arka-plan" ile pencere göstermeden başlar.
/// - 6 saatte bir güncellemeleri denetler; yenisi çıkınca bildirim gösterir.
/// - "Güncellemeleri kendiliğinden kur" açıksa, o an açık olmayan uygulamaları kendisi günceller.
/// - Tek kopya: zaten açıkken yeniden başlatılırsa açık olan öne gelir.
class Desktop extends ChangeNotifier with WindowListener, TrayListener {
  Desktop._();
  static final Desktop i = Desktop._();

  static const _port = 47613; // tek kopya denetimi (yalnız 127.0.0.1)
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _runName = 'OALabsCenter';
  static const _interval = Duration(hours: 6);

  bool background = true;
  bool autoUpdate = false;
  CenterState? _state;
  SharedPreferences? _prefs;
  Timer? _timer;
  ServerSocket? _server;
  bool _notifyReady = false;

  /// Pencereyi öne getirince gösterilecek sekme (bildirime tıklanınca Ana sayfa).
  void Function(int tab)? onShowTab;

  /// Uygulama başlamadan önce çağrılır. Başka bir kopya zaten açıksa onu öne getirir ve false döner.
  Future<bool> init(List<String> args) async {
    if (!Platform.isWindows) return true;
    try {
      _server = await ServerSocket.bind(InternetAddress.loopbackIPv4, _port);
      _server!.listen((sock) {
        sock.listen((data) {
          if (String.fromCharCodes(data).trim() == 'goster') show();
        }, onError: (_) {}, cancelOnError: true);
      }, onError: (_) {});
    } on SocketException {
      // Bağlantı noktası kullanılıyor: büyük ihtimalle OA Labs Center zaten açık.
      try {
        final s = await Socket.connect(InternetAddress.loopbackIPv4, _port, timeout: const Duration(seconds: 2));
        s.write('goster\n');
        await s.flush();
        await s.close();
        return false;
      } catch (_) {
        // Başka bir program kullanıyor; tek kopya denetimi olmadan devam et.
      }
    }

    _prefs = await SharedPreferences.getInstance();
    background = _prefs!.getBool('arkaPlan') ?? true;
    autoUpdate = _prefs!.getBool('otoGuncelle') ?? false;

    await windowManager.ensureInitialized();
    await windowManager.setPreventClose(true);
    await windowManager.setMinimumSize(const Size(640, 520));
    windowManager.addListener(this);

    try {
      await trayManager.setIcon('assets/icon/tray.ico');
      await trayManager.setToolTip('OA Labs Center');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'OA Labs Center’ı aç'),
        MenuItem(key: 'check', label: 'Güncellemeleri denetle'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Çıkış'),
      ]));
      trayManager.addListener(this);
    } catch (_) {}

    try {
      await localNotifier.setup(appName: 'OA Labs Center', shortcutPolicy: ShortcutPolicy.requireCreate);
      _notifyReady = true;
    } catch (_) {}

    await _applyAutostart(background);
    if (args.contains('--arka-plan')) {
      WidgetsBinding.instance.addPostFrameCallback((_) => windowManager.hide());
    }
    return true;
  }

  /// Uygulamanın durumu hazır olunca: ilk denetimden sonra bildirim ve 6 saatlik zamanlayıcı.
  void attach(CenterState state) {
    if (!Platform.isWindows) return;
    _state = state;
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => check());
  }

  /// Güncellemeleri denetler; yenileri bildirir ya da (ayar açıksa) kurar.
  Future<void> check({bool force = true}) async {
    final s = _state;
    if (s == null) return;
    await s.refresh(force: force);
    await afterCheck();
  }

  /// Denetimden sonra: daha önce bildirilmemiş güncellemeleri bildir ya da kur.
  Future<void> afterCheck() async {
    final s = _state, p = _prefs;
    if (s == null || p == null) return;
    final pending = [...s.updates, if (s.selfUpdate) centerApp];
    final told = p.getStringList('bildirilen') ?? const <String>[];
    String tag(OAApp a) => '${a.id}@${s.latest[a.id]?.version}';
    final fresh = pending.where((a) => !told.contains(tag(a))).toList();
    if (fresh.isEmpty) return;
    await p.setStringList('bildirilen', {...told, ...fresh.map(tag)}.toList());

    if (autoUpdate) {
      final done = <String>[], left = <OAApp>[];
      for (final a in s.updates) {
        // Açık olan uygulama kurulum sırasında kapanırdı; onu kullanıcıya bırak.
        final exe = a.win?.exe;
        if (exe != null && await isRunning(exe)) {
          left.add(a);
          continue;
        }
        final err = await s.install(a);
        if (err == null) {
          done.add(a.name);
        } else {
          left.add(a);
        }
      }
      if (done.isNotEmpty) {
        await _notify('${done.length} uygulama güncellendi', done.join(', '));
      }
      if (left.isNotEmpty) {
        await _notify('${left.length} güncelleme seni bekliyor',
            '${left.map((a) => a.name).join(', ')}. Açık olduğu için kurulmadı; OA Labs Center’dan güncelleyebilirsin.');
      }
      // En son kendini günceller (kurulum OA Labs Center'ı kapatıp yeniden açar).
      if (s.selfUpdate) await s.install(centerApp);
      return;
    }

    final names = fresh.map((a) => '${a.name} ${s.latest[a.id]?.version ?? ''}'.trim()).join(', ');
    await _notify(fresh.length == 1 ? 'Güncelleme var' : '${fresh.length} güncelleme var', names);
  }

  Future<void> _notify(String title, String body) async {
    if (!_notifyReady) return;
    try {
      if (await windowManager.isVisible() && await windowManager.isFocused()) return; // ekranda zaten görünüyor
      final n = LocalNotification(title: title, body: body);
      n.onClick = () {
        show();
        onShowTab?.call(0);
      };
      await n.show();
    } catch (_) {}
  }

  Future<void> setBackground(bool v) async {
    background = v;
    await _prefs?.setBool('arkaPlan', v);
    await _applyAutostart(v);
    notifyListeners();
  }

  Future<void> setAutoUpdate(bool v) async {
    autoUpdate = v;
    await _prefs?.setBool('otoGuncelle', v);
    notifyListeners();
  }

  /// Windows açılınca başlat: kullanıcının "Run" kaydına yazar (yönetici izni gerekmez).
  Future<void> _applyAutostart(bool on) async {
    try {
      if (on) {
        await Process.run('reg',
            ['add', _runKey, '/v', _runName, '/t', 'REG_SZ', '/d', '"${Platform.resolvedExecutable}" --arka-plan', '/f']);
      } else {
        await Process.run('reg', ['delete', _runKey, '/v', _runName, '/f']);
      }
    } catch (_) {}
  }

  Future<void> show() async {
    try {
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }

  Future<void> quit() async {
    _timer?.cancel();
    try {
      await _server?.close();
      await trayManager.destroy();
      await windowManager.setPreventClose(false);
    } catch (_) {}
    exit(0);
  }

  @override
  void onWindowClose() async {
    if (!background) {
      await quit();
      return;
    }
    await windowManager.hide();
    final p = _prefs;
    if (p != null && p.getBool('tepsiIpucu') != true) {
      await p.setBool('tepsiIpucu', true);
      await _notify('OA Labs Center arka planda çalışıyor',
          'Güncellemeleri denetlemeye devam eder. Saat yanındaki simgeden açabilir ya da kapatabilirsin.');
    }
  }

  @override
  void onTrayIconMouseDown() => show();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        show();
      case 'check':
        check();
      case 'exit':
        quit();
    }
  }
}
