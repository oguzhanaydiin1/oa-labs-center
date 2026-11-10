import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';

import 'account.dart';
import 'account_page.dart';
import 'catalog.dart';
import 'center_state.dart';
import 'desktop.dart';
import 'discover_page.dart';
import 'home_page.dart';
import 'link_request.dart';
import 'oa_theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // Windows: zaten açıksa açık olan öne gelir, bu kopya kapanır.
  if (!await Desktop.i.init(args)) exit(0);
  runApp(const CenterApp());
}

class CenterApp extends StatelessWidget {
  const CenterApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'OA Labs Center',
        debugShowCheckedModeBanner: false,
        theme: oaTheme(),
        home: const Shell(),
      );
}

/// Uygulamanın iskeleti: geniş pencerede solda menü, dar ekranda altta menü.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final _state = CenterState();
  final _account = OAAccount();
  int _tab = 0;

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
    _state.refresh().then((_) => Desktop.i.afterCheck());
    _account.load().then((_) => _checkLink());
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
    _account.dispose();
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
      listenable: Listenable.merge([_state, _account, Desktop.i]),
      builder: (context, _) => LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 760;
        final badge = _state.updates.length + (_state.selfUpdate ? 1 : 0);
        final pages = IndexedStack(index: _tab, children: [
          HomePage(state: _state, wide: wide, onDiscover: () => _go(1)),
          DiscoverPage(state: _state, account: _account, wide: wide, onAccount: () => _go(2)),
          AccountPage(account: _account, wide: wide),
        ]);
        final link = _linkApp;
        final prompt = link != null && (!_linkHidden || _account.signedIn)
            ? LinkPrompt(
                app: link,
                account: _account,
                onSignIn: () => setState(() {
                  _linkHidden = true;
                  _tab = 2;
                }),
              )
            : null;
        Widget withPrompt(Widget child) => prompt == null ? child : Stack(children: [child, Positioned.fill(child: prompt)]);
        if (wide) {
          return withPrompt(Scaffold(
            body: Row(children: [
              _SideNav(tab: _tab, badge: badge, account: _account, onTap: _go),
              Expanded(child: pages),
            ]),
          ));
        }
        return withPrompt(Scaffold(
          body: SafeArea(bottom: false, child: pages),
          bottomNavigationBar: _BottomNav(tab: _tab, badge: badge, onTap: _go),
        ));
      }),
    );
  }
}

const _tabs = [
  (label: 'Ana sayfa', icon: Icons.home_outlined),
  (label: 'Keşfet', icon: Icons.grid_view_outlined),
  (label: 'Hesabım', icon: Icons.person_outline),
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

class _SideNav extends StatelessWidget {
  const _SideNav({required this.tab, required this.badge, required this.account, required this.onTap});
  final int tab;
  final int badge;
  final OAAccount account;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final user = account.user;
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
        for (var i = 0; i < 2; i++) ...[
          _SideItem(label: _tabs[i].label, selected: tab == i, badge: i == 0 ? badge : 0, onTap: () => onTap(i)),
          const SizedBox(height: 4),
        ],
        const Spacer(),
        Material(
          color: tab == 2 ? OA.surface2 : OA.surface,
          shape: const StadiumBorder(side: BorderSide(color: OA.border)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onTap(2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
              child: Row(children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: OA.surface2, shape: BoxShape.circle),
                  child: user == null
                      ? const Icon(Icons.person_outline, size: 20, color: OA.text2)
                      : Text(user.initial, style: oaDisplay(16)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    user == null ? 'Giriş yap' : 'Hesabım',
                    style: oaBody(15, weight: FontWeight.w600, height: 1.2),
                    maxLines: 1,
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
  const _SideItem({required this.label, required this.selected, required this.badge, required this.onTap});
  final String label;
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
              Expanded(
                child: Text(label,
                    style: oaBody(15, color: selected ? OA.text : OA.muted, weight: FontWeight.w600, height: 1.2)),
              ),
              if (badge > 0) _Badge(badge),
            ]),
          ),
        ),
      );
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.badge, required this.onTap});
  final int tab;
  final int badge;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(color: OA.bg2, border: Border(top: BorderSide(color: OA.line))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => onTap(i),
                    // Sabit yükseklik: hizalamalı bir kutu burada ekranın tamamına yayılır ve sayfayı örter.
                    child: SizedBox(
                      height: 56,
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Stack(clipBehavior: Clip.none, children: [
                          Icon(_tabs[i].icon, size: 24, color: tab == i ? OA.amber : OA.muted),
                          if (i == 0 && badge > 0)
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
                        Text(_tabs[i].label,
                            style: oaBody(13, color: tab == i ? OA.amber : OA.muted, weight: FontWeight.w600, height: 1.1)),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ),
      );
}
