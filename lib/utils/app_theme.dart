import 'package:flutter/material.dart';

class AppColors {
  // Medical Blue / Cyan Brand
  static const Color primary = Color(0xFF0284C7); // Sky 600
  static const Color primaryDark = Color(0xFF0369A1); // Sky 700
  static const Color primaryLight = Color(0xFFE0F2FE); // Sky 100
  static const Color primaryDeep = Color(0xFF075985); // Sky 800

  // Secondary Accents
  static const Color teal = Color(0xFF0D9488); // Teal 600
  static const Color tealDark = Color(0xFF0F766E); // Teal 700
  static const Color tealLight = Color(0xFFCCFBF1); // Teal 100
  static const Color indigo = Color(0xFF6366F1); // Indigo 500
  static const Color indigoLight = Color(0xFFE0E7FF); // Indigo 100
  static const Color emerald = Color(0xFF10B981); // Emerald 500
  static const Color emeraldLight = Color(0xFFD1FAE5); // Emerald 100
  static const Color amber = Color(0xFFF59E0B); // Amber 500
  static const Color amberLight = Color(0xFFFEF3C7); // Amber 100
  static const Color rose = Color(0xFFE11D48); // Rose 600
  static const Color roseLight = Color(0xFFFFE4E6); // Rose 100

  // Neutral Palette
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9); // Slate 100
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color borderSubtle = Color(0xFFCBD5E1); // Slate 300

  // Text Colors
  static const Color textMain = Color(0xFF0F172A); // Slate 900
  static const Color textBody = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
  static const Color textLight = Color(0xFF94A3B8); // Slate 400
}

class AppGradients {
  static const LinearGradient primary = LinearGradient(
    colors: [Color(0xFF0284C7), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerAdmin = LinearGradient(
    colors: [Color(0xFF0369A1), Color(0xFF0284C7), Color(0xFF0D9488)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerDoctor = LinearGradient(
    colors: [Color(0xFF047857), Color(0xFF10B981), Color(0xFF14B8A6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerPatient = LinearGradient(
    colors: [Color(0xFF4338CA), Color(0xFF6366F1), Color(0xFF0284C7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emergency = LinearGradient(
    colors: [Color(0xFFBE123C), Color(0xFFE11D48), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGlow = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class AppShadows {
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.02),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final List<BoxShadow> hover = [
    BoxShadow(
      color: const Color(0xFF0284C7).withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> floating = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        error: AppColors.rose,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: null, // Default system font with clean weight styling
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textMain,
        iconTheme: IconThemeData(color: AppColors.textMain),
        titleTextStyle: TextStyle(
          color: AppColors.textMain,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 0,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.rose),
        ),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
      ),
    );
  }
}
