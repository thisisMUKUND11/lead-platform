import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's logo mark: a rounded gradient tile with a network-hub glyph.
///
/// The glyph is drawn to match `web/favicon.svg` exactly (same geometry), so
/// the in-app logo and the browser address-bar icon are identical.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 48, this.onGradient = false, super.key});

  final double size;

  /// When placed on the gradient background, render as a translucent white tile.
  final bool onGradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: onGradient ? null : kBrandGradient,
        color: onGradient ? Colors.white.withValues(alpha: 0.18) : null,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: onGradient
            ? Border.all(color: Colors.white.withValues(alpha: 0.5))
            : null,
      ),
      child: CustomPaint(
        size: Size.square(size),
        painter: _HubPainter(),
      ),
    );
  }
}

/// Draws the same network hub as favicon.svg (viewBox 0..100), scaled to size:
/// a central node with four diagonal nodes joined by lines, in white.
class _HubPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width; // square
    Offset p(double x, double y) => Offset(x / 100 * s, y / 100 * s);

    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = Colors.white;

    const center = Offset(50, 50);
    const nodes = [
      Offset(30, 30),
      Offset(70, 30),
      Offset(30, 70),
      Offset(70, 70),
    ];

    for (final n in nodes) {
      canvas.drawLine(p(center.dx, center.dy), p(n.dx, n.dy), line);
    }
    canvas.drawCircle(p(center.dx, center.dy), s * 0.10, dot);
    for (final n in nodes) {
      canvas.drawCircle(p(n.dx, n.dy), s * 0.07, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
