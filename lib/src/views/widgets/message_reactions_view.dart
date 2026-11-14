import 'package:flutter/material.dart';

/// Exibe as reações de uma mensagem e fornece a barra de seleção de emoji.
class MessageReactionsView extends StatelessWidget {
  const MessageReactionsView({
    super.key,
    required this.reactions,
    required this.currentUserId,
    required this.onReactionTap,
  });

  final Map<String, List<String>> reactions;
  final String currentUserId;
  final ValueChanged<String> onReactionTap;

  static const List<String> quickEmojis = ['👍', '❤️', '😂', '🔥', '😮', '👏', '🔐'];

  static Future<String?> showPicker(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final emoji in quickEmojis)
                InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => Navigator.pop(ctx, emoji),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in reactions.entries)
            if (entry.value.isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onReactionTap(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: entry.value.contains(currentUserId)
                        ? colors.primaryContainer.withValues(alpha: 0.8)
                        : colors.surfaceContainerHighest.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: entry.value.contains(currentUserId)
                          ? colors.primary.withValues(alpha: 0.6)
                          : colors.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(entry.key, style: const TextStyle(fontSize: 12)),
                      if (entry.value.length > 1) ...[
                        const SizedBox(width: 3),
                        Text(
                          '${entry.value.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: entry.value.contains(currentUserId)
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
