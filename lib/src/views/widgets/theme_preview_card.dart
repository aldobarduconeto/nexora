import 'package:flutter/material.dart';
import 'package:nexora/src/models/seting.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/chat_wallpaper.dart';
import 'package:nexora/src/views/widgets/crypto_avatar.dart';
import 'package:nexora/src/views/widgets/stealth_blur.dart';

/// Card interativo de prévia ao vivo das personalizações de layout e tema.
class ThemePreviewCard extends StatelessWidget {
  const ThemePreviewCard({super.key, required this.setting});

  final Setting setting;

  @override
  Widget build(BuildContext context) {
    final accent = AppTheme.resolveAccentColor(setting.accentColor);
    final dark = setting.isDarkMode;
    final amoled = setting.isAmoledMode && dark;

    final bg = amoled
        ? Colors.black
        : (dark ? const Color(0xFF0F1523) : const Color(0xFFF3F6FD));
    final bubbleLocalBg = accent.withValues(alpha: dark ? 0.22 : 0.18);
    final bubbleRemoteBg = dark
        ? const Color(0xFF1B2336)
        : Colors.white;

    final bubbleBorderRadius = switch (setting.chatBubbleStyle) {
      'minimal' => BorderRadius.circular(8),
      'bubble' => const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(3),
        ),
      _ => const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
    };

    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(setting.cardRadius),
        border: Border.all(
          color: accent.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ChatWallpaperBackground(
        wallpaperStyle: setting.chatWallpaper,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Barra simulada de status com HUD e Avatar
              Row(
                children: [
                  const CryptoAvatar(
                    seedKey: 'peer_preview_seed',
                    title: 'Alice',
                    size: 32,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Alice (P2P)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF36D399),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          setting.showSecurityInspector
                              ? 'Túnel AES-256-GCM ativo'
                              : 'Conectado diretamente',
                          style: TextStyle(
                            fontSize: 10,
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'PRÉVIA',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .5,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),

              // Mensagem remota simulada
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleRemoteBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.15),
                    ),
                  ),
                  child: StealthBlur(
                    enabled: setting.stealthMode,
                    child: Text(
                      'Olá! Como está a conexão P2P?',
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),

              // Mensagem local simulada
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: bubbleLocalBg,
                    borderRadius: bubbleBorderRadius,
                    border: Border.all(color: accent.withValues(alpha: 0.35)),
                  ),
                  child: StealthBlur(
                    enabled: setting.stealthMode,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Criptografia perfeita e layout personalizado!',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: dark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(Icons.done_all_rounded, size: 14, color: accent),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
