import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AgriColors {
  static const emerald900 = Color(0xFF064e3b);
  static const emerald800 = Color(0xFF065f46);
  static const emerald700 = Color(0xFF047857);
  static const emerald600 = Color(0xFF059669);
  static const emerald500 = Color(0xFF10b981);
  static const emerald400 = Color(0xFF34d399);
  static const emerald300 = Color(0xFF6ee7b7);
  static const emerald100 = Color(0xFFd1fae5);
  static const emerald50  = Color(0xFFecfdf5);

  static const amber600   = Color(0xFFd97706);
  static const amber500   = Color(0xFFf59e0b);
  static const amber100   = Color(0xFFfef3c7);

  static const red600     = Color(0xFFdc2626);
  static const red100     = Color(0xFFfee2e2);

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
  static const slate50    = Color(0xFFf8fafc);

  static const brandGradient = LinearGradient(
    colors: [emerald700, emerald500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF1e293b), Color(0xFF0f172a)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AgriTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AgriColors.emerald500,
      secondary: AgriColors.emerald400,
      surface: AgriColors.slate800,
      onSurface: AgriColors.slate100,
      error: AgriColors.red600,
    ),
    scaffoldBackgroundColor: AgriColors.slate950,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(color: AgriColors.slate100, fontWeight: FontWeight.w800),
      displayMedium: GoogleFonts.outfit(color: AgriColors.slate100, fontWeight: FontWeight.w700),
      titleLarge: GoogleFonts.outfit(color: AgriColors.slate100, fontWeight: FontWeight.w700),
      titleMedium: GoogleFonts.outfit(color: AgriColors.slate100, fontWeight: FontWeight.w600),
      bodyLarge: GoogleFonts.inter(color: AgriColors.slate100),
      bodyMedium: GoogleFonts.inter(color: AgriColors.slate400),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AgriColors.slate900,
      foregroundColor: AgriColors.slate100,
      elevation: 0,
    ),
  );
}
