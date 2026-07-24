import 'package:flutter/material.dart';

import '../theme.dart';

/// The app's logo mark: a rounded gradient tile with a hub icon.
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
        borderRadius: BorderRadius.circular(size * 0.28),
        border: onGradient
            ? Border.all(color: Colors.white.withValues(alpha: 0.5))
            : null,
      ),
      child: Icon(
        Icons.hub_rounded,
        color: Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
