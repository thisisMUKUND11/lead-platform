import 'package:flutter/material.dart';

/// A colored circular avatar showing a name's initial. The color is derived
/// deterministically from the name so the same person is always the same hue.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {this.size = 34, this.color, super.key});

  final String name;
  final double size;
  final Color? color;

  static const palette = [
    Color(0xFF4F46E5),
    Color(0xFF0EA5A6),
    Color(0xFFEA580C),
    Color(0xFF7C3AED),
    Color(0xFF2563EB),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final c = color ?? palette[name.hashCode.abs() % palette.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
