import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/glass_color.dart';
import 'glass_colors.dart';

/// The bundled Sofia Sans superfamily. The files are variable fonts, so each
/// weight is also set on the `wght` axis. Change weight with [withWeight].
abstract final class CorkFonts {
  static const sansFamily = 'Sofia Sans';
  static const condensedFamily = 'Sofia Sans Condensed';
  static const extraCondensedFamily = 'Sofia Sans Extra Condensed';

  static TextStyle sans({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) => _face(sansFamily, size, lineHeight, weight, letterSpacing, color);

  static TextStyle condensed({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) => _face(condensedFamily, size, lineHeight, weight, letterSpacing, color);

  static TextStyle extraCondensed({
    required double size,
    required double lineHeight,
    required FontWeight weight,
    double letterSpacing = 0,
    Color? color,
  }) => _face(
    extraCondensedFamily,
    size,
    lineHeight,
    weight,
    letterSpacing,
    color,
  );

  static TextStyle withWeight(TextStyle style, FontWeight weight) =>
      style.copyWith(
        fontWeight: weight,
        fontVariations: [FontVariation.weight(weight.value.toDouble())],
      );

  static TextStyle _face(
    String family,
    double size,
    double lineHeight,
    FontWeight weight,
    double letterSpacing,
    Color? color,
  ) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    fontVariations: [FontVariation.weight(weight.value.toDouble())],
    letterSpacing: letterSpacing,
    color: color,
  );
}

/// Eleven-step slate ramp, darkest to lightest. Every neutral in Cork snaps
/// to one of these steps; surface containers and outlines are picked from it.
abstract final class Slate {
  static const s0 = Color(0xFF0E1214);
  static const s1 = Color(0xFF151A1D);
  static const s2 = Color(0xFF1B2124);
  static const s3 = Color(0xFF21282C);
  static const s4 = Color(0xFF293135);
  static const s5 = Color(0xFF343D42);
  static const s6 = Color(0xFF4F5A60);
  static const s7 = Color(0xFF76838A);
  static const s8 = Color(0xFFA3AEB3);
  static const s9 = Color(0xFFCDD4D6);
  static const s10 = Color(0xFFEDF0F0);

  static const ramp = [s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10];
}

/// Spacing in dp on a 4dp grid.
abstract final class CorkSpace {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Side gutter for every scrolling screen.
  static const double gutter = 16;
  static const double minTouch = 48;
}

abstract final class CorkRadius {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;

  static const BorderRadius card = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius field = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius sheet = BorderRadius.vertical(
    top: Radius.circular(lg),
  );
  static const BorderRadius dialog = BorderRadius.all(Radius.circular(xl));
}

/// Material 3 motion tokens. Callers check
/// `MediaQuery.disableAnimationsOf(context)` and cut to [Duration.zero].
abstract final class CorkMotion {
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 500);

  /// Chalk swipe drawing left to right on save.
  static const swipe = Duration(milliseconds: 350);

  static const standard = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
}

/// Custom tokens Material's ColorScheme has no slot for.
@immutable
class CorkTokens extends ThemeExtension<CorkTokens> {
  const CorkTokens({
    required this.score,
    required this.shell,
    required this.onShell,
    required this.onShellVariant,
    required this.shellIndicator,
    required this.onShellIndicator,
    required this.typeRed,
    required this.typeWhite,
    required this.typeRose,
    required this.typeSparkling,
    required this.typeDessert,
    required this.aromaFruit,
    required this.aromaFloral,
    required this.aromaHerbal,
    required this.aromaSpice,
    required this.aromaEarth,
    required this.aromaOak,
    required this.aromaYeast,
    required this.aromaOxidative,
    required this.badgeEarned,
    required this.badgeLocked,
    required this.scoreNumeral,
    required this.boardHeading,
  });

  /// Scores and prices, chalked in yellow like a pour price on a board.
  final Color score;

  /// The slate shell: app bar and navigation bar stay slate in both themes.
  final Color shell;
  final Color onShell;
  final Color onShellVariant;
  final Color shellIndicator;
  final Color onShellIndicator;

  /// Wine type series for stats. Still wines use their glass colour.
  final Color typeRed;
  final Color typeWhite;
  final Color typeRose;
  final Color typeSparkling;
  final Color typeDessert;

  /// Aroma wheel categories.
  final Color aromaFruit;
  final Color aromaFloral;
  final Color aromaHerbal;
  final Color aromaSpice;
  final Color aromaEarth;
  final Color aromaOak;
  final Color aromaYeast;
  final Color aromaOxidative;

  final Color badgeEarned;
  final Color badgeLocked;

  /// Overall score figure: condensed, tabular, in [score].
  final TextStyle scoreNumeral;

  /// Month headers and section heads, set in caps by the caller.
  final TextStyle boardHeading;

  /// Glass colour of a tasting. Identical in both themes: it is the wine.
  Color glass(GlassHue hue, GlassIntensity intensity) =>
      glassDisplayColor(hue, intensity);

  Color get tablecloth => glassTablecloth;

  /// Fixed dot diameters (dp) for score bands 1, 2, 3, 4, 5 in distributions.
  static const List<double> scoreDotRamp = [6, 9, 12, 16, 22];

  /// Chalk swipe geometry in dp.
  static const double swipeHeight = 6;
  static const double swipeWidth = 56;

  @override
  CorkTokens copyWith({Color? score, TextStyle? scoreNumeral}) => CorkTokens(
    score: score ?? this.score,
    shell: shell,
    onShell: onShell,
    onShellVariant: onShellVariant,
    shellIndicator: shellIndicator,
    onShellIndicator: onShellIndicator,
    typeRed: typeRed,
    typeWhite: typeWhite,
    typeRose: typeRose,
    typeSparkling: typeSparkling,
    typeDessert: typeDessert,
    aromaFruit: aromaFruit,
    aromaFloral: aromaFloral,
    aromaHerbal: aromaHerbal,
    aromaSpice: aromaSpice,
    aromaEarth: aromaEarth,
    aromaOak: aromaOak,
    aromaYeast: aromaYeast,
    aromaOxidative: aromaOxidative,
    badgeEarned: badgeEarned,
    badgeLocked: badgeLocked,
    scoreNumeral: scoreNumeral ?? this.scoreNumeral,
    boardHeading: boardHeading,
  );

  @override
  CorkTokens lerp(CorkTokens? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return CorkTokens(
      score: c(score, other.score),
      shell: c(shell, other.shell),
      onShell: c(onShell, other.onShell),
      onShellVariant: c(onShellVariant, other.onShellVariant),
      shellIndicator: c(shellIndicator, other.shellIndicator),
      onShellIndicator: c(onShellIndicator, other.onShellIndicator),
      typeRed: c(typeRed, other.typeRed),
      typeWhite: c(typeWhite, other.typeWhite),
      typeRose: c(typeRose, other.typeRose),
      typeSparkling: c(typeSparkling, other.typeSparkling),
      typeDessert: c(typeDessert, other.typeDessert),
      aromaFruit: c(aromaFruit, other.aromaFruit),
      aromaFloral: c(aromaFloral, other.aromaFloral),
      aromaHerbal: c(aromaHerbal, other.aromaHerbal),
      aromaSpice: c(aromaSpice, other.aromaSpice),
      aromaEarth: c(aromaEarth, other.aromaEarth),
      aromaOak: c(aromaOak, other.aromaOak),
      aromaYeast: c(aromaYeast, other.aromaYeast),
      aromaOxidative: c(aromaOxidative, other.aromaOxidative),
      badgeEarned: c(badgeEarned, other.badgeEarned),
      badgeLocked: c(badgeLocked, other.badgeLocked),
      scoreNumeral: TextStyle.lerp(scoreNumeral, other.scoreNumeral, t)!,
      boardHeading: TextStyle.lerp(boardHeading, other.boardHeading, t)!,
    );
  }
}

extension CorkThemeX on ThemeData {
  CorkTokens get cork => extension<CorkTokens>()!;
}

abstract final class CorkTheme {
  static const ColorScheme darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFEBCB6B),
    onPrimary: Color(0xFF2A2205),
    primaryContainer: Color(0xFF4A3D10),
    onPrimaryContainer: Color(0xFFF7E3A6),
    secondary: Color(0xFF94C2D3),
    onSecondary: Color(0xFF0B2A35),
    secondaryContainer: Color(0xFF1F4351),
    onSecondaryContainer: Color(0xFFC6E5F0),
    tertiary: Color(0xFFE9A6B4),
    onTertiary: Color(0xFF3D1520),
    tertiaryContainer: Color(0xFF5A2633),
    onTertiaryContainer: Color(0xFFFAD6DE),
    error: Color(0xFFF08C76),
    onError: Color(0xFF3E0E04),
    errorContainer: Color(0xFF6A2414),
    onErrorContainer: Color(0xFFFFD8CE),
    surface: Slate.s2,
    onSurface: Color(0xFFECE9E1),
    onSurfaceVariant: Color(0xFFA9B3B7),
    surfaceDim: Slate.s1,
    surfaceBright: Slate.s5,
    surfaceContainerLowest: Slate.s0,
    surfaceContainerLow: Slate.s1,
    surfaceContainer: Slate.s3,
    surfaceContainerHigh: Slate.s4,
    surfaceContainerHighest: Slate.s5,
    outline: Slate.s7,
    outlineVariant: Slate.s5,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFECE9E1),
    onInverseSurface: Slate.s3,
    inversePrimary: Color(0xFF7C6110),
    surfaceTint: Colors.transparent,
  );

  static const ColorScheme lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF7C6110),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFF6E0A0),
    onPrimaryContainer: Color(0xFF261C00),
    secondary: Color(0xFF2E6577),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFBFE6F4),
    onSecondaryContainer: Color(0xFF001F29),
    tertiary: Color(0xFF8C4256),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFFD9E0),
    onTertiaryContainer: Color(0xFF3A0716),
    error: Color(0xFFB3361E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD2),
    onErrorContainer: Color(0xFF3D0700),
    surface: Color(0xFFF1F2EF),
    onSurface: Slate.s2,
    onSurfaceVariant: Color(0xFF47525A),
    surfaceDim: Color(0xFFD5DAD8),
    surfaceBright: Color(0xFFF8F9F7),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEBEDEA),
    surfaceContainer: Color(0xFFE4E7E4),
    surfaceContainerHigh: Color(0xFFDDE1DF),
    surfaceContainerHighest: Color(0xFFD5DAD8),
    outline: Color(0xFF6E7A80),
    outlineVariant: Color(0xFFBEC7CB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Slate.s3,
    onInverseSurface: Color(0xFFECE9E1),
    inversePrimary: Color(0xFFEBCB6B),
    surfaceTint: Colors.transparent,
  );

  static ThemeData get dark => _build(darkScheme, _darkTokens());
  static ThemeData get light => _build(lightScheme, _lightTokens());

  static CorkTokens _darkTokens() => CorkTokens(
    score: darkScheme.primary,
    shell: Slate.s3,
    onShell: darkScheme.onSurface,
    onShellVariant: darkScheme.onSurfaceVariant,
    shellIndicator: darkScheme.primaryContainer,
    onShellIndicator: darkScheme.onPrimaryContainer,
    typeRed: glassDisplayColor(GlassHue.ruby, GlassIntensity.medium),
    typeWhite: glassDisplayColor(GlassHue.lemon, GlassIntensity.medium),
    typeRose: glassDisplayColor(GlassHue.salmon, GlassIntensity.medium),
    typeSparkling: darkScheme.secondary,
    typeDessert: glassDisplayColor(GlassHue.amber, GlassIntensity.medium),
    aromaFruit: const Color(0xFFE88A8A),
    aromaFloral: const Color(0xFFE9A6D0),
    aromaHerbal: const Color(0xFF9CCB8A),
    aromaSpice: const Color(0xFFE5A15C),
    aromaEarth: const Color(0xFFB9A48A),
    aromaOak: const Color(0xFFC9925E),
    aromaYeast: const Color(0xFFE8D9A0),
    aromaOxidative: const Color(0xFFA9B3B7),
    badgeEarned: darkScheme.primary,
    badgeLocked: Slate.s6,
    scoreNumeral: _scoreNumeral(darkScheme.primary),
    boardHeading: _boardHeading(darkScheme.onSurfaceVariant),
  );

  static CorkTokens _lightTokens() => CorkTokens(
    score: lightScheme.primary,
    shell: Slate.s3,
    onShell: darkScheme.onSurface,
    onShellVariant: darkScheme.onSurfaceVariant,
    shellIndicator: darkScheme.primaryContainer,
    onShellIndicator: darkScheme.onPrimaryContainer,
    typeRed: glassDisplayColor(GlassHue.ruby, GlassIntensity.medium),
    typeWhite: glassDisplayColor(GlassHue.gold, GlassIntensity.medium),
    typeRose: glassDisplayColor(GlassHue.deepPink, GlassIntensity.medium),
    typeSparkling: lightScheme.secondary,
    typeDessert: glassDisplayColor(GlassHue.amber, GlassIntensity.medium),
    aromaFruit: const Color(0xFFB0393F),
    aromaFloral: const Color(0xFFA84C86),
    aromaHerbal: const Color(0xFF4F7F3E),
    aromaSpice: const Color(0xFFB0611C),
    aromaEarth: const Color(0xFF7A6650),
    aromaOak: const Color(0xFF8C5A2C),
    aromaYeast: const Color(0xFF8F7A2A),
    aromaOxidative: const Color(0xFF5E6A70),
    badgeEarned: lightScheme.primary,
    badgeLocked: Slate.s8,
    scoreNumeral: _scoreNumeral(lightScheme.primary),
    boardHeading: _boardHeading(lightScheme.onSurfaceVariant),
  );

  static TextStyle _scoreNumeral(Color color) => CorkFonts.extraCondensed(
    size: 28,
    lineHeight: 32,
    weight: FontWeight.w700,
    color: color,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle _boardHeading(Color color) => CorkFonts.extraCondensed(
    size: 16,
    lineHeight: 20,
    weight: FontWeight.w700,
    letterSpacing: 1.2,
    color: color,
  );

  static TextTheme _textTheme(Color ink) {
    TextStyle board(double size, double lh, FontWeight w, [double ls = 0]) =>
        CorkFonts.extraCondensed(
          size: size,
          lineHeight: lh,
          weight: w,
          letterSpacing: ls,
          color: ink,
        );
    TextStyle title(double size, double lh, [double ls = 0]) =>
        CorkFonts.condensed(
          size: size,
          lineHeight: lh,
          weight: FontWeight.w600,
          letterSpacing: ls,
          color: ink,
        );
    TextStyle text(double size, double lh, FontWeight w, [double ls = 0]) =>
        CorkFonts.sans(
          size: size,
          lineHeight: lh,
          weight: w,
          letterSpacing: ls,
          color: ink,
        );
    return TextTheme(
      displayLarge: board(57, 64, FontWeight.w600, -0.25),
      displayMedium: board(45, 52, FontWeight.w600),
      displaySmall: board(36, 44, FontWeight.w600),
      headlineLarge: board(32, 40, FontWeight.w700, 0.4),
      headlineMedium: board(28, 36, FontWeight.w700, 0.4),
      headlineSmall: board(24, 32, FontWeight.w700, 0.4),
      titleLarge: title(22, 28),
      titleMedium: title(16, 24, 0.15),
      titleSmall: title(14, 20, 0.1),
      bodyLarge: text(16, 24, FontWeight.w400, 0.15),
      bodyMedium: text(14, 20, FontWeight.w400, 0.25),
      bodySmall: text(12, 16, FontWeight.w400, 0.4),
      labelLarge: text(14, 20, FontWeight.w600, 0.1),
      labelMedium: text(12, 16, FontWeight.w600, 0.5),
      labelSmall: text(11, 16, FontWeight.w600, 0.5),
    );
  }

  static ThemeData _build(ColorScheme scheme, CorkTokens tokens) {
    final text = _textTheme(scheme.onSurface);
    final shellOverlay = SystemUiOverlayStyle.light.copyWith(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      extensions: [tokens],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.shell,
        foregroundColor: tokens.onShell,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: shellOverlay,
        titleTextStyle: text.headlineSmall?.copyWith(color: tokens.onShell),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.shell,
        surfaceTintColor: Colors.transparent,
        indicatorColor: tokens.shellIndicator,
        elevation: 0,
        height: 72,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? tokens.onShellIndicator
                : tokens.onShellVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(
            color: s.contains(WidgetState.selected)
                ? tokens.onShell
                : tokens.onShellVariant,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        highlightElevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CorkRadius.lg)),
        ),
        extendedTextStyle: text.labelLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: CorkRadius.card),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CorkSpace.gutter,
        ),
        minVerticalPadding: CorkSpace.md,
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CorkRadius.sm)),
        ),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.secondaryContainer,
        labelStyle: text.labelLarge,
        showCheckmark: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: CorkRadius.field,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: CorkRadius.field,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: CorkRadius.field,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: CorkRadius.field,
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: const WidgetStatePropertyAll(0),
        backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerHigh),
        textStyle: WidgetStatePropertyAll(text.bodyLarge),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(CorkRadius.md)),
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.surfaceContainerHighest,
        thumbColor: scheme.primary,
        valueIndicatorColor: scheme.primaryContainer,
        valueIndicatorTextStyle: tokens.scoreNumeral.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        showValueIndicator: ShowValueIndicator.onDrag,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: CorkRadius.sheet),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: CorkRadius.dialog),
        titleTextStyle: text.headlineSmall,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(CorkRadius.sm)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: scheme.onSurfaceVariant,
        collapsedIconColor: scheme.onSurfaceVariant,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
    );
  }
}
