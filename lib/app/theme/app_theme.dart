import 'package:flutter/material.dart';

abstract final class AppColors {
  static const darkBackground = Color(0xFF12142B);
  static const darkSurface = Color(0xFF0E1024);
  static const darkGlass = Color(0x0AFFFFFF);
  static const darkGlassStrong = Color(0x12FFFFFF);
  static const darkBorder = Color(0x14FFFFFF);
  static const darkInput = Color(0x0AFFFFFF);
  static const darkInputBorder = Color(0x1AFFFFFF);
  static const darkText = Color(0xFFFFFFFF);
  static const darkTextMuted = Color(0x8AFFFFFF);
  static const lightBackground = Color(0xFFF4F5FA);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightGlass = Color(0xBFFFFFFF);
  static const lightGlassStrong = Color(0xE6FFFFFF);
  static const lightBorder = Color(0x1A11142D);
  static const lightInput = Color(0xFFFFFFFF);
  static const lightInputBorder = Color(0x2911142D);
  static const lightText = Color(0xFF14151C);
  static const lightTextMuted = Color(0x9911152D);
  static const violet = Color(0xFF7C3AED);
  static const violetHover = Color(0xFF8B5CF6);
  static const violetLightText = Color(0xFF6D28D9);
  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
}

abstract final class AppRadii {
  static const small = 8.0;
  static const medium = 12.0;
  static const large = 16.0;
  static const extraLarge = 20.0;
}

@immutable
class CarCareTheme extends ThemeExtension<CarCareTheme> {
  const CarCareTheme({
    required this.shellBackground,
    required this.shellSurface,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.mutedText,
    required this.inputBackground,
  });
  final Color shellBackground;
  final Color shellSurface;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;
  final Color mutedText;
  final Color inputBackground;

  static CarCareTheme of(BuildContext context) =>
      Theme.of(context).extension<CarCareTheme>()!;

  @override
  CarCareTheme copyWith({
    Color? shellBackground,
    Color? shellSurface,
    Color? glass,
    Color? glassStrong,
    Color? glassBorder,
    Color? mutedText,
    Color? inputBackground,
  }) => CarCareTheme(
    shellBackground: shellBackground ?? this.shellBackground,
    shellSurface: shellSurface ?? this.shellSurface,
    glass: glass ?? this.glass,
    glassStrong: glassStrong ?? this.glassStrong,
    glassBorder: glassBorder ?? this.glassBorder,
    mutedText: mutedText ?? this.mutedText,
    inputBackground: inputBackground ?? this.inputBackground,
  );

  @override
  CarCareTheme lerp(CarCareTheme? other, double t) {
    if (other == null) return this;
    return CarCareTheme(
      shellBackground: Color.lerp(shellBackground, other.shellBackground, t)!,
      shellSurface: Color.lerp(shellSurface, other.shellSurface, t)!,
      glass: Color.lerp(glass, other.glass, t)!,
      glassStrong: Color.lerp(glassStrong, other.glassStrong, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData get light => _theme(Brightness.light);
  static ThemeData get dark => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surface = dark ? AppColors.darkSurface : AppColors.lightSurface;
    final text = dark ? AppColors.darkText : AppColors.lightText;
    final border = dark ? AppColors.darkBorder : AppColors.lightBorder;
    final inputBorder = dark
        ? AppColors.darkInputBorder
        : AppColors.lightInputBorder;
    final extension = CarCareTheme(
      shellBackground: background,
      shellSurface: surface,
      glass: dark ? AppColors.darkGlass : AppColors.lightGlass,
      glassStrong: dark
          ? AppColors.darkGlassStrong
          : AppColors.lightGlassStrong,
      glassBorder: border,
      mutedText: dark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
      inputBackground: dark ? AppColors.darkInput : AppColors.lightInput,
    );
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.violet,
      brightness: brightness,
      surface: background,
    );
    final scheme = base.copyWith(
      primary: AppColors.violet,
      onPrimary: Colors.white,
      primaryContainer: dark
          ? const Color(0x337C3AED)
          : const Color(0xFFEDE9FE),
      onPrimaryContainer: dark
          ? const Color(0xFFEDE9FE)
          : AppColors.violetLightText,
      secondary: AppColors.blue,
      onSecondary: Colors.white,
      tertiary: AppColors.green,
      error: AppColors.red,
      surface: background,
      onSurface: text,
      onSurfaceVariant: extension.mutedText,
      outline: inputBorder,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      extensions: [extension],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: surface,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        shape: Border(bottom: BorderSide(color: border)),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: ThemeData(brightness: brightness).textTheme
          .apply(bodyColor: text, displayColor: text),
      cardTheme: CardThemeData(
        color: extension.glass,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.large),
          side: BorderSide(color: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: extension.inputBackground,
        hintStyle: TextStyle(color: extension.mutedText),
        prefixIconColor: extension.mutedText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: BorderSide(color: inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
          borderSide: const BorderSide(color: AppColors.violetHover),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.violet,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.medium),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: extension.mutedText),
      ),
      dividerColor: border,
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.violetHover,
      ),
    );
  }
}
