import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OA Labs renkleri: oalabs.dev site.css ile birebir (tek tema: koyu).
class OA {
  OA._();
  static const bg = Color(0xFF0D0F16);
  static const bg2 = Color(0xFF11131C);
  static const surface = Color(0xFF151824);
  static const surface2 = Color(0xFF1C2030);
  static const line = Color(0xFF1E2232);
  static const border = Color(0xFF262B3D);
  static const border2 = Color(0xFF2A2F43);
  static const text = Color(0xFFEEEAE2);
  static const text2 = Color(0xFFB7BACA);
  static const muted = Color(0xFF9EA2B3);
  static const faint = Color(0xFF7E8296);
  static const amber = Color(0xFFF2A541);
  static const amberHi = Color(0xFFF7BF6E);
  static const amberInk = Color(0xFF14110A);
  static const green = Color(0xFF5BC48C);
  static const blue = Color(0xFF6EA8FE);
  static const danger = Color(0xFFF08A7E);
  static const soonInk = Color(0xFF7CC88A);
  static const soonBg = Color(0x247CC88A);
  static const betaInk = Color(0xFF8FB8FF);
  static const betaBg = Color(0x246EA8FE);
  static const tileDim = Color(0xFF5D606B);
}

/// Başlık yazısı: Bricolage Grotesque 800.
TextStyle oaDisplay(double size, {Color color = OA.text}) => GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: -0.02 * size,
      height: 1.15,
    );

/// Gövde yazısı: DM Sans.
TextStyle oaBody(double size, {Color color = OA.text, FontWeight weight = FontWeight.w400, double height = 1.45}) =>
    GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color, height: height);

ThemeData oaTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    scaffoldBackgroundColor: OA.bg,
    colorScheme: const ColorScheme.dark(
      primary: OA.amber,
      onPrimary: OA.amberInk,
      secondary: OA.amber,
      onSecondary: OA.amberInk,
      surface: OA.surface,
      onSurface: OA.text,
      error: OA.danger,
    ),
  );
  return base.copyWith(
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).apply(bodyColor: OA.text, displayColor: OA.text),
    dividerColor: OA.line,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: OA.surface2,
      contentTextStyle: oaBody(15),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: OA.border)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: OA.amber, linearTrackColor: OA.surface2),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OA.bg,
      hintStyle: oaBody(17, color: OA.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OA.border2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OA.amber, width: 2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: OA.border2)),
    ),
  );
}

enum OAButtonKind { primary, secondary, danger }

/// Tam yuvarlak uçlu OA düğmesi. [big]: 54 px (ekranın ana eylemi), yoksa 44 px.
class OAButton extends StatelessWidget {
  const OAButton(this.label, {super.key, this.onPressed, this.kind = OAButtonKind.secondary, this.big = false});
  final String label;
  final VoidCallback? onPressed;
  final OAButtonKind kind;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final h = big ? 54.0 : 44.0;
    final style = oaBody(big ? 17 : 15, weight: FontWeight.w600, height: 1);
    final pad = EdgeInsets.symmetric(horizontal: big ? 26 : 18);
    if (kind == OAButtonKind.primary) {
      return FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: OA.amber,
          foregroundColor: OA.amberInk,
          disabledBackgroundColor: OA.surface2,
          disabledForegroundColor: OA.faint,
          minimumSize: Size(0, h),
          padding: pad,
          shape: const StadiumBorder(),
          textStyle: style,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: kind == OAButtonKind.danger ? OA.danger : OA.text,
        disabledForegroundColor: OA.faint,
        minimumSize: Size(0, h),
        padding: pad,
        shape: const StadiumBorder(),
        side: const BorderSide(color: OA.border2),
        textStyle: style,
      ),
      child: Text(label),
    );
  }
}

/// Kart: surface zemin, 1 px kenar, 20 px köşe.
class OACard extends StatelessWidget {
  const OACard({super.key, required this.child, this.padding = const EdgeInsets.all(20)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: OA.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OA.border),
        ),
        child: child,
      );
}

/// Küçük etiket (Yakında, Beta, Yalnız Windows).
class OAChip extends StatelessWidget {
  const OAChip(this.label, {super.key, this.ink = OA.text2, this.bg = OA.surface2});
  final String label;
  final Color ink;
  final Color bg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(label, style: oaBody(13, color: ink, weight: FontWeight.w600, height: 1.1)),
      );
}

/// OA Labs işareti: oalabs.dev'deki dört karolu ızgara (sol üstte O, sağ altta amber karoda A).
class OAMark extends StatelessWidget {
  const OAMark({super.key, this.size = 32, this.ground = OA.bg});
  final double size;
  final Color ground;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _MarkPainter(ground)));
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.ground);
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 220);
    RRect tile(double x, double y) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, 96, 96), const Radius.circular(25));
    final fill = Paint()..color = ground;
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final t in [tile(6, 6), tile(118, 6), tile(6, 118)]) {
      canvas.drawRRect(t, fill);
    }
    canvas.drawRRect(tile(6, 6), stroke(OA.text, 8.4));
    canvas.drawCircle(const Offset(54, 54), 25.4, stroke(OA.text, 11.3));
    canvas.drawRRect(tile(118, 6), stroke(OA.tileDim, 8.4));
    canvas.drawRRect(tile(6, 118), stroke(OA.tileDim, 8.4));
    canvas.drawRRect(tile(118, 118), Paint()..color = OA.amber);
    final a = Path()
      ..moveTo(140.6, 194.3)
      ..lineTo(166, 137.7)
      ..lineTo(191.4, 194.3);
    canvas.drawPath(a, stroke(OA.amberInk, 11.3));
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.ground != ground;
}
