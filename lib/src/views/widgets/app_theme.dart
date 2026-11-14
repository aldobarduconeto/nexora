import 'package:flutter/material.dart';

abstract final class AppTheme {
  static Color resolveAccentColor(String name) => switch (name) {
    'blue' => const Color(0xFF3B82F6),
    'purple' => const Color(0xFF8B5CF6),
    'amber' => const Color(0xFFF59E0B),
    'crimson' => const Color(0xFFF43F5E),
    'monochrome' => const Color(0xFFCBD5E1),
    _ => const Color(0xFF00DC82), // Mint moderno vibrante
  };

  static ThemeData build(
    Brightness brightness,
    Color accent,
    bool animations, {
    bool isAmoled = false,
    double cardRadius = 18.0,
  }) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );

    // Paleta clean & moderna com tons refinados e contraste perfeito
    final background = (dark && isAmoled)
        ? Colors.black
        : Color.lerp(
            dark ? const Color(0xFF090D18) : const Color(0xFFF8FAFC),
            accent,
            dark ? .05 : .015,
          )!;

    final surface = (dark && isAmoled)
        ? const Color(0xFF0D121F)
        : Color.lerp(
            dark ? const Color(0xFF111728) : Colors.white,
            accent,
            dark ? .06 : .01,
          )!;

    final surfaceContainer = (dark && isAmoled)
        ? const Color(0xFF141C2E)
        : Color.lerp(
            dark ? const Color(0xFF182035) : const Color(0xFFF1F5F9),
            accent,
            dark ? .08 : .02,
          )!;

    final outlineVariant = dark
        ? Color.lerp(const Color(0xFF243048), accent, .12)!
        : Color.lerp(const Color(0xFFE2E8F0), accent, .08)!;

    final scheme = base.copyWith(
      primary: dark ? accent : Color.lerp(accent, Colors.black, .32),
      surface: surface,
      surfaceContainerHighest: surfaceContainer,
      outlineVariant: outlineVariant,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(cardRadius * 0.75),
      borderSide: BorderSide(color: scheme.outlineVariant, width: 1.2),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius + 6),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.8), width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius * 0.7),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius * 0.7),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          side: BorderSide(color: scheme.outlineVariant, width: 1.2),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cardRadius * 0.7),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? scheme.primary : scheme.onSurfaceVariant,
            letterSpacing: -0.1,
          );
        }),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        selectedLabelTextStyle: TextStyle(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
          fontSize: 12.5,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: 12.5,
        ),
      ),
      pageTransitionsTheme: animations
          ? const PageTransitionsTheme()
          : PageTransitionsTheme(
              builders: {
                for (final platform in TargetPlatform.values)
                  platform: const _NoTransition(),
              },
            ),
    );
  }

  /// Formata uma chave Base64 Ed25519 em impressão digital compacta e legível.
  static String formatKeyPreview(String key) {
    final trimmed = key.trim();
    if (trimmed.length <= 16) return trimmed;
    final clean = trimmed.replaceAll('=', '');
    if (clean.length < 12) return trimmed;
    return '${clean.substring(0, 6)}••••${clean.substring(clean.length - 6)}';
  }
}

class _NoTransition extends PageTransitionsBuilder {
  const _NoTransition();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.child, this.maxWidth = 920});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primary.withValues(alpha: 0.22),
            colors.primary.withValues(alpha: 0.05),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * .26),
        child: Image.asset(
          'assets/icon.png',
          width: size,
          height: size,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
