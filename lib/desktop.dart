import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'announcements.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'kapat.dart';
import 'i18n.dart';
import 'installed.dart';

/// Windows: arka planda çalışma.
///
/// - Pencere kapatılınca (ayar açıksa) saat yanındaki simgeye iner, çalışmaya devam eder.
/// - Windows açılınca "--arka-plan" ile pencere göstermeden başlar.
/// - 6 saatte bir güncellemeleri denetler; yenisi çıkınca bildirim gösterir.
/// - "Güncellemeleri kendiliğinden kur" açıksa, o an açık olmayan uygulamaları kendisi günceller.
/// - 15 dakikada bir hesabın öbür cihazlarından gelen kurulum isteklerine bakar ve kurar.
/// - Yeni OA Labs duyurularını bildirir.
/// - Tek kopya: zaten açıkken yeniden başlatılırsa açık olan öne gelir.
class Desktop extends ChangeNotifier with WindowListener, TrayListener {
  Desktop._();
  static final Desktop i = Desktop._();

  static const _port = 47613; // tek kopya denetimi (yalnız 127.0.0.1)
  static const _runKey = r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _runName = 'OALabsCenter';
  static const _interval = Duration(hours: 6);
  static const _remoteInterval = Duration(minutes: 15);

  bool background = true;
  bool autoUpdate = false;
  CenterState? _state;
  SharedPreferences? _prefs;
  Timer? _timer;
  Timer? _remoteTimer;
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
        MenuItem(key: 'show', label: t('OA Labs Center’ı aç')),
        MenuItem(key: 'check', label: t('Güncellemeleri denetle')),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: t('Çıkış')),
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
    _remoteTimer?.cancel();
    _remoteTimer = Timer.periodic(_remoteInterval, (_) => remote());
  }

  /// Öbür cihazdan gelen kurulum isteklerini alır ve kurar (CenterState.syncDevice).
  Future<void> remote() async {
    final s = _state;
    if (s == null) return;
    final done = await s.syncDevice();
    if (done.isNotEmpty) {
      await _notify(t('Öbür cihazından istenen kuruldu'), done.join(', '), always: true);
    }
  }

  /// Güncellemeleri denetler; yenileri bildirir ya da (ayar açıksa) kurar.
  Future<void> check({bool force = true}) async {
    final s = _state;
    if (s == null) return;
    await s.refresh(force: force);
    await afterCheck();
  }

  /// Denetimden sonra: yeni duyuruları ve daha önce bildirilmemiş güncellemeleri bildir ya da kur.
  Future<void> afterCheck() async {
    final s = _state, p = _prefs;
    if (s == null || p == null) return;
    // Duyurular: ilk açılışta eskileri bildirmeden işaretle.
    final first = !p.containsKey('bildirilenDuyurular');
    for (final a in s.announcements.reversed) {
      if (await Announcements.markNotified(a.id) && !first) await _notify(a.title, a.body);
    }
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
        await _notify(t('{n} uygulama güncellendi', {'n': done.length}), done.join(', '));
      }
      if (left.isNotEmpty) {
        await _notify(t('{n} güncelleme seni bekliyor', {'n': left.length}),
            t('{names}. Açık olduğu için kurulmadı; OA Labs Center’dan güncelleyebilirsin.', {'names': left.map((a) => a.name).join(', ')}));
      }
      // En son kendini günceller (kurulum OA Labs Center'ı kapatıp yeniden açar).
      if (s.selfUpdate) await s.install(centerApp);
      return;
    }

    final names = fresh.map((a) => '${a.name} ${s.latest[a.id]?.version ?? ''}'.trim()).join(', ');
    await _notify(fresh.length == 1 ? t('Güncelleme var') : t('{n} güncelleme var', {'n': fresh.length}), names);
  }

  Future<void> _notify(String title, String body, {bool always = false}) async {
    if (!_notifyReady) return;
    try {
      // Ekranda zaten görünüyorsa bildirim gereksiz.
      if (!always && await windowManager.isVisible() && await windowManager.isFocused()) return;
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

  bool _quitting = false;

  /// Uygulamayı kapatır. Tepsi menüsünden çağrıldığında Windows'un menü döngüsü
  /// bitmeden pencereyi yıkmamak için önce kısa bir süre bekler; hiçbir adım
  /// takılırsa birkaç saniye sonra süreç zorla kapanır.
  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    kapanisGunlugu('basladi');
    // Ne olursa olsun 3 saniye içinde süreç kapanır; ekran asla donuk kalmaz.
    Timer(const Duration(seconds: 3), () => hemenKapat());
    _timer?.cancel();
    _remoteTimer?.cancel();
    Future<void> adim(String ad, Future<void> Function() f) async {
      kapanisGunlugu(ad);
      try {
        await f().timeout(const Duration(milliseconds: 800));
      } catch (e) {
        kapanisGunlugu('$ad hata: $e');
      }
    }

    await adim('pencere gizleniyor', () async => windowManager.hide());
    await adim('sunucu kapaniyor', () async => _server?.close());
    trayManager.removeListener(this);
    // Simge kaldırılmazsa görev çubuğunda fare üstüne gelene kadar kalır.
    await adim('simge kaldiriliyor', () => trayManager.destroy());
    hemenKapat();
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
      await _notify(t('OA Labs Center arka planda çalışıyor'),
          t('Güncellemeleri denetlemeye devam eder. Saat yanındaki simgeden açabilir ya da kapatabilirsin.'));
    }
  }

  @override
  void onTrayIconMouseDown() => show();

  @override
  void onTrayIconRightMouseDown() async {
    // Menü açılmadan önce pencere öne alınmazsa Windows menüyü kapatamaz ve
    // fare menüde takılı kalır; görünmez pencereyi öne almak için focus yeter.
    try {
      await trayManager.popUpContextMenu(bringAppToFront: true);
    } catch (_) {
      try {
        await trayManager.popUpContextMenu();
      } catch (_) {}
    }
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        show();
      case 'check':
        check();
      case 'exit':
        // Menü kapanıp Windows fareyi bırakana kadar bekle, sonra kapat.
        Future<void>.delayed(const Duration(milliseconds: 250), quit);
    }
  }
}
