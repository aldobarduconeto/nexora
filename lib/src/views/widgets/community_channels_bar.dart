import 'package:flutter/material.dart';

class CommunityChannelsBar extends StatelessWidget {
  const CommunityChannelsBar({
    super.key,
    required this.channels,
    required this.activeChannel,
    required this.onSelectChannel,
    required this.onAddChannel,
    this.onShowInfo,
    this.activeChannelMuted = false,
    this.onToggleChannelMute,
    this.onRenameChannel,
  });

  final List<String> channels;
  final String activeChannel;
  final ValueChanged<String> onSelectChannel;
  final VoidCallback onAddChannel;
  final VoidCallback? onShowInfo;
  final bool activeChannelMuted;
  final VoidCallback? onToggleChannelMute;
  final VoidCallback? onRenameChannel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final list = channels.isEmpty ? ['geral'] : channels;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .35),
        border: Border(
          bottom: BorderSide(color: colors.outlineVariant.withValues(alpha: .5)),
        ),
      ),
      child: Row(
        children: [
          if (onShowInfo != null) ...[
            IconButton(
              icon: const Icon(Icons.info_outline_rounded, size: 18),
              tooltip: 'Regras e detalhes da comunidade',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onShowInfo,
            ),
            const VerticalDivider(width: 1, indent: 8, endIndent: 8),
          ],
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final ch = list[index];
                final isSelected = ch.toLowerCase() == activeChannel.toLowerCase();

                return ChoiceChip(
                  label: Text(
                    '#$ch',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (_) => onSelectChannel(ch),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              },
            ),
          ),
          if (onToggleChannelMute != null)
            IconButton(
              icon: Icon(
                activeChannelMuted
                    ? Icons.notifications_off_outlined
                    : Icons.notifications_outlined,
                size: 18,
              ),
              tooltip: activeChannelMuted
                  ? 'Reativar notificações de #$activeChannel'
                  : 'Silenciar notificações de #$activeChannel',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onToggleChannelMute,
            ),
          if (onRenameChannel != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              tooltip: 'Renomear #$activeChannel',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: onRenameChannel,
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 19),
            tooltip: 'Criar novo canal de tópico',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: onAddChannel,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}
