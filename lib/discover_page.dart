import 'package:flutter/material.dart';

import 'account.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'oa_theme.dart';
import 'widgets.dart';

/// Keşfet: henüz kurulu olmayan, yakında çıkacak ve öbür platformdaki OA uygulamaları.
class DiscoverPage extends StatelessWidget {
  const DiscoverPage({super.key, required this.state, required this.account, required this.wide, required this.onAccount});
  final CenterState state;
  final OAAccount account;
  final bool wide;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final available = state.available;
    final others = state.others;
    return PageFrame(wide: wide, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Keşfet', style: oaDisplay(34)),
        const SizedBox(height: 6),
        Text('Henüz kurmadığın OA uygulamaları.', style: oaBody(wide ? 17 : 15, color: OA.text2)),
      ]),
      if (state.loading)
        const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
      else ...[
        if (available.isEmpty && others.isEmpty)
          OACard(child: Text('Bütün OA uygulamaları kurulu.', style: oaBody(15, color: OA.text2))),
        if (available.isNotEmpty)
          CardGrid(children: [for (final a in available) _DiscoverCard(state: state, account: account, app: a, onAccount: onAccount)]),
        if (available.isEmpty && others.isNotEmpty)
          OACard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Text('Bu cihaza kurulabilen bütün OA uygulamaları kurulu.', style: oaBody(15, color: OA.text2)),
          ),
        if (others.isNotEmpty)
          CardGrid(children: [for (final a in others) _DiscoverCard(state: state, account: account, app: a, onAccount: onAccount)]),
      ],
    ]);
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.state, required this.account, required this.app, required this.onAccount});
  final CenterState state;
  final OAAccount account;
  final OAApp app;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final job = state.jobs[app.id];
    final rel = state.latest[app.id];
    final only = app.onlyOn;

    Widget action;
    if (app.soon) {
      final on = account.user?.notify.contains(app.id) ?? false;
      action = OAButton(
        on ? 'Haber vereceğiz · Vazgeç' : 'Çıkınca haber ver',
        onPressed: () async {
          if (!account.signedIn) {
            toast(context, 'Haber verebilmemiz için önce giriş yap.');
            onAccount();
            return;
          }
          final messenger = ScaffoldMessenger.of(context);
          final ok = await account.setNotify(app.id, !on);
          final text = !ok
              ? 'Kaydedilemedi, biraz sonra tekrar dene.'
              : on
                  ? '${app.name} için bildirim kapatıldı.'
                  : '${app.name} çıkınca e-postayla haber vereceğiz.';
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(text)));
        },
      );
    } else if (only != null) {
      action = Text('$only sürümünü o cihazdaki OA Labs Center’dan kurabilirsin.', style: oaBody(13, color: OA.muted));
    } else if (job != null) {
      final p = job.progress;
      action = Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(p != null ? '${job.label} · %${(p * 100).round()}' : '${job.label}…', style: oaBody(13, color: OA.muted)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(value: p, minHeight: 4),
        ),
      ]);
    } else {
      action = Row(children: [
        OAButton('Kur', kind: OAButtonKind.primary, onPressed: () => runInstall(context, state, app)),
        if (rel != null) ...[
          const SizedBox(width: 12),
          Text('Sürüm ${rel.version}', style: oaBody(13, color: OA.muted)),
        ],
      ]);
    }

    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          AppIcon(app),
          const SizedBox(width: 14),
          Expanded(
            child: Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(app.name, style: oaDisplay(20)),
              if (app.soon) const OAChip('Yakında', ink: OA.soonInk, bg: OA.soonBg),
              if (app.beta) const OAChip('Beta', ink: OA.betaInk, bg: OA.betaBg),
              if (only != null) OAChip('Yalnız $only'),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(app.tagline, style: oaBody(15, color: OA.text2)),
        const SizedBox(height: 16),
        action,
      ]),
    );
  }
}
