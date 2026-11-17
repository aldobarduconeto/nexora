import 'dart:ui';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
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
    bool reduceMotion = false,
  }) {
    final dark = brightness == Brightness.dark;
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );

    // Paleta clean & moderna inspirada em Linear & Telegram Desktop (Modern Minimal / Frosted)
    final background = (dark && isAmoled)
        ? Colors.black
        : Color.lerp(
            dark ? const Color(0xFF0A0F1D) : const Color(0xFFF8FAFD),
            accent,
            dark ? .035 : .012,
          )!;

    final surface = (dark && isAmoled)
        ? const Color(0xFF0D1424)
        : Color.lerp(
            dark ? const Color(0xFF111827) : Colors.white,
            accent,
            dark ? .045 : .008,
          )!;

    final surfaceContainer = (dark && isAmoled)
        ? const Color(0xFF131D33)
        : Color.lerp(
            dark ? const Color(0xFF172036) : const Color(0xFFF1F5F9),
            accent,
            dark ? .06 : .015,
          )!;

    final outlineVariant = dark
        ? Color.lerp(const Color(0xFF222F49), accent, .08)!
        : Color.lerp(const Color(0xFFE2E8F0), accent, .06)!;

    final scheme = base.copyWith(
      primary: dark ? accent : Color.lerp(accent, Colors.black, .32),
      surface: surface,
      surfaceContainerHighest: surfaceContainer,
      outlineVariant: outlineVariant,
    );

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6), width: 1.1),
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
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45), width: 1),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius + 4),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6), width: 1.2),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 42),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.7), width: 1.1),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.1,
            fontSize: 13.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.45),
        space: 1,
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(5),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return scheme.primary.withValues(alpha: 0.5);
          }
          return scheme.onSurfaceVariant.withValues(alpha: 0.2);
        }),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(14),
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
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 500),
        showDuration: const Duration(milliseconds: 2500),
        triggerMode: TooltipTriggerMode.longPress,
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF1F293D) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: outlineVariant.withValues(alpha: 0.35),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.24),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.14),
        trackHeight: 3.5,
      ),
      pageTransitionsTheme: (animations && !reduceMotion)
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
                TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                TargetPlatform.windows: ZoomPageTransitionsBuilder(),
                TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
                TargetPlatform.linux: ZoomPageTransitionsBuilder(),
              },
            )
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

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.description,
    this.badge,
  });

  final String title;
  final String description;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (badge != null) ...[
          badge!,
          const SizedBox(height: 8),
        ],
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          description,
          style: TextStyle(
            fontSize: 13.5,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class FrostedCard extends StatelessWidget {
  const FrostedCard({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding = const EdgeInsets.all(20),
    this.borderWidth = 1.0,
    this.borderColor,
    this.border,
    this.backgroundColor,
    this.onTap,
  });

  final Widget child;
  final dynamic borderRadius;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final Color? borderColor;
  final BoxBorder? border;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  BorderRadius _resolveRadius() {
    if (borderRadius is BorderRadius) {
      return borderRadius as BorderRadius;
    }
    if (borderRadius is num) {
      return BorderRadius.circular((borderRadius as num).toDouble());
    }
    return BorderRadius.circular(18.0);
  }

  BoxBorder _resolveBorder(ColorScheme colors) {
    if (border != null) return border!;
    final color = borderColor ?? colors.outlineVariant.withValues(alpha: 0.45);
    return Border.all(color: color, width: borderWidth);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = _resolveRadius();
    final effectiveBorder = _resolveBorder(colors);

    final bg = backgroundColor ??
        (isDark
            ? colors.surface.withValues(alpha: 0.65)
            : colors.surface.withValues(alpha: 0.85));

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: effectiveBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      content = Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: content,
        ),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: content,
      ),
    );
  }
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * .24),
      child: Image.asset(
        'assets/icon.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
      ),
    );
  }
}
