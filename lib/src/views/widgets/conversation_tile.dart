import 'package:flutter/material.dart';
import 'package:nexora/src/models/user.dart';
import 'package:nexora/src/models/conversation.dart';

class ConversationTile extends StatelessWidget {
  const ConversationTile({
    super.key,
    required this.conversation,
    required this.displayName,
    required this.currentUser,
    required this.onOpen,
    this.isBlocked = false,
    this.onManage,
  });
  final Conversation conversation;
  final String displayName;
  final User currentUser;
  final VoidCallback onOpen;
  final bool isBlocked;
  final ValueChanged<String>? onManage;
  @override
  Widget build(BuildContext context) {
    final title = displayName;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          backgroundColor: colors.primaryContainer,
          foregroundColor: colors.onPrimaryContainer,
          child: Text(
            title.isEmpty ? '?' : title.substring(0, 1).toUpperCase(),
          ),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            isBlocked
                ? 'Bloqueado'
                : conversation.isGroup
                ? '${conversation.participantIds.length} participantes'
                : 'Conversa privada',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        ),
        trailing: onManage == null
            ? Icon(
                isBlocked ? Icons.block : Icons.chevron_right,
                color: colors.onSurfaceVariant,
              )
            : PopupMenuButton<String>(
                tooltip: 'Gerenciar conversa',
                icon: Icon(isBlocked ? Icons.block : Icons.more_horiz),
                onSelected: onManage,
                itemBuilder: (_) => [
                  if (conversation.isGroup)
                    const PopupMenuItem(
                      value: 'share',
                      child: Text('Copiar convite do grupo'),
                    ),
                  if (conversation.isGroup)
                    PopupMenuItem(
                      value: 'rename',
                      child: Text('Renomear grupo'),
                    ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Excluir conversa local'),
                  ),
                ],
              ),
        onTap: onOpen,
      ),
    );
  }
}
