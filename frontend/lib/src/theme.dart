import 'package:flutter/material.dart';

import 'models.dart';

const kBrandSeed = Color(0xFF4F46E5); // indigo
const kBrandAccent = Color(0xFF7C3AED); // violet

/// Central app theme (Material 3, light).
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kBrandSeed,
    brightness: Brightness.light,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);

  return base.copyWith(
    scaffoldBackgroundColor: const Color(0xFFF7F8FC),
    textTheme: base.textTheme.apply(
      displayColor: const Color(0xFF1A1B25),
      bodyColor: const Color(0xFF2A2B37),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Color(0xFF1A1B25),
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF3F4FB),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E4F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBrandSeed, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE9EAF3)),
      ),
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFFECEDF4)),
  );
}

/// The brand gradient used behind the auth pages.
const kBrandGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kBrandSeed, kBrandAccent],
);

/// Colors for each lead status chip.
Color statusColor(LeadStatus status, ColorScheme scheme) {
  switch (status) {
    case LeadStatus.newLead:
      return const Color(0xFF64748B);
    case LeadStatus.contacted:
      return const Color(0xFF4F46E5);
    case LeadStatus.qualified:
      return const Color(0xFF0EA5A6);
    case LeadStatus.proposal:
      return const Color(0xFFEA580C);
    case LeadStatus.won:
      return const Color(0xFF16A34A);
    case LeadStatus.lost:
      return const Color(0xFFDC2626);
  }
}
