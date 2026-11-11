import 'package:flutter/material.dart';

import 'account.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'releases.dart';
import 'widgets.dart';

void openAppPage(BuildContext context, CenterState state, OAAccount account, OAApp app) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AppPage(state: state, account: account, app: app)));
}

/// Sürüm notunu düz metne çevirir: Markdown başlık ve kalın işaretleri atılır, boş satırlar sadeleşir.
String plainNotes(String s) {
  final lines = s
      .replaceAll('\r', '')
      .split('\n')
      .map((l) => l.replaceFirst(RegExp(r'^#{1,6}\s*'), '').replaceAll('**', '').replaceFirst(RegExp(r'^\s*[-*]\s+'), '• ').trimRight())
      .toList();
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Uygulama sayfası: tanıtım, özellikler, ekran görüntüleri, sürüm bilgisi ve geçmişi; Kur / Aç / Güncelle / Kaldır.
class AppPage extends StatefulWidget {
  const AppPage({super.key, required this.state, required this.account, required this.app});
  final CenterState state;
  final OAAccount account;
  final OAApp app;

  @override
  State<AppPage> createState() => _AppPageState();
}

class _AppPageState extends State<AppPage> {
  List<Release>? _history;

  @override
  void initState() {
    super.initState();
    Releases.list(widget.app).then((r) {
      if (mounted) setState(() => _history = r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: OA.bg,
        surfaceTintColor: OA.bg,
        title: Text(app.name, style: oaDisplay(20)),
        leading: IconButton(
          tooltip: t('Geri'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([widget.state, widget.account]),
        builder: (context, _) => LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 760;
          return PageFrame(wide: wide, children: [
            _header(context),
            _actions(context),
            if (app.shots.isNotEmpty) _shots(),
            if (app.localFeatures.isNotEmpty) _features(),
            _info(),
            if (!app.soon) _historyCard(),
          ]);
        }),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final app = widget.app;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppIcon(app, size: 76),
      const SizedBox(width: 18),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(app.name, style: oaDisplay(30)),
            if (app.soon) OAChip(t('Yakında'), ink: OA.soonInk, bg: OA.soonBg),
            if (app.beta) OAChip(t('Beta'), ink: OA.betaInk, bg: OA.betaBg),
            if (app.onlyOn != null) OAChip(t('Yalnız {p}', {'p': app.onlyOn})),
          ]),
          const SizedBox(height: 6),
          Text(app.localTagline, style: oaBody(17, color: OA.text2)),
        ]),
      ),
    ]);
  }

  Widget _actions(BuildContext context) {
    final s = widget.state, app = widget.app;
    final job = s.jobs[app.id];
    final installed = s.isInstalled(app);
    final up = s.hasUpdate(app);
    final buttons = <Widget>[];

    if (job != null) {
      final p = job.progress;
      return OACard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p != null ? '${job.label} · %${(p * 100).round()}' : '${job.label}…', style: oaBody(15, color: OA.text2)),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: p, minHeight: 6)),
        ]),
      );
    }
    if (app.soon) {
      final on = widget.account.user?.notify.contains(app.id) ?? false;
      buttons.add(OAButton(
        on ? t('Haber vereceğiz · Vazgeç') : t('Çıkınca haber ver'),
        kind: on ? OAButtonKind.secondary : OAButtonKind.primary,
        big: true,
        onPressed: () => toggleNotify(context, widget.account, app),
      ));
    } else if (installed) {
      if (up) buttons.add(OAButton(t('Güncelle'), kind: OAButtonKind.primary, big: true, onPressed: () => runInstall(context, s, app)));
      buttons.add(OAButton(t('Aç'), big: true, kind: up ? OAButtonKind.secondary : OAButtonKind.primary, onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        if (!await s.open(app)) {
          messenger.showSnackBar(SnackBar(content: Text(t('{app} açılamadı.', {'app': app.name}))));
        }
      }));
      if (!app.self) {
        buttons.add(OAButton(t('Kaldır'), kind: OAButtonKind.danger, big: true, onPressed: () => runUninstall(context, s, app)));
      }
    } else if (app.onThisPlatform) {
      buttons.add(OAButton(t('Kur'), kind: OAButtonKind.primary, big: true, onPressed: () => runInstall(context, s, app)));
    }
    buttons.add(OAButton(t('Web sayfası'), big: true, onPressed: () => openLink(app.localPage)));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: buttons),
      if (app.onlyOn != null) ...[
        const SizedBox(height: 10),
        Text(t('{p} sürümünü o cihazdaki OA Labs Center’dan kurabilirsin; Cihazlarım sayfasından uzaktan da kurdurabilirsin.', {'p': app.onlyOn}),
            style: oaBody(13, color: OA.muted)),
      ],
    ]);
  }

  Widget _shots() => SizedBox(
        height: 260,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: widget.app.shots.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              color: OA.surface,
              child: Image.network(
                widget.app.shots[i],
                height: 260,
                fit: BoxFit.contain,
                semanticLabel: t('{app} ekran görüntüsü {n}', {'app': widget.app.name, 'n': i + 1}),
                errorBuilder: (_, __, ___) => const SizedBox(width: 160, height: 260),
              ),
            ),
          ),
        ),
      );

  Widget _features() => OACard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Neler var?'), style: oaDisplay(22)),
          const SizedBox(height: 10),
          for (final f in widget.app.localFeatures)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check, size: 18, color: OA.amber)),
                const SizedBox(width: 10),
                Expanded(child: Text(f, style: oaBody(15))),
              ]),
            ),
        ]),
      );

  Widget _info() {
    final s = widget.state, app = widget.app;
    final inst = s.installed[app.id];
    final rel = s.latest[app.id];
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(k, style: oaBody(15, color: OA.muted))),
            Text(v, style: oaBody(15, weight: FontWeight.w600)),
          ]),
        );
    final platforms = [if (app.win != null) 'Windows', if (app.android != null) 'Android'];
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t('Bilgiler'), style: oaDisplay(22)),
        const SizedBox(height: 6),
        if (inst != null) row(t('Kurulu sürüm'), inst.version),
        if (rel != null) row(t('Son sürüm'), rel.prerelease ? '${rel.version} (${t('deneme')})' : rel.version),
        if (rel != null && rel.size > 0) row(t('İndirme boyutu'), sizeText(rel.size)),
        if (platforms.isNotEmpty) row(t('Platform'), platforms.join(', ')),
        row(t('Fiyat'), t('Ücretsiz, reklamsız')),
        row(t('Geliştirici'), 'OA Labs'),
      ]),
    );
  }

  Widget _historyCard() {
    final h = _history;
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Sürüm geçmişi'), style: oaDisplay(22)),
        const SizedBox(height: 8),
        if (h == null)
          const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
        else if (h.isEmpty)
          Text(t('Sürüm bilgisi alınamadı.'), style: oaBody(15, color: OA.muted))
        else
          for (final r in h.take(6)) ...[
            const Divider(height: 24, color: OA.line),
            Row(children: [
              Text(r.version, style: oaBody(17, weight: FontWeight.w600)),
              if (r.prerelease) ...[const SizedBox(width: 8), OAChip(t('Deneme'), ink: OA.betaInk, bg: OA.betaBg)],
              const Spacer(),
              Text(dateText(r.date), style: oaBody(13, color: OA.muted)),
            ]),
            if (r.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(plainNotes(r.notes), style: oaBody(15, color: OA.text2), maxLines: 12, overflow: TextOverflow.ellipsis),
            ],
          ],
      ]),
    );
  }
}

/// "Çıkınca haber ver" aç/kapat (hesap gerekir).
Future<void> toggleNotify(BuildContext context, OAAccount account, OAApp app) async {
  final messenger = ScaffoldMessenger.of(context);
  if (!account.signedIn) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(t('Haber verebilmemiz için önce Hesabım’dan giriş yap.'))));
    return;
  }
  final on = account.user?.notify.contains(app.id) ?? false;
  final ok = await account.setNotify(app.id, !on);
  final text = !ok
      ? t('Kaydedilemedi, biraz sonra tekrar dene.')
      : on
          ? t('{app} için bildirim kapatıldı.', {'app': app.name})
          : t('{app} çıkınca e-postayla haber vereceğiz.', {'app': app.name});
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
