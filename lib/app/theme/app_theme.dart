import 'package:flutter/material.dart';

/// Mirrors the web app's `.landing-ops` accent token system
/// (`carcare.mn/app/globals.css`), which is what the live customer portal
/// (sidebar + page content alike) actually renders — see COWORK.md D-021.
/// Accent switched amber -> cyan on 2026-09-10 (web commit `f15b477`,
/// COWORK.md D-086) — the `accent*`/`onAccent` names below are no longer
/// amber-specific, only their old names briefly were.
abstract final class AppColors {
  static const darkBackground = Color(0xFF0B0D10); // --oc-carbon
  static const darkSurface = Color(0xFF0E1116); // --oc-panel
  static const darkGlass = Color(0x0AFFFFFF);
  static const darkGlassStrong = Color(0x12FFFFFF);
  static const darkBorder = Color(0xFF23272E); // --oc-line
  static const darkInput = Color(0x0AFFFFFF);
  static const darkInputBorder = Color(0xFF23272E); // --oc-line
  static const darkText = Color(0xFFF4F5F7); // --oc-ink
  static const darkTextMuted = Color(0xFFA7ADB6); // --oc-muted
  static const lightBackground = Color(0xFFF6F5F2); // --oc-carbon (light)
  static const lightSurface = Color(0xFFFFFFFF); // --oc-panel (light)
  static const lightGlass = Color(0xBFFFFFFF);
  static const lightGlassStrong = Color(0xE6FFFFFF);
  static const lightBorder = Color(0xFFE3E0DA); // --oc-line (light)
  static const lightInput = Color(0xFFFFFFFF);
  static const lightInputBorder = Color(0xFFE3E0DA); // --oc-line (light)
  static const lightText = Color(0xFF16171B); // --oc-ink (light)
  static const lightTextMuted = Color(0xFF5C6067); // --oc-muted (light)
  static const accent = Color(0xFF22D3EE); // --oc-accent
  static const accentHover = Color(0xFF67E8F9); // --oc-accent-hi
  static const accentLightText = Color(0xFF0E7490); // --oc-accent (light)
  static const onAccent = Color(0xFF14120C); // --oc-on-accent
  static const blue = Color(0xFF3B82F6);
  static const purple = Color(0xFFA855F7); // matches web's POSTPONED badge (purple-500)
  static const green = Color(0xFF3DDC97); // --oc-ok
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

/// A consistent, subtle push transition for every route on every platform: the
/// incoming page slides up a few pixels while easing from 98% to full size.
///
/// Deliberately transform-only — NO opacity fade. Pages here paint the glass
/// `GlassSurface` (a `BackdropFilter`); fading a subtree that contains a
/// backdrop filter isolates it in an opacity layer, which disables the blur for
/// the duration of the fade and then snaps it back on completion — a visible
/// flicker of the blurred background. Slides and scales are transform layers,
/// so the glass keeps compositing correctly throughout.
class _FadeSlidePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadeSlidePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
        child: child,
      ),
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
      seedColor: AppColors.accent,
      brightness: brightness,
      surface: background,
    );
    final scheme = base.copyWith(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      primaryContainer: dark
          ? const Color(0x3322D3EE)
          : const Color(0xFFCFFAFE),
      onPrimaryContainer: dark
          ? const Color(0xFF67E8F9)
          : AppColors.accentLightText,
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.iOS: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.macOS: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.windows: _FadeSlidePageTransitionsBuilder(),
          TargetPlatform.linux: _FadeSlidePageTransitionsBuilder(),
        },
      ),
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
          borderSide: const BorderSide(color: AppColors.accentHover),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.medium),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
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
        color: AppColors.accentHover,
      ),
    );
  }
}
