import 'package:flutter/material.dart';

import 'account.dart';
import 'app_page.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'widgets.dart';

/// Keşfet: henüz kurulu olmayan, yakında çıkacak ve öbür platformdaki OA uygulamaları.
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key, required this.state, required this.account, required this.wide});
  final CenterState state;
  final OAAccount account;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final available = state.available;
    final others = state.others;
    return PageFrame(wide: wide, children: [
      PageTitle(t('Keşfet'), lead: t('Henüz kurmadığın OA uygulamaları. Ayrıntılar için karta dokun.')),
      if (state.loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else ...[
        if (available.isEmpty)
          OACard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text(t('Bu cihaza kurulabilen bütün OA uygulamaları kurulu.'), style: oaBody(15, color: OA.text2)),
          ),
        if (available.isNotEmpty)
          CardGrid(children: [for (final a in available) _DiscoverCard(state: state, account: account, app: a)]),
        if (others.isNotEmpty) ...[
          Text(t('Yakında ve öbür cihazlar için'), style: oaDisplay(22)),
          CardGrid(children: [for (final a in others) _DiscoverCard(state: state, account: account, app: a)]),
        ],
      ],
    ]);
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.state, required this.account, required this.app});
  final CenterState state;
  final OAAccount account;
  final OAApp app;

  @override
  Widget build(BuildContext context) {
    final job = state.jobs[app.id];
    final rel = state.latest[app.id];
    final only = app.onlyOn;

    Widget action;
    if (app.soon) {
      final on = account.user?.notify.contains(app.id) ?? false;
      action = OAButton(on ? t('Haber vereceğiz · Vazgeç') : t('Çıkınca haber ver'), onPressed: () => toggleNotify(context, account, app));
    } else if (only != null) {
      action = Text(t('{p} sürümünü o cihazdaki OA Labs Center’dan kurabilirsin.', {'p': only}), style: oaBody(13, color: OA.muted));
    } else if (job != null) {
      final p = job.progress;
      action = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(p != null ? '${job.label} · %${(p * 100).round()}' : '${job.label}…', style: oaBody(13, color: OA.muted)),
        const SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: p, minHeight: 4)),
      ]);
    } else {
      action = Row(children: [
        OAButton(t('Kur'), kind: OAButtonKind.primary, onPressed: () => runInstall(context, state, app)),
        if (rel != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              [t('Sürüm {v}', {'v': rel.version}), if (rel.size > 0) sizeText(rel.size)].join(' · '),
              style: oaBody(13, color: OA.muted),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ]);
    }

    return Material(
      color: OA.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: OA.border)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openAppPage(context, state, account, app),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              AppIcon(app),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(app.name, style: oaDisplay(20)),
                  if (app.soon) OAChip(t('Yakında'), ink: OA.soonInk, bg: OA.soonBg),
                  if (app.beta) OAChip(t('Beta'), ink: OA.betaInk, bg: OA.betaBg),
                  if (only != null) OAChip(t('Yalnız {p}', {'p': only})),
                ]),
              ),
            ]),
            const SizedBox(height: 12),
            Text(app.localTagline, style: oaBody(15, color: OA.text2)),
            const SizedBox(height: 16),
            action,
          ]),
        ),
      ),
    );
  }
}
