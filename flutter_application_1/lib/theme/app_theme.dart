import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

/// Couleurs de l'application (maquettes AKORO mobile) + couleurs du logo FabLab Hay Tao.
class Brand {
  Brand._();

  // Logo FabLab (liseré tricolore)
  static const pink = Color(0xFFD6336C);
  static const green = Color(0xFF8CC63F);
  static const blue = Color(0xFF29ABE2);
  static const ink = Color(0xFF2E3036);

  // Maquettes : vert canard principal, orange d'accent
  static const teal = Color(0xFF0F8F7E); // contraste AA sur blanc
  static const tealLight = Color(0xFF3CC7B3);
  static const mint = Color(0xFFD5F5EE);
  static const orange = Color(0xFFEA6A0C);
  static const orangeLight = Color(0xFFFB923C);
  static const orangeSoft = Color(0xFFFFEAD8);

  // Ancien nom conservé
  static const primary = teal;
}

/// Couleurs de statut communes (présent, absent, alerte…), lisibles en clair et en sombre.
class StatusColors {
  final Color success, successBg, danger, dangerBg, warning, warningBg;
  const StatusColors(this.success, this.successBg, this.danger, this.dangerBg, this.warning, this.warningBg);

  static StatusColors of(BuildContext context) => Theme.of(context).brightness == Brightness.dark
      ? const StatusColors(Color(0xFF5EDCC4), Color(0xFF123A33), Color(0xFFFF8A80), Color(0xFF3D1F1F),
          Brand.orangeLight, Color(0xFF3A2614))
      : const StatusColors(Brand.teal, Brand.mint, Color(0xFFC62828), Color(0xFFFDE4E4), Brand.orange,
          Brand.orangeSoft);
}

/// Ombre douce des cartes (presque invisible en mode sombre, où la bordure suffit).
List<BoxShadow> ombreCarte(BuildContext context) => Theme.of(context).brightness == Brightness.dark
    ? const []
    : const [
        BoxShadow(color: Color(0x0D1F2328), blurRadius: 18, offset: Offset(0, 6)),
        BoxShadow(color: Color(0x081F2328), blurRadius: 3, offset: Offset(0, 1)),
      ];

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(
        ColorScheme.fromSeed(
          seedColor: Brand.teal,
          primary: Brand.teal,
          onPrimary: Colors.white,
          primaryContainer: Brand.mint,
          onPrimaryContainer: const Color(0xFF064E44),
          secondary: Brand.orange,
          secondaryContainer: Brand.orangeSoft,
          onSecondaryContainer: const Color(0xFF7A3306),
          tertiary: Brand.teal,
          surface: Colors.white,
          onSurface: const Color(0xFF1F2328),
          onSurfaceVariant: const Color(0xFF5F6670),
          outlineVariant: const Color(0xFFE6E4DE),
          error: const Color(0xFFC62828),
        ),
        const Color(0xFFF8F7F3),
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(
          seedColor: Brand.teal,
          brightness: Brightness.dark,
          primary: Brand.tealLight,
          onPrimary: const Color(0xFF00201B),
          primaryContainer: const Color(0xFF123A33),
          onPrimaryContainer: const Color(0xFFBDF2E7),
          secondary: Brand.orangeLight,
          secondaryContainer: const Color(0xFF3A2614),
          onSecondaryContainer: const Color(0xFFFFD9BF),
          tertiary: Brand.tealLight,
          surface: const Color(0xFF1C2120),
          onSurface: const Color(0xFFE9EDEC),
          onSurfaceVariant: const Color(0xFFA5AEAC),
          outlineVariant: const Color(0xFF2E3634),
          error: const Color(0xFFFF8A80),
        ),
        const Color(0xFF131716),
      );

  static ThemeData _build(ColorScheme scheme, Color background) {
    final radius = BorderRadius.circular(14);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'PlusJakartaSans');
    // Titres serrés et gras, texte courant aéré
    final texte = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.6),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.4),
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.2),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.45),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'PlusJakartaSans',
      textTheme: texte,
      scaffoldBackgroundColor: background,
      // Transitions douces entre écrans
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      // Zones tactiles d'au moins 48 dp
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: scheme.onSurface,
          fontSize: 19,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        surfaceTintColor: Colors.transparent,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
              color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? scheme.primary : scheme.onSurfaceVariant,
            )),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: radius),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      chipTheme: ChipThemeData(
        labelStyle: const TextStyle(fontFamily: 'PlusJakartaSans', fontWeight: FontWeight.w600),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 24),
      // Style 2024 des indicateurs de progression (option officielle tant qu'il n'est pas le défaut)
      // ignore: deprecated_member_use
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary, year2023: false),
    );
  }
}
