import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'i18n.dart';
import 'oa_theme.dart';
import 'version.dart';

/// OA Labs mühürü: iki halka, aralarında dönen "OA LABS · ATÖLYE · 2026" yazısı, ortada A.
/// Yazı 40 saniyede bir tur döner; sistemde hareketi azaltma açıksa durur.
class OALabsSeal extends StatefulWidget {
  const OALabsSeal({
    super.key,
    this.size = 96,
    required this.color,
    required this.accent,
    this.text = 'OA LABS · ATÖLYE · 2026 · OA LABS · ATÖLYE · 2026 · ',
  });
  final double size;
  final Color color;
  final Color accent;
  final String text;

  @override
  State<OALabsSeal> createState() => _OALabsSealState();
}

class _OALabsSealState extends State<OALabsSeal> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(seconds: 40));
  List<TextPainter> _glyphs = const [];

  void _layoutGlyphs() {
    _glyphs = widget.text
        .split('')
        .map((ch) => TextPainter(
              text: TextSpan(
                text: ch,
                style: TextStyle(color: widget.color, fontSize: 11, fontWeight: FontWeight.w600, height: 1),
              ),
              textDirection: TextDirection.ltr,
            )..layout())
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _layoutGlyphs();
  }

  @override
  void didUpdateWidget(OALabsSeal old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text || old.color != widget.color) _layoutGlyphs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _turn.stop();
    } else if (!_turn.isAnimating) {
      _turn.repeat();
    }
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'OA Labs',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _turn,
          builder: (context, _) => CustomPaint(
            painter: _OALabsSealPainter(
              color: widget.color,
              accent: widget.accent,
              glyphs: _glyphs,
              turn: _turn.value * 2 * math.pi,
            ),
          ),
        ),
      ),
    );
  }
}

class _OALabsSealPainter extends CustomPainter {
  _OALabsSealPainter({required this.color, required this.accent, required this.glyphs, required this.turn});
  final Color color;
  final Color accent;
  final List<TextPainter> glyphs;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    // Çizim 140 birimlik kutuda, merkez (0,0).
    final s = size.shortestSide / 140;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(s);
    final ring = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset.zero, 64, ring);
    canvas.drawCircle(Offset.zero, 42, ring);
    if (glyphs.isNotEmpty) {
      final step = 2 * math.pi / glyphs.length;
      for (var i = 0; i < glyphs.length; i++) {
        final g = glyphs[i];
        canvas.save();
        canvas.rotate(turn + i * step);
        canvas.translate(0, -53);
        g.paint(canvas, Offset(-g.width / 2, -g.height / 2));
        canvas.restore();
      }
    }
    final a = Path()
      ..moveTo(-15, 18)
      ..lineTo(0, -20)
      ..lineTo(15, 18);
    canvas.drawPath(
      a,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OALabsSealPainter old) =>
      old.turn != turn || old.color != color || old.accent != accent || old.glyphs != glyphs;
}


/// "Uygulama hakkında" kartı (OA Radyo ile aynı): dönen OA Labs mührü, sürüm, sistem, altyapı.
class AboutCard extends StatelessWidget {
  const AboutCard({super.key});

  static String get _system {
    final name = switch (Platform.operatingSystem) {
      'windows' => 'Windows',
      'android' => 'Android',
      'macos' => 'macOS',
      'linux' => 'Linux',
      final o => o,
    };
    return '$name · ${Platform.operatingSystemVersion.replaceAll('"', '')}';
  }

  static String get _dart => RegExp(r'^(\S+)').firstMatch(Platform.version)?.group(1) ?? '';

  Widget _row(String k, String v) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: OA.line))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 84, child: Text(k, style: oaBody(14, color: OA.faint))),
          Expanded(
            child: SelectableText(v,
                style: oaBody(14, weight: FontWeight.w600).copyWith(fontFamily: 'Consolas', fontFamilyFallback: const ['monospace'])),
          ),
        ]),
      );

  @override
  Widget build(BuildContext context) => OACard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            OALabsSeal(
              size: 92,
              color: OA.text,
              accent: OA.amber,
              text: L.en
                  ? 'OA LABS · WORKSHOP · 2026 · OA LABS · WORKSHOP · 2026 · '
                  : 'OA LABS · ATÖLYE · 2026 · OA LABS · ATÖLYE · 2026 · ',
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t('Uygulama hakkında'), style: oaBody(17, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(t('OA Labs atölyesinde özenle yapıldı.'), style: oaBody(15, color: OA.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          _row(t('Sürüm'), appVersion == '0.0.0' ? t('geliştirme') : appVersion),
          _row(t('Sistem'), _system),
          _row(t('Altyapı'), 'Flutter · Dart $_dart'),
          const SizedBox(height: 12),
          Text('© ${DateTime.now().year} Oğuzhan Aydın', style: oaBody(14, color: OA.muted)),
        ]),
      );
}
