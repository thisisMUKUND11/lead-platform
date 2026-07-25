import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// A clean full-area loading state: a spinner with a "please wait" message.
class AppLoader extends StatelessWidget {
  const AppLoader({this.message = 'Please wait…', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            height: 44,
            width: 44,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 18),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// A blurred full-screen overlay with a "please wait" card. Use as a direct
/// child of a [Stack] (it is a [Positioned.fill]).
class BlurLoadingOverlay extends StatelessWidget {
  const BlurLoadingOverlay({this.message = 'Please wait…', super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            color: Colors.black.withValues(alpha: 0.18),
            alignment: Alignment.center,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    height: 36,
                    width: 36,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
