import 'package:flutter/material.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/models/user.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/crypto_avatar.dart';
import 'package:nexora/src/views/widgets/stealth_blur.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.displayName,
    required this.currentUser,
    required this.onOpen,
    this.isBlocked = false,
    this.stealthMode = false,
    this.isCompact = false,
    this.onManage,
  });

  final Conversation conversation;
  final String displayName;
  final User currentUser;
  final VoidCallback onOpen;
  final bool isBlocked;
  final bool stealthMode;
  final bool isCompact;
  final ValueChanged<String>? onManage;

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final local = dateTime.toLocal();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Agora';
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    if (diff.inDays == 1) return 'Ontem';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  String _subtitlePreview() {
    if (isBlocked) return 'Contato bloqueado neste dispositivo';
    if (conversation.isSavedMessages) {
      if (conversation.messages.isNotEmpty) {
        return conversation.messages.last.textMsg;
      }
      return 'Cofre seguro para suas notas e mensagens';
    }
    if (conversation.isCommunity) {
      if (conversation.messages.isNotEmpty) {
        final last = conversation.messages.last;
        final isMe = last.senderId == currentUser.id;
        final prefix = isMe ? 'Você: ' : '';
        final ch = last.channel != null ? '#${last.channel}: ' : '';
        return '$prefix$ch${last.textMsg}';
      }
      return 'Comunidade P2P • ${conversation.channels.length} canais tópicos';
    }
    if (conversation.messages.isNotEmpty) {
      final last = conversation.messages.last;
      final isMe = last.senderId == currentUser.id;
      final prefix = isMe ? 'Você: ' : '';
      return '$prefix${last.textMsg}';
    }
    if (conversation.isGroup) {
      return 'Grupo P2P • ${conversation.participantIds.length} participantes';
    }
    final peerKey = conversation.participantIds.firstWhere(
      (id) => id != currentUser.id,
      orElse: () => '',
    );
    return 'Chave ${AppTheme.formatKeyPreview(peerKey)} • E2EE Ativo';
  }

  @override
  Widget build(BuildContext context) {
    final title = displayName;
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastTime = conversation.messages.isNotEmpty
        ? conversation.messages.last.sentAt
        : conversation.updatedAt;

    final seedKey = conversation.participantIds.firstWhere(
      (id) => id != currentUser.id,
      orElse: () => conversation.id,
    );

    final cardBg = isDark
        ? (conversation.isPinned
            ? colors.surfaceContainerHighest.withValues(alpha: 0.45)
            : colors.surface.withValues(alpha: 0.75))
        : (conversation.isPinned
            ? colors.primary.withValues(alpha: 0.05)
            : colors.surface);

    final borderColor = conversation.isPinned
        ? colors.primary.withValues(alpha: 0.35)
        : colors.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: isCompact ? 9 : 12,
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    CryptoAvatar(
                      seedKey: seedKey,
                      title: title,
                      isGroup: conversation.isGroup,
                      isCommunity: conversation.isCommunity,
                      isSavedMessages: conversation.isSavedMessages,
                      size: isCompact ? 42 : 46,
                      isBlocked: isBlocked,
                    ),
                    if (conversation.isPinned)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: colors.surface, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.push_pin_rounded,
                            size: 9,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (conversation.isMuted) ...[
                            Icon(
                              Icons.volume_off_rounded,
                              size: 13,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (!conversation.isGroup &&
                              conversation.isSafetyVerified) ...[
                            const Icon(
                              Icons.verified_user_rounded,
                              size: 13,
                              color: Color(0xFF00DC82),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (conversation.isCommunity) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: .14),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'COMUNIDADE',
                                style: TextStyle(
                                  fontSize: 9.0,
                                  fontWeight: FontWeight.w800,
                                  color: colors.primary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: isCompact ? 13.5 : 14.5,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatRelativeTime(lastTime),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colors.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            isBlocked
                                ? Icons.block_rounded
                                : (conversation.isSavedMessages
                                    ? Icons.bookmark_rounded
                                    : Icons.lock_outline_rounded),
                            size: 12,
                            color: isBlocked
                                ? colors.error
                                : colors.primary.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: StealthBlur(
                              enabled: stealthMode && conversation.messages.isNotEmpty,
                              child: Text(
                                _subtitlePreview(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: colors.onSurfaceVariant.withValues(alpha: 0.85),
                                  fontSize: isCompact ? 11.5 : 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          if (conversation.messages.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: colors.primary.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '${conversation.messages.length}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                if (onManage == null)
                  Icon(
                    isBlocked ? Icons.block : Icons.chevron_right_rounded,
                    color: colors.onSurfaceVariant.withValues(alpha: 0.5),
                    size: 18,
                  )
              else
                PopupMenuButton<String>(
                  tooltip: 'Gerenciar conversa',
                  icon: Icon(
                    isBlocked ? Icons.block : Icons.more_vert_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  onSelected: onManage,
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(
                            conversation.isPinned
                                ? Icons.push_pin_rounded
                                : Icons.push_pin_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(conversation.isPinned ? 'Desafixar conversa' : 'Fixar conversa'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'mute',
                      child: Row(
                        children: [
                          Icon(
                            conversation.isMuted
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(conversation.isMuted ? 'Reativar notificações' : 'Silenciar conversa'),
                        ],
                      ),
                    ),
                    if (conversation.isGroup)
                      const PopupMenuItem(
                        value: 'share',
                        child: Text('Copiar convite do grupo'),
                      ),
                    if (conversation.isGroup)
                      const PopupMenuItem(
                        value: 'rename',
                        child: Text('Renomear grupo'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Excluir conversa local'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
