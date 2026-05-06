import 'package:flutter/material.dart';

const _seed = Color(0xFF4C6414);
const _brandGreen = Color(0xFF628141);
const _brandGreenDark = Color(0xFF3D5A27);
const _brandGreenLight = Color(0xFFE8EFCF);

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFF5F7F0),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _brandGreenDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
    extensions: const [
      AppPalette(
        brand: _brandGreen,
        brandStrong: _brandGreenDark,
        brandSoft: _brandGreenLight,
        surfaceCard: Colors.white,
        surfaceMuted: Color(0xFFF5F7F0),
        textPrimary: Colors.black87,
        textSecondary: Color(0xFF6B7280),
        textFaint: Color(0x66000000),
        chartGrid: Color(0xFFE5E7EB),
        danger: Color(0xFFE74C3C),
        warning: Color(0xFFE85D04),
      ),
    ],
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    brightness: Brightness.dark,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter',
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFF0F1310),
    cardTheme: CardThemeData(
      color: const Color(0xFF1B211C),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1B211C),
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(
        color: Color(0xFF2A312B), thickness: 1),
    extensions: const [
      AppPalette(
        brand: Color(0xFF8FB069),
        brandStrong: Color(0xFFB8D08C),
        brandSoft: Color(0xFF2A3422),
        surfaceCard: Color(0xFF1B211C),
        surfaceMuted: Color(0xFF0F1310),
        textPrimary: Color(0xFFE8EAE6),
        textSecondary: Color(0xFF9AA39C),
        textFaint: Color(0x66E8EAE6),
        chartGrid: Color(0xFF2A312B),
        danger: Color(0xFFFF6B5C),
        warning: Color(0xFFFFA458),
      ),
    ],
  );
}

class AppPalette extends ThemeExtension<AppPalette> {
  final Color brand;
  final Color brandStrong;
  final Color brandSoft;
  final Color surfaceCard;
  final Color surfaceMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textFaint;
  final Color chartGrid;
  final Color danger;
  final Color warning;

  const AppPalette({
    required this.brand,
    required this.brandStrong,
    required this.brandSoft,
    required this.surfaceCard,
    required this.surfaceMuted,
    required this.textPrimary,
    required this.textSecondary,
    required this.textFaint,
    required this.chartGrid,
    required this.danger,
    required this.warning,
  });

  @override
  AppPalette copyWith({
    Color? brand,
    Color? brandStrong,
    Color? brandSoft,
    Color? surfaceCard,
    Color? surfaceMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textFaint,
    Color? chartGrid,
    Color? danger,
    Color? warning,
  }) =>
      AppPalette(
        brand: brand ?? this.brand,
        brandStrong: brandStrong ?? this.brandStrong,
        brandSoft: brandSoft ?? this.brandSoft,
        surfaceCard: surfaceCard ?? this.surfaceCard,
        surfaceMuted: surfaceMuted ?? this.surfaceMuted,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textFaint: textFaint ?? this.textFaint,
        chartGrid: chartGrid ?? this.chartGrid,
        danger: danger ?? this.danger,
        warning: warning ?? this.warning,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      brand: Color.lerp(brand, other.brand, t)!,
      brandStrong: Color.lerp(brandStrong, other.brandStrong, t)!,
      brandSoft: Color.lerp(brandSoft, other.brandSoft, t)!,
      surfaceCard: Color.lerp(surfaceCard, other.surfaceCard, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textFaint: Color.lerp(textFaint, other.textFaint, t)!,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension AppPaletteX on BuildContext {
  AppPalette get palette {
    final ext = Theme.of(this).extension<AppPalette>();
    if (ext != null) return ext;
    return Theme.of(this).brightness == Brightness.dark
        ? buildDarkTheme().extension<AppPalette>()!
        : buildLightTheme().extension<AppPalette>()!;
  }
}
