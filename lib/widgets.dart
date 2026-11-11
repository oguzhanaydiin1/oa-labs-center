import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'catalog.dart';
import 'center_state.dart';
import 'i18n.dart';
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

/// Kaldırmadan önce sorar; onaylanırsa kaldırır ve sonucu bildirir.
Future<void> runUninstall(BuildContext context, CenterState state, OAApp app) async {
  final yes = await confirm(
    context,
    title: t('{app} kaldırılsın mı?', {'app': app.name}),
    body: t('Uygulama bu cihazdan silinir. Hesabındaki eşitlenmiş verilere dokunulmaz.'),
    action: t('Kaldır'),
    danger: true,
  );
  if (!yes || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final err = await state.uninstall(app);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(err ?? t('{app} kaldırıldı.', {'app': app.name}))));
}

/// Evet/hayır sorusu.
Future<bool> confirm(BuildContext context,
    {required String title, String? body, required String action, bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: OA.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: OA.border)),
      title: Text(title, style: oaDisplay(22)),
      content: body == null ? null : Text(body, style: oaBody(15, color: OA.text2)),
      actions: [
        OAButton(t('Vazgeç'), onPressed: () => Navigator.of(ctx).pop(false)),
        OAButton(action,
            kind: danger ? OAButtonKind.danger : OAButtonKind.primary, onPressed: () => Navigator.of(ctx).pop(true)),
      ],
    ),
  );
  return r == true;
}

Future<void> openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

/// Sayfa başlığı ve altında kısa açıklama.
class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.lead, this.trailing});
  final String title;
  final String? lead;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: oaDisplay(34)),
            if (lead != null) ...[
              const SizedBox(height: 6),
              Text(lead!, style: oaBody(16, color: OA.text2)),
            ],
          ]),
          if (trailing != null) trailing!,
        ],
      );
}

/// Açık/kapalı ayarı.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: oaBody(17, weight: FontWeight.w600, color: onChanged == null ? OA.faint : OA.text)),
                const SizedBox(height: 2),
                Text(subtitle, style: oaBody(13, color: OA.muted)),
              ]),
            ),
            const SizedBox(width: 12),
            Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: OA.amberInk,
              activeTrackColor: OA.amber,
              inactiveThumbColor: OA.muted,
              inactiveTrackColor: OA.surface2,
            ),
          ]),
        ),
      );
}

/// İndirme boyutu: "48 MB".
String sizeText(int bytes) {
  if (bytes <= 0) return '';
  final mb = bytes / (1024 * 1024);
  return mb >= 10 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
}

/// Tarih: "11 Kasım 2026".
String dateText(DateTime? d) {
  if (d == null) return '';
  const tr = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  const en = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
  final l = d.toLocal();
  return L.en ? '${en[l.month - 1]} ${l.day}, ${l.year}' : '${l.day} ${tr[l.month - 1]} ${l.year}';
}

/// "3 saat önce" gibi.
String agoText(DateTime? d) {
  if (d == null) return '';
  final x = DateTime.now().difference(d.toLocal());
  if (x.inMinutes < 10) return t('az önce');
  if (x.inHours < 1) return t('{n} dakika önce', {'n': x.inMinutes});
  if (x.inDays < 1) return t('{n} saat önce', {'n': x.inHours});
  if (x.inDays < 30) return t('{n} gün önce', {'n': x.inDays});
  return dateText(d);
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
