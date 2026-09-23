// ═══════════════════════════════════════════════════════════════════
// AgriMind Flutter App — Theme & Color System
// ═══════════════════════════════════════════════════════════════════
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
  static const slate200   = Color(0xFFe2e8f0);
  static const slate100   = Color(0xFFf1f5f9);
  static const slate50    = Color(0xFFf8fafc);

  // Gradients
  static const brandGradient = LinearGradient(
    colors: [emerald700, emerald500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const headerGradient = LinearGradient(
    colors: [emerald900, emerald800],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const bgGradient = LinearGradient(
    colors: [slate950, slate900, Color(0xFF0a1628)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AgriTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AgriColors.emerald500,
      secondary: AgriColors.emerald400,
      surface: AgriColors.slate800,
      onSurface: AgriColors.slate100,
      error: AgriColors.red600,
    ),
    scaffoldBackgroundColor: AgriColors.slate950,
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.outfit(
        color: AgriColors.slate100,
        fontWeight: FontWeight.w800,
      ),
      displayMedium: GoogleFonts.outfit(
        color: AgriColors.slate100,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: GoogleFonts.outfit(
        color: AgriColors.slate100,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.outfit(
        color: AgriColors.slate100,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(color: AgriColors.slate100),
      bodyMedium: GoogleFonts.inter(color: AgriColors.slate400),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AgriColors.slate900,
      foregroundColor: AgriColors.slate100,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.outfit(
        color: AgriColors.emerald400,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: CardThemeData(
      color: AgriColors.slate800,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AgriColors.emerald500, width: 1.5),
      ),
      hintStyle: GoogleFonts.inter(color: AgriColors.slate600),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AgriColors.emerald600,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700),
      ),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: AgriColors.emerald400,
      unselectedLabelColor: AgriColors.slate400,
      indicator: UnderlineTabIndicator(
        borderSide: const BorderSide(color: AgriColors.emerald500, width: 2.5),
        borderRadius: BorderRadius.circular(2),
      ),
      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(
      color: Colors.white.withOpacity(0.08),
      thickness: 1,
    ),
  );
}
