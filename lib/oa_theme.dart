import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// OA Labs renkleri: koyu tema oalabs.dev site.css ile birebir; açık tema aynı tonların krem zeminli hâli
/// (OA Radyo ve Terazi ile aynı). [koyu] açılışta ve tema değişince Settings tarafından ayarlanır.
class OA {
  OA._();
  static bool koyu = true;
  static Color _r(int d, int l) => Color(koyu ? d : l);
  static Color get bg => _r(0xFF0D0F16, 0xFFF6F3EC);
  static Color get bg2 => _r(0xFF11131C, 0xFFEFEBE2);
  static Color get surface => _r(0xFF151824, 0xFFFFFFFF);
  static Color get surface2 => _r(0xFF1C2030, 0xFFF0ECE3);
  static Color get line => _r(0xFF1E2232, 0xFFE7E1D5);
  static Color get border => _r(0xFF262B3D, 0xFFE3DDD0);
  static Color get border2 => _r(0xFF2A2F43, 0xFFD6CFBF);
  static Color get text => _r(0xFFEEEAE2, 0xFF1A1710);
  static Color get text2 => _r(0xFFB7BACA, 0xFF4A4336);
  static Color get muted => _r(0xFF9EA2B3, 0xFF6B6457);
  static Color get faint => _r(0xFF7E8296, 0xFF8F8878);
  static Color get amber => _r(0xFFF2A541, 0xFFE0901F);
  static Color get amberHi => _r(0xFFF7BF6E, 0xFFC97A12);
  static const amberInk = Color(0xFF14110A);
  static Color get green => _r(0xFF5BC48C, 0xFF2E9D63);
  static Color get blue => _r(0xFF6EA8FE, 0xFF3B7DDB);
  static Color get danger => _r(0xFFF08A7E, 0xFFD2553F);
  static Color get soonInk => _r(0xFF7CC88A, 0xFF2E8B4A);
  static Color get soonBg => _r(0x247CC88A, 0x262E9D63);
  static Color get betaInk => _r(0xFF8FB8FF, 0xFF2F68C4);
  static Color get betaBg => _r(0x246EA8FE, 0x263B7DDB);
  static Color get tileDim => _r(0xFF5D606B, 0xFFB5AE9F);
}

/// Başlık yazısı: Bricolage Grotesque 800.
TextStyle oaDisplay(double size, {Color? color}) => GoogleFonts.bricolageGrotesque(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color ?? OA.text,
      letterSpacing: -0.02 * size,
      height: 1.15,
    );

/// Gövde yazısı: DM Sans.
TextStyle oaBody(double size, {Color? color, FontWeight weight = FontWeight.w400, double height = 1.45}) =>
    GoogleFonts.dmSans(fontSize: size, fontWeight: weight, color: color ?? OA.text, height: height);

ThemeData oaTheme() {
  final base = ThemeData(
    brightness: OA.koyu ? Brightness.dark : Brightness.light,
    useMaterial3: true,
    scaffoldBackgroundColor: OA.bg,
    colorScheme: (OA.koyu ? ColorScheme.dark : ColorScheme.light)(
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
      backgroundColor: OA.koyu ? OA.surface2 : const Color(0xFF1A1710),
      contentTextStyle: oaBody(15, color: OA.koyu ? null : const Color(0xFFF6F3EC)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: OA.border)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: OA.amber, linearTrackColor: OA.surface2),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OA.bg,
      hintStyle: oaBody(17, color: OA.faint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: OA.border2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: OA.amber, width: 2)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: OA.border2)),
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
        side: BorderSide(color: OA.border2),
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
  OAChip(this.label, {super.key, Color? ink, Color? bg})
      : ink = ink ?? OA.text2,
        bg = bg ?? OA.surface2;
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
  OAMark({super.key, this.size = 32, Color? ground}) : ground = ground ?? OA.bg;
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
