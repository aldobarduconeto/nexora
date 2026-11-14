import 'package:flutter/material.dart';

/// Avatar procedural derivado deterministicamente da chave pública ou identificador.
class CryptoAvatar extends StatelessWidget {
  const CryptoAvatar({
    super.key,
    required this.seedKey,
    required this.title,
    this.isGroup = false,
    this.isCommunity = false,
    this.isSavedMessages = false,
    this.size = 46,
    this.isBlocked = false,
  });

  final String seedKey;
  final String title;
  final bool isGroup;
  final bool isCommunity;
  final bool isSavedMessages;
  final double size;
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (isBlocked) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: .5),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: colors.error.withValues(alpha: .4)),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.block_rounded, size: size * .46, color: colors.error),
      );
    }

    if (isSavedMessages) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: colors.primary.withValues(alpha: .3)),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.bookmark_rounded,
          size: size * .5,
          color: colors.onPrimaryContainer,
        ),
      );
    }

    if (isCommunity) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primary,
              colors.primary.withValues(alpha: .7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: colors.primary.withValues(alpha: .4)),
          boxShadow: [
            BoxShadow(
              color: colors.primary.withValues(alpha: .25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.hub_rounded,
          size: size * .5,
          color: colors.onPrimary,
        ),
      );
    }

    if (isGroup) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.primaryContainer,
              colors.primaryContainer.withValues(alpha: .6),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size * .3),
          border: Border.all(color: colors.primary.withValues(alpha: .3)),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.groups_rounded,
          size: size * .5,
          color: colors.onPrimaryContainer,
        ),
      );
    }

    // Derivação de cor primária e secundária a partir dos bytes da chave
    final hash = seedKey.codeUnits.fold<int>(0, (prev, elem) => prev + elem);
    final hueA = (hash * 37) % 360;
    final hueB = (hueA + 40) % 360;

    final colorA = HSLColor.fromAHSL(0.85, hueA.toDouble(), 0.65, 0.42).toColor();
    final colorB = HSLColor.fromAHSL(0.85, hueB.toDouble(), 0.70, 0.32).toColor();

    final initial = title.trim().isNotEmpty
        ? title.trim().substring(0, 1).toUpperCase()
        : (seedKey.isNotEmpty ? seedKey.substring(0, 1).toUpperCase() : '?');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorA, colorB],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorA.withValues(alpha: 0.28),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * .44,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
