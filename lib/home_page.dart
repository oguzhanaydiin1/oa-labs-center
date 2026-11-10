import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'catalog.dart';
import 'center_state.dart';
import 'oa_theme.dart';
import 'widgets.dart';

/// Ana sayfa: kurulu uygulamalar, bekleyen güncellemeler.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.state, required this.wide, required this.onDiscover});
  final CenterState state;
  final bool wide;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final list = state.installedApps;
    final ups = state.updates;
    return PageFrame(wide: wide, children: [
      SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            Text('Uygulamaların', style: oaDisplay(34)),
            OAButton(
              state.checking ? 'Denetleniyor…' : 'Güncellemeleri denetle',
              onPressed: state.checking ? null : () => state.refresh(force: true),
            ),
          ],
        ),
      ),
      if (state.selfUpdate) _SelfBanner(state: state),
      if (ups.isNotEmpty) _UpdateBanner(state: state, count: ups.length),
      if (state.loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else if (list.isEmpty)
        _Empty(onDiscover: onDiscover)
      else
        CardGrid(minWidth: 400, children: [for (final a in list) _InstalledCard(state: state, app: a, wide: wide)]),
      if (!state.loading && list.isNotEmpty && state.available.isNotEmpty)
        Align(
          alignment: Alignment.centerLeft,
          child: OAButton('Diğer OA uygulamalarına göz at', onPressed: onDiscover),
        ),
    ]);
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
              Text('$count güncelleme var', style: oaDisplay(24)),
              const SizedBox(height: 4),
              Text(
                android
                    ? '$names. Android her kurulumda senden onay ister; uygulamaları tek tek güncelle.'
                    : '$names. Arka planda kurulur, yönetici izni gerekmez.',
                style: oaBody(15, color: OA.text2),
              ),
            ]),
          ),
          if (!android)
            OAButton(
              state.updatingAll ? 'Güncelleniyor…' : 'Hepsini güncelle',
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
                ? 'OA Labs Center güncelleniyor…'
                : 'OA Labs Center ${rel?.version ?? ''} hazır. Güncellenince kendiliğinden yeniden açılır.',
            style: oaBody(15, color: OA.text2),
          ),
          OAButton('Güncelle', onPressed: job != null ? null : () => runInstall(context, state, centerApp)),
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
          Text('Henüz kurulu OA uygulaması yok', style: oaDisplay(24)),
          const SizedBox(height: 6),
          Text('Keşfet sayfasından istediğini tek dokunuşla kurabilirsin.', style: oaBody(15, color: OA.text2)),
          const SizedBox(height: 18),
          OAButton('Keşfet', kind: OAButtonKind.primary, big: true, onPressed: onDiscover),
        ]),
      );
}

class _InstalledCard extends StatelessWidget {
  const _InstalledCard({required this.state, required this.app, required this.wide});
  final CenterState state;
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
      status = '$version kurulu · ${rel.version} hazır';
    } else if (rel != null) {
      status = '$version · Güncel';
    } else {
      status = version;
    }

    return OACard(
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
          if (up) OAButton('Güncelle', onPressed: () => runInstall(context, state, app)),
          if (up && wide) const SizedBox(width: 8),
          if (!up || wide)
            OAButton('Aç', onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final ok = await state.open(app);
              if (!ok) {
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text('${app.name} açılamadı.')));
              }
            }),
        ],
      ]),
    );
  }
}
