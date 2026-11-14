import 'package:flutter/material.dart';

/// Exibe o trecho citado de uma mensagem respondida.
class ReplySnippetWidget extends StatelessWidget {
  const ReplySnippetWidget({
    super.key,
    required this.senderName,
    required this.snippet,
    this.onTap,
    this.onCancel,
    this.isEmbedded = false,
  });

  final String senderName;
  final String snippet;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final bool isEmbedded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: isEmbedded ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: colors.primary,
            width: 3.5,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: isEmbedded ? MainAxisSize.min : MainAxisSize.max,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  senderName,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (onCancel != null)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              onPressed: onCancel,
              tooltip: 'Cancelar resposta',
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }

    return content;
  }
}
