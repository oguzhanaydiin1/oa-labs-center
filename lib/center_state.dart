import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'account.dart';
import 'announcements.dart';
import 'catalog.dart';
import 'devices.dart';
import 'i18n.dart';
import 'installed.dart';
import 'installer.dart';
import 'releases.dart';
import 'settings.dart';
import 'version.dart';

/// Süren bir kurulum, güncelleme ya da kaldırma.
class Job {
  const Job(this.label, [this.progress]);
  final String label;

  /// 0..1; bilinmiyorsa null (belirsiz ilerleme çubuğu).
  final double? progress;
}

/// Yenilikler akışındaki bir sürüm.
class NewsItem {
  const NewsItem(this.app, this.release);
  final OAApp app;
  final Release release;
}

/// Uygulamanın durumu: katalog, kurulu sürümler, en yeni sürümler, süren işler,
/// duyurular ve bu cihaza gelen kurulum istekleri.
class CenterState extends ChangeNotifier {
  CenterState(this.account);
  final OAAccount account;

  /// Listelerde görünen uygulamalar (OA Labs Center'ın kendisi hariç).
  List<OAApp> apps = const [];
  Map<String, Installed> installed = {};
  final Map<String, ReleaseInfo> latest = {};
  final Map<String, Job> jobs = {};
  List<Announcement> announcements = const [];
  Set<int> dismissed = {};

  /// Android: bilgisayardan gelen ve kullanıcının onayını bekleyen kurulum istekleri.
  List<RemoteCommand> incoming = const [];

  /// İlk tarama bitmeden boş liste gösterilmesin.
  bool loading = true;
  bool checking = false;
  bool updatingAll = false;

  List<OAApp> get _all => [...apps, centerApp];

  OAApp? byId(String id) {
    for (final a in _all) {
      if (a.id == id) return a;
    }
    return null;
  }

  bool isInstalled(OAApp a) => installed.containsKey(a.id);

  bool hasUpdate(OAApp a) {
    final i = installed[a.id], l = latest[a.id];
    if (i == null || l == null) return false;
    if (a.self && appVersion == '0.0.0') return false; // geliştirme derlemesi
    return isNewer(l.version, i.version);
  }

  List<OAApp> get installedApps => apps.where(isInstalled).toList();
  List<OAApp> get updates => apps.where(hasUpdate).toList();
  bool get selfUpdate => hasUpdate(centerApp);
  List<Announcement> get visibleAnnouncements => announcements.where((a) => !dismissed.contains(a.id)).take(3).toList();

  /// Keşfet: bu cihaza kurulabilecek, henüz kurulu olmayan uygulamalar.
  List<OAApp> get available => apps.where((a) => !a.soon && a.onThisPlatform && !isInstalled(a)).toList();

  /// Keşfet: yakında çıkacaklar ve yalnız öbür platformda olanlar.
  List<OAApp> get others => apps.where((a) => a.soon || (!a.onThisPlatform && !isInstalled(a))).toList();

  /// Açılışta ve "Güncellemeleri denetle" ile: katalog, kurulu sürümler, en yeni sürümler, duyurular.
  Future<void> refresh({bool force = false}) async {
    if (checking) return;
    checking = true;
    notifyListeners();
    try {
      // Bir istek takılsa bile "Denetleniyor…" sonsuza kadar kalmasın.
      await _check(force).timeout(const Duration(seconds: 45));
    } catch (_) {
      // Ağ ya da kayıt okunamadıysa eldeki bilgi gösterilmeye devam eder.
    } finally {
      loading = false;
      checking = false;
      notifyListeners();
    }
    // Cihaz kaydı ve uzaktan kurulum istekleri denetimi bekletmesin (Windows'ta kurulum dakikalar sürebilir).
    unawaited(syncDevice());
  }

  Future<void> _check(bool force) async {
    {
      if (loading) apps = await Catalog.cached();
      installed = await readInstalled(_all);
      loading = false;
      notifyListeners();

      final remote = await Catalog.remote();
      if (remote != null) {
        apps = remote;
        installed = await readInstalled(_all);
      }
      final beta = Settings.i.beta;
      await Future.wait([
        ..._all.where((a) => !a.soon && a.onThisPlatform).map((a) async {
          final r = await Releases.latest(a, force: force, beta: beta);
          if (r != null) {
            latest[a.id] = r;
          } else {
            latest.remove(a.id);
          }
        }),
        () async {
          announcements = await Announcements.fetch();
          dismissed = await Announcements.dismissed();
        }(),
      ]);
    }
  }

  /// Yalnız kurulu sürümleri yeniden okur (Android'de kurulum ekranından dönünce).
  Future<void> refreshInstalled() async {
    if (loading || checking) return;
    try {
      installed = await readInstalled(_all);
      notifyListeners();
      await syncDevice();
    } catch (_) {}
  }

  Future<void> dismissAnnouncement(Announcement a) async {
    dismissed = {...dismissed, a.id};
    notifyListeners();
    await Announcements.dismiss(a.id);
  }

  // ---------------------------------------------------------------- Cihazlar ve uzaktan kurulum

  bool _syncing = false;

  /// Bu cihazı hesaba kaydeder ve bekleyen kurulum isteklerini alır.
  /// Windows'ta istekler hemen (sessiz) kurulur; Android'de kullanıcıya sorulur.
  /// Windows'ta kurulan uygulamaların adlarını döndürür (bildirim için).
  Future<List<String>> syncDevice() async {
    if (_syncing || !account.signedIn) return const [];
    _syncing = true;
    final done = <String>[];
    try {
      final cmds = await DeviceSync.sync(account, {for (final e in installed.entries) e.key: e.value.version});
      if (cmds == null) return const [];
      if (Platform.isAndroid) {
        incoming = cmds.where((c) {
          final a = byId(c.app);
          return a != null && a.android != null && !isInstalled(a);
        }).toList();
        // Zaten kurulu olanlar: isteği kapat.
        for (final c in cmds.where((c) => !incoming.contains(c))) {
          await DeviceSync.done(account, c.id, true);
        }
        notifyListeners();
        return const [];
      }
      for (final c in cmds) {
        final a = byId(c.app);
        if (a == null || a.win == null) {
          await DeviceSync.done(account, c.id, false);
          continue;
        }
        if (isInstalled(a) && !hasUpdate(a)) {
          await DeviceSync.done(account, c.id, true);
          continue;
        }
        final err = await install(a);
        await DeviceSync.done(account, c.id, err == null);
        if (err == null) done.add(a.name);
      }
      if (done.isNotEmpty) {
        await DeviceSync.sync(account, {for (final e in installed.entries) e.key: e.value.version});
      }
    } catch (_) {
    } finally {
      _syncing = false;
    }
    return done;
  }

  /// Android: bilgisayardan gelen isteği kur ya da reddet.
  Future<String?> answerIncoming(RemoteCommand c, bool accept) async {
    incoming = incoming.where((x) => x.id != c.id).toList();
    notifyListeners();
    if (!accept) {
      await DeviceSync.cancel(account, c.id);
      return null;
    }
    final a = byId(c.app);
    if (a == null) return null;
    final err = await install(a);
    await DeviceSync.done(account, c.id, err == null);
    return err;
  }

  // ---------------------------------------------------------------- Aç, kur, kaldır

  Future<bool> open(OAApp app) async {
    final i = installed[app.id];
    return i != null && await launchApp(app, i);
  }

  void _job(OAApp app, Job? j) {
    if (j == null) {
      jobs.remove(app.id);
    } else {
      jobs[app.id] = j;
    }
    notifyListeners();
  }

  /// Uygulamayı kurar ya da günceller. Hata olursa kullanıcıya gösterilecek metni döndürür.
  Future<String?> install(OAApp app) async {
    if (jobs.containsKey(app.id)) return null;
    _job(app, Job(t('Sürüm denetleniyor')));
    final rel = latest[app.id] ?? await Releases.latest(app, force: true, beta: Settings.i.beta);
    if (rel == null || rel.url.isEmpty) {
      _job(app, null);
      return t('{app} için sürüm bilgisi alınamadı. İnternet bağlantını kontrol et.', {'app': app.name});
    }
    latest[app.id] = rel;

    _job(app, Job(t('İndiriliyor'), 0));
    var shown = 0.0;
    final file = await downloadSetup(rel.url, '${rel.version}-${rel.fileName}', (v) {
      // Her parçada değil, yüzde bir ilerleyince yeniden çiz.
      if (v - shown >= 0.01 || v >= 1) {
        shown = v;
        _job(app, Job(t('İndiriliyor'), v));
      }
    });
    if (file == null) {
      _job(app, null);
      return t('{app} indirilemedi. Biraz sonra yeniden dene.', {'app': app.name});
    }

    if (Platform.isAndroid) {
      // Android her kurulumda kullanıcıdan onay ister; kurulum ekranı açılır, sonuç dönüşte okunur.
      final ok = await openApk(file);
      _job(app, null);
      return ok ? null : t('Kurulum ekranı açılamadı. Dosya indirildi ama kurulamadı.');
    }

    _job(app, Job(t('Kuruluyor')));
    final started = await runWindowsSetup(file, app.win?.silent ?? const []);
    if (!started) {
      _job(app, null);
      return t('{app} kurulumu başlatılamadı.', {'app': app.name});
    }
    if (app.self) {
      // Kurulum, OA Labs Center'ı kapatıp yeni sürümü kendisi açar.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      exit(0);
    }
    // Kurulum arka planda sürer; kayıttaki sürüm yenilenene kadar bekle (en çok 4 dakika).
    var done = false;
    for (var i = 0; i < 120 && !done; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        final now = (await readInstalled([app], userOnly: true))[app.id];
        if (now != null && !isNewer(rel.version, now.version)) {
          installed[app.id] = now;
          done = true;
        }
      } catch (_) {}
    }
    if (!done) {
      try {
        installed = await readInstalled(_all);
      } catch (_) {}
      done = installed[app.id] != null && !isNewer(rel.version, installed[app.id]!.version);
    }
    _job(app, null);
    return done ? null : t('{app} kurulumu tamamlanmadı ya da iptal edildi.', {'app': app.name});
  }

  /// Uygulamayı kaldırır. Hata olursa kullanıcıya gösterilecek metni döndürür.
  Future<String?> uninstall(OAApp app) async {
    final info = installed[app.id];
    if (info == null || app.self || jobs.containsKey(app.id)) return null;
    if (Platform.isAndroid) {
      // Sistemin kaldırma onayı açılır; sonuç, uygulamaya dönülünce okunur.
      final ok = await uninstallApp(app, info);
      return ok ? null : t('{app} kaldırılamadı.', {'app': app.name});
    }
    _job(app, Job(t('Kaldırılıyor')));
    await uninstallApp(app, info);
    // Inno Setup kaldırıcısı kendini geçici klasöre kopyalayıp oradan sürer; kayıt silinene kadar bekle.
    var gone = false;
    for (var i = 0; i < 45 && !gone; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      try {
        gone = !(await readInstalled([app])).containsKey(app.id);
      } catch (_) {}
    }
    if (gone) installed.remove(app.id);
    _job(app, null);
    await syncDevice();
    return gone ? null : t('{app} kaldırılamadı. Açıksa kapatıp yeniden dene.', {'app': app.name});
  }

  /// Bekleyen bütün güncellemeleri sırayla kurar. Hata metinlerini döndürür.
  Future<List<String>> updateAll() async {
    if (updatingAll) return const [];
    updatingAll = true;
    notifyListeners();
    final errors = <String>[];
    try {
      for (final app in updates) {
        final e = await install(app);
        if (e != null) errors.add(e);
        // Android'de aynı anda tek kurulum ekranı açılabilir; kalanlar için kullanıcı yeniden dokunur.
        if (Platform.isAndroid) break;
      }
    } finally {
      updatingAll = false;
      notifyListeners();
    }
    await syncDevice();
    return errors;
  }

  // ---------------------------------------------------------------- Yenilikler

  /// Bütün uygulamaların sürüm notları, en yeni önce.
  Future<List<NewsItem>> news({bool force = false}) async {
    final beta = Settings.i.beta;
    final lists = await Future.wait(_all.where((a) => a.repo != null).map((a) async {
      final rels = await Releases.list(a, force: force);
      return [
        for (final r in rels)
          if (!r.prerelease || beta) NewsItem(a, r),
      ];
    }));
    final out = lists.expand((x) => x).toList()
      ..sort((a, b) => (b.release.date ?? DateTime(2000)).compareTo(a.release.date ?? DateTime(2000)));
    return out.take(40).toList();
  }
}
