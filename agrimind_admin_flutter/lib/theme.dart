import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminColors {
  static const emerald700 = Color(0xFF047857);
  static const emerald600 = Color(0xFF059669);
  static const emerald500 = Color(0xFF10b981);
  static const emerald400 = Color(0xFF34d399);
  static const emerald300 = Color(0xFF6ee7b7);

  static const indigo600  = Color(0xFF4f46e5);
  static const indigo500  = Color(0xFF6366f1);
  static const violet600  = Color(0xFF7c3aed);
  static const violet500  = Color(0xFF8b5cf6);
  static const violet400  = Color(0xFFa78bfa);
  static const violet300  = Color(0xFFc4b5fd);

  static const amber500   = Color(0xFFf59e0b);
  static const red500     = Color(0xFFef4444);

  static const slate950   = Color(0xFF020617);
  static const slate900   = Color(0xFF0f172a);
  static const slate800   = Color(0xFF1e293b);
  static const slate700   = Color(0xFF334155);
  static const slate600   = Color(0xFF475569);
  static const slate500   = Color(0xFF64748b);
  static const slate400   = Color(0xFF94a3b8);
  static const slate300   = Color(0xFFcbd5e1);
  static const slate200   = Color(0xFFe2e8f0);
  static const slate100   = Color(0xFFf1f5f9);

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AdminTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AdminColors.emerald500,
      secondary: AdminColors.indigo600,
      surface: AdminColors.slate800,
      onSurface: AdminColors.slate100,
      error: AdminColors.red500,
    ),
    scaffoldBackgroundColor: AdminColors.slate950,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(color: AdminColors.slate100, fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.outfit(color: AdminColors.slate100, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.outfit(color: AdminColors.slate100, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.outfit(color: AdminColors.slate100, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: AdminColors.slate100),
      bodyMedium: GoogleFonts.inter(color: AdminColors.slate400),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.slate900,
      foregroundColor: AdminColors.slate100,
      elevation: 0,
    ),
  );
}
