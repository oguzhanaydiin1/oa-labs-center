import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';

import 'account.dart';
import 'account_page.dart';
import 'android_bg.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'desktop.dart';
import 'devices_page.dart';
import 'discover_page.dart';
import 'home_page.dart';
import 'i18n.dart';
import 'link_request.dart';
import 'news_page.dart';
import 'oa_theme.dart';
import 'settings.dart';
import 'support_page.dart';
import 'widgets.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.i.load();
  await Catalog.loadBundled();
  // Windows: zaten açıksa açık olan öne gelir, bu kopya kapanır.
  if (!await Desktop.i.init(args)) exit(0);
  runApp(const CenterApp());
}

class CenterApp extends StatelessWidget {
  const CenterApp({super.key});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Settings.i,
        builder: (context, _) => MaterialApp(
          key: ValueKey(L.code), // dil değişince bütün metinler yeniden kurulur
          title: 'OA Labs Center',
          debugShowCheckedModeBanner: false,
          theme: oaTheme(),
          home: const Shell(),
        ),
      );
}

const _home = 0, _discover = 1, _devices = 3, _account = 5;

/// Uygulamanın iskeleti: geniş pencerede solda menü, dar ekranda altta menü ve üstte hesap düğmesi.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final _acc = OAAccount();
  late final _state = CenterState(_acc);
  int _tab = _home;

  /// Android tek giriş: giriş isteyen OA uygulaması (yoksa null).
  OAApp? _linkApp;

  /// İstek, Center'da önce giriş yapılsın diye geçici olarak gizlendi.
  bool _linkHidden = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Desktop.i.attach(_state);
    Desktop.i.onShowTab = _go;
    _acc.load().then((_) async {
      _checkLink();
      await _state.syncDevice();
    });
    _refresh();
  }

  Future<void> _refresh({bool force = false}) async {
    await _state.refresh(force: force);
    await Desktop.i.afterCheck();
    await AndroidBackground.apply(_state.apps);
  }

  Future<void> _checkLink() async {
    if (!Platform.isAndroid) return;
    final pkg = await LinkRequests.pending();
    if (pkg == null || !mounted) return;
    final app = LinkRequests.appFor(pkg, _state.apps);
    if (app == null) {
      // OA uygulaması değil: giriş verilmez.
      await LinkRequests.answer(null);
      return;
    }
    setState(() => _linkApp = app);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _state.dispose();
    _acc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android'de kurulum ekranından ya da başka uygulamadan dönünce kurulu sürümleri yeniden oku.
    if (state == AppLifecycleState.resumed) _state.refreshInstalled();
  }

  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([_state, _acc, Desktop.i]),
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final badge = _state.updates.length + (_state.selfUpdate ? 1 : 0) + _state.incoming.length;
        final pages = IndexedStack(index: _tab, children: [
          HomePage(state: _state, account: _acc, wide: wide, onDiscover: () => _go(_discover)),
          DiscoverPage(state: _state, account: _acc, wide: wide),
          NewsPage(state: _state, account: _acc, wide: wide),
          DevicesPage(state: _state, account: _acc, wide: wide, onSignIn: () => _go(_account)),
          SupportPage(account: _acc, wide: wide),
          AccountPage(account: _acc, wide: wide, onSettingsChanged: () => _refresh(force: true)),
        ]);
        final link = _linkApp;
        final prompt = link != null && (!_linkHidden || _acc.signedIn)
            ? LinkPrompt(
                app: link,
                account: _acc,
                onSignIn: () => setState(() {
                  _linkHidden = true;
                  _tab = _account;
                }),
              )
            : null;
        Widget withPrompt(Widget child) => prompt == null ? child : Stack(children: [child, Positioned.fill(child: prompt)]);
        if (wide) {
          return withPrompt(Scaffold(
            body: Row(children: [
              _SideNav(tab: _tab, badge: badge, account: _acc, onTap: _go),
              Expanded(child: pages),
            ]),
          ));
        }
        return withPrompt(Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(children: [
              _TopBar(account: _acc, selected: _tab == _account, onAccount: () => _go(_account)),
              Expanded(child: pages),
            ]),
          ),
          bottomNavigationBar: _BottomNav(tab: _tab, badge: badge, devicesBadge: 0, onTap: _go),
        ));
      }),
    );
  }
}

List<({String label, IconData icon})> get _tabs => [
      (label: t('Ana sayfa'), icon: Icons.home_outlined),
      (label: t('Keşfet'), icon: Icons.grid_view_outlined),
      (label: t('Yenilikler'), icon: Icons.auto_awesome_outlined),
      (label: t('Cihazlarım'), icon: Icons.devices_outlined),
      (label: t('Destek'), icon: Icons.support_agent_outlined),
    ];

class _Badge extends StatelessWidget {
  const _Badge(this.count);
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 22),
        height: 22,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: OA.amber, borderRadius: BorderRadius.circular(999)),
        child: Text('$count', style: oaBody(13, color: OA.amberInk, weight: FontWeight.w600, height: 1)),
      );
}

/// Telefonda üst çubuk: OA işareti, ad ve hesap düğmesi.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.account, required this.selected, required this.onAccount});
  final OAAccount account;
  final bool selected;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
        child: Row(children: [
          const OAMark(size: 30),
          const SizedBox(width: 10),
          Expanded(child: Text('OA Labs Center', style: oaDisplay(20), maxLines: 1, overflow: TextOverflow.ellipsis)),
          IconButton(
            tooltip: t('Hesap ve ayarlar'),
            onPressed: onAccount,
            icon: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                  shape: BoxShape.circle, border: Border.all(color: selected ? OA.amber : Colors.transparent, width: 2)),
              child: UserAvatar(account, size: 36),
            ),
          ),
        ]),
      );
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.tab, required this.badge, required this.account, required this.onTap});
  final int tab;
  final int badge;
  final OAAccount account;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final user = account.user;
    final tabs = _tabs;
    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
      decoration: const BoxDecoration(color: OA.bg2, border: Border(right: BorderSide(color: OA.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(children: [
            const OAMark(size: 32, ground: OA.bg2),
            const SizedBox(width: 10),
            Expanded(child: Text('OA Labs Center', style: oaDisplay(19), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        const SizedBox(height: 24),
        for (var i = 0; i < tabs.length; i++) ...[
          _SideItem(
              label: tabs[i].label, icon: tabs[i].icon, selected: tab == i, badge: i == _home ? badge : 0, onTap: () => onTap(i)),
          const SizedBox(height: 4),
        ],
        const Spacer(),
        Material(
          color: tab == _account ? OA.surface2 : OA.surface,
          shape: const StadiumBorder(side: BorderSide(color: OA.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(_account),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              child: Row(children: [
                UserAvatar(account),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user == null ? t('Giriş yap ve ayarlar') : t('Hesap ve ayarlar'),
                    style: oaBody(15, weight: FontWeight.w600, height: 1.2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({required this.label, required this.icon, required this.selected, required this.badge, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? OA.surface2 : Colors.transparent,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              Icon(icon, size: 20, color: selected ? OA.amber : OA.muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: oaBody(15, color: selected ? OA.text : OA.muted, weight: FontWeight.w600, height: 1.2)),
              ),
              if (badge > 0) _Badge(badge),
            ]),
          ),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.badge, required this.devicesBadge, required this.onTap});
  final int tab;
  final int badge;
  final int devicesBadge;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final tabs = _tabs;
    return Container(
      decoration: const BoxDecoration(color: OA.bg2, border: Border(top: BorderSide(color: OA.line))),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
          child: Row(children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  // Sabit yükseklik: hizalamalı bir kutu burada ekranın tamamına yayılır ve sayfayı örter.
                  child: SizedBox(
                    height: 56,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Stack(clipBehavior: Clip.none, children: [
                        Icon(tabs[i].icon, size: 24, color: tab == i ? OA.amber : OA.muted),
                        if ((i == _home && badge > 0) || (i == _devices && devicesBadge > 0))
                          const Positioned(
                            right: -4,
                            top: -2,
                            child: SizedBox(
                              width: 10,
                              height: 10,
                              child: DecoratedBox(decoration: BoxDecoration(color: OA.amber, shape: BoxShape.circle)),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 4),
                      Text(tabs[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: oaBody(12, color: tab == i ? OA.amber : OA.muted, weight: FontWeight.w600, height: 1.1)),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
