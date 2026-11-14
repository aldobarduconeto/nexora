import 'dart:math';
import 'package:flutter/material.dart';

/// Widget de plano de fundo procedural para a tela de chat.
/// Suporta os estilos: 'none', 'mesh' (malha P2P), 'grid' (cyber grid), 'dots' (pontilhado moderno).
class ChatWallpaperBackground extends StatelessWidget {
  const ChatWallpaperBackground({
    super.key,
    required this.wallpaperStyle,
    required this.child,
  });

  final String wallpaperStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (wallpaperStyle == 'none') return child;

    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(
            painter: _WallpaperPainter(
              style: wallpaperStyle,
              accentColor: colors.primary,
              isDark: isDark,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _WallpaperPainter extends CustomPainter {
  final String style;
  final Color accentColor;
  final bool isDark;

  _WallpaperPainter({
    required this.style,
    required this.accentColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (style) {
      case 'grid':
        _paintGrid(canvas, size);
        break;
      case 'dots':
        _paintDots(canvas, size);
        break;
      case 'mesh':
      default:
        _paintMesh(canvas, size);
        break;
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.045 : 0.035)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const spacing = 36.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintDots(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.08 : 0.06)
      ..style = PaintingStyle.fill;

    const spacing = 28.0;
    for (double x = spacing / 2; x < size.width; x += spacing) {
      for (double y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.3, paint);
      }
    }
  }

  void _paintMesh(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.038 : 0.028)
      ..strokeWidth = 1.0;

    final nodePaint = Paint()
      ..color = accentColor.withValues(alpha: isDark ? 0.08 : 0.06)
      ..style = PaintingStyle.fill;

    // Nós pseudo-determinísticos simulando malha P2P
    const cellWidth = 90.0;
    const cellHeight = 90.0;
    final cols = (size.width / cellWidth).ceil() + 1;
    final rows = (size.height / cellHeight).ceil() + 1;

    final points = <List<Offset>>[];

    for (int r = 0; r < rows; r++) {
      final rowPoints = <Offset>[];
      for (int c = 0; c < cols; c++) {
        final seed = (r * 31 + c * 17) % 100;
        final offsetX = (sin(seed) * 16);
        final offsetY = (cos(seed) * 16);
        rowPoints.add(
          Offset(c * cellWidth + offsetX, r * cellHeight + offsetY),
        );
      }
      points.add(rowPoints);
    }

    // Linhas interconectadas
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final p = points[r][c];
        canvas.drawCircle(p, 2.0, nodePaint);

        if (c + 1 < cols) {
          canvas.drawLine(p, points[r][c + 1], linePaint);
        }
        if (r + 1 < rows) {
          canvas.drawLine(p, points[r + 1][c], linePaint);
        }
        if (r + 1 < rows && c + 1 < cols && (r + c) % 2 == 0) {
          canvas.drawLine(p, points[r + 1][c + 1], linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WallpaperPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isDark != isDark;
}
