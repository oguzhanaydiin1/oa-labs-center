import 'package:flutter/material.dart';

import 'account.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'devices.dart';
import 'i18n.dart';
import 'oa_theme.dart';
import 'widgets.dart';

/// Cihazlarım: hesaba bağlı telefon ve bilgisayarlar, üzerlerindeki OA uygulamaları;
/// öbür cihaza uzaktan kurulum isteği.
class DevicesPage extends StatefulWidget {
  const DevicesPage({super.key, required this.state, required this.account, required this.wide, required this.onSignIn});
  final CenterState state;
  final OAAccount account;
  final bool wide;
  final VoidCallback onSignIn;

  @override
  State<DevicesPage> createState() => _DevicesPageState();
}

class _DevicesPageState extends State<DevicesPage> {
  List<OADevice>? _devices;
  String? _me;
  bool _loading = false;
  bool _wasSignedIn = false;

  @override
  void initState() {
    super.initState();
    DeviceSync.id().then((v) {
      if (mounted) setState(() => _me = v);
    });
    widget.account.addListener(_onAccount);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onAccount());
  }

  @override
  void dispose() {
    widget.account.removeListener(_onAccount);
    super.dispose();
  }

  void _onAccount() {
    final s = widget.account.signedIn;
    if (s && !_wasSignedIn) _load();
    if (!s) _devices = null;
    _wasSignedIn = s;
  }

  Future<void> _load() async {
    if (_loading || !widget.account.signedIn) return;
    setState(() => _loading = true);
    await widget.state.syncDevice();
    final d = await DeviceSync.list(widget.account);
    if (!mounted) return;
    setState(() {
      _devices = d ?? _devices ?? const [];
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final acc = widget.account;
    return RefreshIndicator(
      onRefresh: _load,
      child: PageFrame(wide: widget.wide, children: [
        PageTitle(
          t('Cihazlarım'),
          lead: t('Telefonunda ve bilgisayarında hangi OA uygulamalarının kurulu olduğu. Öbür cihazına buradan kurdurabilirsin.'),
          trailing: acc.signedIn ? OAButton(_loading ? t('Yükleniyor…') : t('Yenile'), onPressed: _loading ? null : _load) : null,
        ),
        if (acc.loading)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else if (!acc.signedIn)
          OACard(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('Cihazlarını görmek için giriş yap'), style: oaDisplay(22)),
              const SizedBox(height: 6),
              Text(t('Telefonunda ve bilgisayarında aynı OA Labs hesabıyla giriş yapınca ikisi burada yan yana görünür.'),
                  style: oaBody(15, color: OA.text2)),
              const SizedBox(height: 16),
              OAButton(t('Giriş yap'), kind: OAButtonKind.primary, big: true, onPressed: widget.onSignIn),
            ]),
          )
        else if (_devices == null)
          const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        else ...[
          for (final d in _sorted()) _DeviceCard(device: d, me: d.id == _me, page: this),
          if (_devices!.length < 2) _hint(),
        ],
      ]),
    );
  }

  List<OADevice> _sorted() {
    final l = [..._devices!];
    l.sort((a, b) => a.id == _me ? -1 : b.id == _me ? 1 : 0);
    return l;
  }

  Widget _hint() {
    final other = DeviceSync.platform == 'windows' ? t('telefonuna') : t('bilgisayarına');
    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t('Öbür cihazını ekle'), style: oaDisplay(20)),
        const SizedBox(height: 6),
        Text(
          t('OA Labs Center’ı {other} da kur ve aynı hesapla giriş yap. İndirme bağlantısı: oalabs.dev', {'other': other}),
          style: oaBody(15, color: OA.text2),
        ),
      ]),
    );
  }

  Future<void> _send(OADevice d, OAApp app) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await DeviceSync.send(widget.account, d.id, app.id);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(!ok
            ? t('İstek gönderilemedi, biraz sonra tekrar dene.')
            : d.isWindows
                ? t('{app}, {device} açıkken kendiliğinden kurulacak.', {'app': app.name, 'device': d.name})
                : t('{device} OA Labs Center’ı açınca {app} kurulumunu onaylaman istenecek.', {'app': app.name, 'device': d.name})),
      ));
    if (ok) _load();
  }

  Future<void> _cancel(RemoteCommand c) async {
    await DeviceSync.cancel(widget.account, c.id);
    _load();
  }

  Future<void> _remove(OADevice d) async {
    final yes = await confirm(context,
        title: t('{device} listeden kaldırılsın mı?', {'device': d.name}),
        body: t('Cihazdaki uygulamalara dokunulmaz. O cihazda OA Labs Center yeniden açılınca listeye geri gelir.'),
        action: t('Kaldır'),
        danger: true);
    if (!yes) return;
    await DeviceSync.remove(widget.account, d.id);
    _load();
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.me, required this.page});
  final OADevice device;
  final bool me;
  final _DevicesPageState page;

  @override
  Widget build(BuildContext context) {
    final state = page.widget.state;
    final d = device;
    final pending = {for (final c in d.commands.where((c) => c.state == 'pending')) c.app: c};
    final installed = state.apps.where((a) => d.apps.containsKey(a.id)).toList();
    final installable = state.apps
        .where((a) => !a.soon && !d.apps.containsKey(a.id) && (d.isWindows ? a.win != null : a.android != null))
        .toList();

    return OACard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: OA.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: OA.border)),
            child: Icon(d.isWindows ? Icons.computer_outlined : Icons.smartphone_outlined, color: OA.text),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(d.name, style: oaDisplay(20)),
                if (me) OAChip(t('Bu cihaz'), ink: OA.amberInk, bg: OA.amber),
              ]),
              Text('${d.isWindows ? 'Windows' : 'Android'} · ${t('son görülme {ago}', {'ago': agoText(d.updated)})}',
                  style: oaBody(13, color: OA.muted)),
            ]),
          ),
          if (!me)
            IconButton(
              tooltip: t('Listeden kaldır'),
              icon: const Icon(Icons.delete_outline, color: OA.muted),
              onPressed: () => page._remove(d),
            ),
        ]),
        const SizedBox(height: 14),
        Text(t('Kurulu'), style: oaBody(13, color: OA.muted, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (installed.isEmpty)
          Text(t('OA uygulaması yok.'), style: oaBody(15, color: OA.text2))
        else
          Wrap(spacing: 10, runSpacing: 10, children: [
            for (final a in installed)
              Container(
                padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                decoration: BoxDecoration(color: OA.surface2, borderRadius: BorderRadius.circular(999), border: Border.all(color: OA.border)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  AppIcon(a, size: 28),
                  const SizedBox(width: 8),
                  Text(a.name, style: oaBody(14, weight: FontWeight.w600)),
                  const SizedBox(width: 6),
                  Text(d.apps[a.id] ?? '', style: oaBody(13, color: OA.muted)),
                ]),
              ),
          ]),
        if (!me && installable.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(d.isWindows ? t('Bu bilgisayara kur') : t('Bu telefona kur'), style: oaBody(13, color: OA.muted, weight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final a in installable)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                AppIcon(a, size: 36),
                const SizedBox(width: 12),
                Expanded(child: Text(a.name, style: oaBody(16, weight: FontWeight.w600))),
                if (pending[a.id] != null) ...[
                  Text(t('Sırada'), style: oaBody(13, color: OA.amber, weight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  OAButton(t('Geri al'), onPressed: () => page._cancel(pending[a.id]!)),
                ] else
                  OAButton(t('Kur'), onPressed: () => page._send(d, a)),
              ]),
            ),
          const SizedBox(height: 4),
          Text(
            d.isWindows
                ? t('Bilgisayar açıkken OA Labs Center isteği birkaç dakika içinde alır ve kendisi kurar.')
                : t('Telefonda OA Labs Center açılınca kurulum için onayın istenir; Android bunu şart koşuyor.'),
            style: oaBody(13, color: OA.muted),
          ),
        ],
      ]),
    );
  }
}
