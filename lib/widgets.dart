import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'catalog.dart';
import 'center_state.dart';
import 'oa_theme.dart';

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Kur ya da güncelle; hata olursa alttan bildirir.
Future<void> runInstall(BuildContext context, CenterState state, OAApp app) async {
  final messenger = ScaffoldMessenger.of(context);
  final err = await state.install(app);
  if (err != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(err)));
  }
}

/// Uygulama ikonu: uygulamayla gelen resim, yoksa baş harfli renkli kare.
class AppIcon extends StatelessWidget {
  const AppIcon(this.app, {super.key, this.size = 52});
  final OAApp app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.29);
    final short = app.name.replaceFirst(RegExp(r'^OA\s+'), '');
    final letter = short.isEmpty ? '?' : short.substring(0, 1).toUpperCase();
    Widget tile() => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: app.color, borderRadius: radius),
          child: Text(letter, style: oaDisplay(size * 0.46, color: app.ink)),
        );
    if (app.icon == null) return tile();
    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        'assets/apps/${app.icon}.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => tile(),
      ),
    );
  }
}

/// Sayfa iskeleti: kaydırılabilir, ortalanmış, en fazla 1040 px genişlikte.
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.wide, required this.children});
  final bool wide;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pad = wide ? 32.0 : 16.0;
    final spaced = <Widget>[];
    for (final c in children) {
      if (spaced.isNotEmpty) spaced.add(const SizedBox(height: 20));
      spaced.add(c);
    }
    return ListView(
      padding: EdgeInsets.fromLTRB(pad, wide ? 32 : 20, pad, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced),
          ),
        ),
      ],
    );
  }
}

/// Kartları genişliğe göre 1 ile 3 sütuna dizer.
class CardGrid extends StatelessWidget {
  const CardGrid({super.key, required this.children, this.minWidth = 320});
  final List<Widget> children;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const gap = 16.0;
        final cols = math.max(1, math.min(3, (c.maxWidth / minWidth).floor()));
        final w = ((c.maxWidth - gap * (cols - 1)) / cols).floorToDouble();
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final child in children) SizedBox(width: w, child: child)],
        );
      });
}
