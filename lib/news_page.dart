import 'package:flutter/material.dart';

import 'account.dart';
import 'app_page.dart';
import 'center_state.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'widgets.dart';

/// Yenilikler: bütün OA uygulamalarının sürüm notları tek akışta.
class NewsPage extends StatefulWidget {
  const NewsPage({super.key, required this.state, required this.account, required this.wide});
  final CenterState state;
  final OAAccount account;
  final bool wide;

  @override
  State<NewsPage> createState() => _NewsPageState();
}

class _NewsPageState extends State<NewsPage> {
  List<NewsItem>? _items;
  bool _loading = false;
  String _filter = 'hepsi';

  @override
  void initState() {
    super.initState();
    // Açılıştaki denetimle aynı anda başlarsa GitHub istekleri birleşir (Releases.list).
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool force = false}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final items = await widget.state.news(force: force);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = _items;
    final ids = <String>{for (final n in all ?? const <NewsItem>[]) n.app.id};
    final list = (all ?? const <NewsItem>[]).where((n) => _filter == 'hepsi' || n.app.id == _filter).toList();
    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: PageFrame(wide: widget.wide, children: [
        PageTitle(
          t('Yenilikler'),
          lead: t('OA uygulamalarına son gelenler, en yenisi üstte.'),
          trailing: OAButton(_loading ? t('Yükleniyor…') : t('Yenile'), onPressed: _loading ? null : () => _load(force: true)),
        ),
        if (ids.length > 1)
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('hepsi', t('Hepsi')),
            for (final id in ids) _chip(id, widget.state.byId(id)?.name ?? id),
          ]),
        if (all == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (list.isEmpty)
          OACard(child: Text(t('Sürüm notları alınamadı. İnternet bağlantını kontrol edip yenile.'), style: oaBody(15, color: OA.text2)))
        else
          for (final n in list) _NewsCard(item: n, state: widget.state, account: widget.account),
      ]),
    );
  }

  Widget _chip(String id, String label) {
    final on = _filter == id;
    return ChoiceChip(
      label: Text(label, style: oaBody(14, weight: FontWeight.w600, color: on ? OA.amberInk : OA.text)),
      selected: on,
      showCheckmark: false,
      selectedColor: OA.amber,
      backgroundColor: OA.surface2,
      side: BorderSide(color: on ? OA.amber : OA.border),
      shape: const StadiumBorder(),
      onSelected: (_) => setState(() => _filter = id),
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item, required this.state, required this.account});
  final NewsItem item;
  final CenterState state;
  final OAAccount account;

  @override
  Widget build(BuildContext context) {
    final r = item.release;
    final notes = plainNotes(r.notes);
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => openAppPage(context, state, account, item.app),
          child: Row(children: [
            AppIcon(item.app, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('${item.app.name} ${r.version}', style: oaDisplay(19)),
                  if (r.prerelease) OAChip(t('Deneme'), ink: OA.betaInk, bg: OA.betaBg),
                ]),
                Text(dateText(r.date), style: oaBody(13, color: OA.muted)),
              ]),
            ),
          ]),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(notes, style: oaBody(15, color: OA.text2), maxLines: 14, overflow: TextOverflow.ellipsis),
        ],
        if (r.url.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => openLink(r.url),
            style: TextButton.styleFrom(foregroundColor: OA.amber, padding: EdgeInsets.zero),
            child: Text(t('Tüm sürüm notu')),
          ),
        ],
      ]),
    );
  }
}
