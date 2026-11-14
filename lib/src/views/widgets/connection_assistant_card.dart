import 'package:flutter/material.dart';
import 'package:nexora/src/services/conversation_connection_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class ConnectionAssistantCard extends StatelessWidget {
  const ConnectionAssistantCard({
    super.key,
    required this.connection,
    required this.userService,
    required this.signalingController,
    required this.isGroup,
    required this.busy,
    required this.isBlocked,
    required this.obscureSignaling,
    required this.onToggleObscure,
    required this.onHidePanel,
    required this.onPeerChanged,
    required this.onSignalingTextChanged,
    required this.onPasteSignaling,
    required this.onCreateOffer,
    required this.onAcceptOffer,
    required this.onAcceptAnswer,
    required this.onCopySignaling,
  });

  final ConversationConnectionService connection;
  final LocalDataService userService;
  final TextEditingController signalingController;
  final bool isGroup;
  final bool busy;
  final bool isBlocked;
  final bool obscureSignaling;
  final VoidCallback onToggleObscure;
  final VoidCallback onHidePanel;
  final ValueChanged<String> onPeerChanged;
  final ValueChanged<String> onSignalingTextChanged;
  final VoidCallback onPasteSignaling;
  final VoidCallback onCreateOffer;
  final VoidCallback onAcceptOffer;
  final VoidCallback onAcceptAnswer;
  final VoidCallback onCopySignaling;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasSignalingText = signalingController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: .14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.hub_outlined,
                      color: colors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assistente de Conexão Direta P2P',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                        Text(
                          'Após conectar, voz, vídeo e transmissão de tela funcionam automaticamente.',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Ocultar painel',
                      onPressed: onHidePanel,
                      icon: const Icon(Icons.expand_less_rounded),
                    ),
                ],
              ),
              if (isGroup) ...[
                const SizedBox(height: 12),
                Text(
                  'Conecte cada participante separadamente para formar a malha completa do grupo.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: connection.remotePublicKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Participante selecionado',
                  ),
                  items: connection.peerKeys
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(
                            '${userService.contactName(key)}${userService.hasContactName(key) ? "" : " (participante ${connection.peerKeys.indexOf(key) + 1})"}${connection.peerConnected(key) ? " • Conectado" : ""}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (key) {
                          if (key != null) onPeerChanged(key);
                        },
                ),
              ],
              const SizedBox(height: 10),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(
                      Icons.fingerprint_rounded,
                      size: 16,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Chave pública: ${AppTheme.formatKeyPreview(connection.remotePublicKey)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                children: [
                  SelectableText(
                    connection.remotePublicKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Compare a chave com seu contato por outro canal confiável.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
              const SizedBox(height: 6),
              TextField(
                controller: signalingController,
                enabled: !busy,
                obscureText: obscureSignaling,
                maxLines: 1,
                enableIMEPersonalizedLearning: false,
                maxLength: 131072,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: onSignalingTextChanged,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Cole aqui o convite ou a resposta recebida',
                  counterText: 'Convite assinado • válido por 10 minutos',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: obscureSignaling
                            ? 'Mostrar código'
                            : 'Ocultar código',
                        icon: Icon(
                          obscureSignaling
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 18,
                        ),
                        onPressed: onToggleObscure,
                      ),
                      IconButton(
                        tooltip: 'Colar da área de transferência',
                        icon: const Icon(Icons.content_paste_rounded, size: 18),
                        onPressed: busy ? null : onPasteSignaling,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: busy || isBlocked ? null : onCreateOffer,
                    icon: const Icon(Icons.outgoing_mail, size: 18),
                    label: const Text('1. Criar convite'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || isBlocked || !hasSignalingText
                        ? null
                        : onAcceptOffer,
                    icon: const Icon(Icons.reply_rounded, size: 18),
                    label: const Text('2. Gerar resposta'),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        busy ||
                            isBlocked ||
                            !connection.canApplyAnswer ||
                            !hasSignalingText
                        ? null
                        : onAcceptAnswer,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('3. Aplicar resposta'),
                  ),
                  TextButton.icon(
                    onPressed: busy || signalingController.text.isEmpty
                        ? null
                        : onCopySignaling,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'No modo direto, seu contato pode descobrir seu IP. STUN não anonimiza. Para ocultar o IP do contato, use uma compilação configurada para TURN exclusivo.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
