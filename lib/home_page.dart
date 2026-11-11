import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'account.dart';
import 'announcements.dart';
import 'app_page.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'devices.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'widgets.dart';

/// Ana sayfa: duyurular, gelen kurulum istekleri, güncellemeler ve kurulu uygulamalar.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state, required this.account, required this.wide, required this.onDiscover});
  final CenterState state;
  final OAAccount account;
  final bool wide;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final list = state.installedApps;
    final ups = state.updates;
    return PageFrame(wide: wide, children: [
      PageTitle(
        t('Uygulamaların'),
        trailing: OAButton(
          state.checking ? t('Denetleniyor…') : t('Güncellemeleri denetle'),
          onPressed: state.checking ? null : () => state.refresh(force: true),
        ),
      ),
      for (final a in state.visibleAnnouncements) _AnnouncementCard(state: state, item: a),
      for (final c in state.incoming) _IncomingCard(state: state, command: c),
      if (state.selfUpdate) _SelfBanner(state: state),
      if (ups.isNotEmpty) _UpdateBanner(state: state, count: ups.length),
      if (state.loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else if (list.isEmpty)
        _Empty(onDiscover: onDiscover)
      else
        CardGrid(minWidth: 400, children: [for (final a in list) InstalledCard(state: state, account: account, app: a, wide: wide)]),
      if (!state.loading && list.isNotEmpty && state.available.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: OAButton(t('Diğer OA uygulamalarına göz at'), onPressed: onDiscover),
        ),
    ]);
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.state, required this.item});
  final CenterState state;
  final Announcement item;

  @override
  Widget build(BuildContext context) {
    final app = item.app == null ? null : state.byId(item.app!);
    final url = item.url;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      decoration: BoxDecoration(
        color: OA.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: OA.amber.withValues(alpha: 0.45)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (app != null) ...[AppIcon(app, size: 44), const SizedBox(width: 14)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('Duyuru'), style: oaBody(13, color: OA.amber, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(item.title, style: oaDisplay(20)),
            if (item.body.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.body, style: oaBody(15, color: OA.text2)),
            ],
            if (url != null) ...[
              const SizedBox(height: 10),
              OAButton(t('Ayrıntılar'), onPressed: () => openLink(url)),
            ],
          ]),
        ),
        IconButton(
          tooltip: t('Kapat'),
          icon: const Icon(Icons.close, color: OA.muted),
          onPressed: () => state.dismissAnnouncement(item),
        ),
      ]),
    );
  }
}

/// Android: bilgisayardan gelen "telefona kur" isteği.
class _IncomingCard extends StatelessWidget {
  const _IncomingCard({required this.state, required this.command});
  final CenterState state;
  final RemoteCommand command;

  @override
  Widget build(BuildContext context) {
    final app = state.byId(command.app);
    if (app == null) return const SizedBox.shrink();
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AppIcon(app, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Başka cihazından istendi'), style: oaBody(13, color: OA.muted, weight: FontWeight.w600)),
              Text(t('{app} bu telefona kurulsun mu?', {'app': app.name}), style: oaDisplay(18)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OAButton(t('Kur'), kind: OAButtonKind.primary, onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            final err = await state.answerIncoming(command, true);
            if (err != null) {
              messenger
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(err)));
            }
          }),
          OAButton(t('Şimdi değil'), onPressed: () => state.answerIncoming(command, false)),
        ]),
      ]),
    );
  }
}

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.state, required this.count});
  final CenterState state;
  final int count;

  @override
  Widget build(BuildContext context) {
    final names = state.updates.map((a) => a.name).join(', ');
    final android = Platform.isAndroid;
    return OACard(
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 16,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(count == 1 ? t('1 güncelleme var') : t('{n} güncelleme var', {'n': count}), style: oaDisplay(24)),
              const SizedBox(height: 4),
              Text(
                android
                    ? t('{names}. Android her kurulumda senden onay ister; uygulamaları tek tek güncelle.', {'names': names})
                    : t('{names}. Arka planda kurulur, yönetici izni gerekmez.', {'names': names}),
                style: oaBody(15, color: OA.text2),
              ),
            ]),
          ),
          if (!android)
            OAButton(
              state.updatingAll ? t('Güncelleniyor…') : t('Hepsini güncelle'),
              kind: OAButtonKind.primary,
              big: true,
              onPressed: state.updatingAll || state.jobs.isNotEmpty
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final errors = await state.updateAll();
                      if (errors.isNotEmpty) {
                        messenger
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(errors.join('\n'))));
                      }
                    },
            ),
        ],
      ),
    );
  }
}

/// OA Labs Center'ın kendi güncellemesi.
class _SelfBanner extends StatelessWidget {
  const _SelfBanner({required this.state});
  final CenterState state;

  @override
  Widget build(BuildContext context) {
    final rel = state.latest[centerApp.id];
    final job = state.jobs[centerApp.id];
    return OACard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 12,
        children: [
          Text(
            job != null
                ? t('OA Labs Center güncelleniyor…')
                : Platform.isAndroid
                    ? t('OA Labs Center {v} hazır.', {'v': rel?.version ?? ''})
                    : t('OA Labs Center {v} hazır. Güncellenince kendiliğinden yeniden açılır.', {'v': rel?.version ?? ''}),
            style: oaBody(15, color: OA.text2),
          ),
          OAButton(t('Güncelle'), onPressed: job != null ? null : () => runInstall(context, state, centerApp)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onDiscover});
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) => OACard(
        padding: const EdgeInsets.all(28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t('Henüz kurulu OA uygulaması yok'), style: oaDisplay(24)),
          const SizedBox(height: 6),
          Text(t('Keşfet sayfasından istediğini tek dokunuşla kurabilirsin.'), style: oaBody(15, color: OA.text2)),
          const SizedBox(height: 18),
          OAButton(t('Keşfet'), kind: OAButtonKind.primary, big: true, onPressed: onDiscover),
        ]),
      );
}

/// Kurulu uygulama kartı: sürüm, Aç / Güncelle; dokununca uygulama sayfası.
class InstalledCard extends StatelessWidget {
  const InstalledCard({super.key, required this.state, required this.account, required this.app, required this.wide});
  final CenterState state;
  final OAAccount account;
  final OAApp app;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final inst = state.installed[app.id];
    final rel = state.latest[app.id];
    final job = state.jobs[app.id];
    final up = state.hasUpdate(app);
    final version = inst?.version ?? '';

    String status;
    if (job != null) {
      final p = job.progress;
      status = p != null ? '${job.label} · %${(p * 100).round()}' : '${job.label}…';
    } else if (up && rel != null) {
      status = t('{a} kurulu · {b} hazır', {'a': version, 'b': rel.version});
    } else if (rel != null) {
      status = t('{v} · Güncel', {'v': version});
    } else {
      status = version;
    }

    return Material(
      color: OA.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: OA.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAppPage(context, state, account, app),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            AppIcon(app),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(app.name, style: oaDisplay(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(status, style: oaBody(13, color: OA.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (job != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(value: job.progress, minHeight: 4),
                  ),
                ],
              ]),
            ),
            if (job == null) ...[
              const SizedBox(width: 10),
              if (up) OAButton(t('Güncelle'), onPressed: () => runInstall(context, state, app)),
              if (up && wide) const SizedBox(width: 8),
              if (!up || wide)
                OAButton(t('Aç'), onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final ok = await state.open(app);
                  if (!ok) {
                    messenger
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text(t('{app} açılamadı.', {'app': app.name}))));
                  }
                }),
            ],
          ]),
        ),
      ),
    );
  }
}
