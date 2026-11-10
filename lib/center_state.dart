import 'dart:io';

import 'package:flutter/foundation.dart';

import 'catalog.dart';
import 'installed.dart';
import 'installer.dart';
import 'releases.dart';
import 'version.dart';

/// Süren bir kurulum ya da güncelleme.
class Job {
  const Job(this.label, [this.progress]);
  final String label;

  /// 0..1; bilinmiyorsa null (belirsiz ilerleme çubuğu).
  final double? progress;
}

/// Uygulamanın durumu: katalog, kurulu sürümler, en yeni sürümler ve süren işler.
class CenterState extends ChangeNotifier {
  /// Listelerde görünen uygulamalar (OA Labs Center'ın kendisi hariç).
  List<OAApp> apps = builtinCatalog;
  Map<String, Installed> installed = {};
  final Map<String, ReleaseInfo> latest = {};
  final Map<String, Job> jobs = {};

  /// İlk tarama bitmeden boş liste gösterilmesin.
  bool loading = true;
  bool checking = false;
  bool updatingAll = false;

  List<OAApp> get _all => [...apps, centerApp];

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

  /// Keşfet: bu cihaza kurulabilecek, henüz kurulu olmayan uygulamalar.
  List<OAApp> get available => apps.where((a) => !a.soon && a.onThisPlatform && !isInstalled(a)).toList();

  /// Keşfet: yakında çıkacaklar ve yalnız öbür platformda olanlar.
  List<OAApp> get others => apps.where((a) => a.soon || (!a.onThisPlatform && !isInstalled(a))).toList();

  /// Açılışta ve "Güncellemeleri denetle" ile: katalog, kurulu sürümler, en yeni sürümler.
  Future<void> refresh({bool force = false}) async {
    if (checking) return;
    checking = true;
    notifyListeners();
    try {
      if (loading) apps = await Catalog.cached();
      installed = await readInstalled(_all);
      loading = false;
      notifyListeners();

      final remote = await Catalog.remote();
      if (remote != null) {
        apps = remote;
        installed = await readInstalled(_all);
      }
      await Future.wait(_all.where((a) => !a.soon && a.onThisPlatform).map((a) async {
        final r = await Releases.latest(a, force: force);
        if (r != null) latest[a.id] = r;
      }));
    } catch (_) {
      // Ağ ya da kayıt okunamadıysa eldeki bilgi gösterilmeye devam eder.
    } finally {
      loading = false;
      checking = false;
      notifyListeners();
    }
  }

  /// Yalnız kurulu sürümleri yeniden okur (Android'de kurulum ekranından dönünce).
  Future<void> refreshInstalled() async {
    if (loading || checking) return;
    try {
      installed = await readInstalled(_all);
      notifyListeners();
    } catch (_) {}
  }

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
    _job(app, const Job('Sürüm denetleniyor'));
    final rel = latest[app.id] ?? await Releases.latest(app, force: true);
    if (rel == null || rel.url.isEmpty) {
      _job(app, null);
      return '${app.name} için sürüm bilgisi alınamadı. İnternet bağlantını kontrol et.';
    }
    latest[app.id] = rel;

    _job(app, const Job('İndiriliyor', 0));
    var shown = 0.0;
    final file = await downloadSetup(rel.url, '${rel.version}-${rel.fileName}', (v) {
      // Her parçada değil, yüzde bir ilerleyince yeniden çiz.
      if (v - shown >= 0.01 || v >= 1) {
        shown = v;
        _job(app, Job('İndiriliyor', v));
      }
    });
    if (file == null) {
      _job(app, null);
      return '${app.name} indirilemedi. Biraz sonra yeniden dene.';
    }

    if (Platform.isAndroid) {
      // Android her kurulumda kullanıcıdan onay ister; kurulum ekranı açılır, sonuç dönüşte okunur.
      final ok = await openApk(file);
      _job(app, null);
      return ok ? null : 'Kurulum ekranı açılamadı. Dosya indirildi ama kurulamadı.';
    }

    _job(app, const Job('Kuruluyor'));
    final started = await runWindowsSetup(file, app.win?.silent ?? const []);
    if (!started) {
      _job(app, null);
      return '${app.name} kurulumu başlatılamadı.';
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
    return done ? null : '${app.name} kurulumu tamamlanmadı ya da iptal edildi.';
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
    return errors;
  }
}
