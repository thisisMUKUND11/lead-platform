import 'package:flutter/material.dart';

import 'models.dart';

/// Central app theme.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3B5BDB),
    brightness: Brightness.light,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFFF6F7FB),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
  );
}

/// Colors for each lead status chip.
Color statusColor(LeadStatus status, ColorScheme scheme) {
  switch (status) {
    case LeadStatus.newLead:
      return Colors.blueGrey;
    case LeadStatus.contacted:
      return Colors.indigo;
    case LeadStatus.qualified:
      return Colors.teal;
    case LeadStatus.proposal:
      return Colors.orange;
    case LeadStatus.won:
      return Colors.green;
    case LeadStatus.lost:
      return Colors.red;
  }
}
