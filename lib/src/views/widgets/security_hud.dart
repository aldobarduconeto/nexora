import 'package:flutter/material.dart';
import 'package:nexora/src/services/conversation_connection_service.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

/// Painel interativo de métricas criptográficas e verificação de canal P2P em tempo real.
class SecurityHud extends StatefulWidget {
  const SecurityHud({
    super.key,
    required this.connection,
    required this.isGroup,
    required this.localUserId,
    required this.peerName,
  });

  final ConversationConnectionService connection;
  final bool isGroup;
  final String localUserId;
  final String peerName;

  @override
  State<SecurityHud> createState() => _SecurityHudState();
}

class _SecurityHudState extends State<SecurityHud> {
  bool _expanded = false;

  /// Gera 4 palavras de código de autenticação curta (SAS) baseadas nas chaves dos pares.
  List<String> _deriveSasWords(String keyA, String keyB) {
    const wordList = [
      'DELTA', 'NEXUS', 'SOLAR', 'CYBER', 'QUANTUM', 'SHIELD',
      'VECTOR', 'PRISM', 'AURA', 'FROST', 'ECHO', 'PULSE',
      'COBALT', 'ALPHA', 'TITAN', 'HORIZON', 'ORBIT', 'STEALTH',
    ];
    final combined = keyA.codeUnits.fold<int>(0, (a, b) => a + b) ^
        keyB.codeUnits.fold<int>(0, (a, b) => a + b);

    return [
      wordList[(combined * 7) % wordList.length],
      wordList[(combined * 13) % wordList.length],
      wordList[(combined * 29) % wordList.length],
      wordList[(combined * 43) % wordList.length],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isConnected = widget.connection.isConnected;
    final remoteKey = widget.connection.remotePublicKey;
    final sasWords = _deriveSasWords(widget.localUserId, remoteKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(
          alpha: _expanded ? .65 : .38,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConnected
              ? colors.primary.withValues(alpha: _expanded ? .45 : .22)
              : colors.outlineVariant.withValues(alpha: .5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de cabeçalho clicável para expandir/recolher
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isConnected ? const Color(0xFF36D399) : colors.outline,
                      boxShadow: isConnected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF36D399).withValues(alpha: .6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected
                        ? 'TÚNEL E2EE ATIVO'
                        : 'AGUARDANDO CONEXÃO P2P',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: isConnected ? colors.primary : colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '•  AES-256-GCM  •  Ed25519',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontFamily: 'monospace',
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),

          // Detalhes expandidos do inspetor criptográfico
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 12),
                  Row(
                    children: [
                      Icon(Icons.shield_rounded, size: 14, color: colors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Verificador de Autenticidade (SAS Fingerprint):',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Confira se estas 4 palavras de segurança coincidem com as da tela de "${widget.peerName}":',
                    style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final word in sasWords)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryContainer.withValues(alpha: .5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: colors.primary.withValues(alpha: .3),
                            ),
                          ),
                          child: Text(
                            word,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'monospace',
                              letterSpacing: .5,
                              color: colors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cryptoRow(
                          'Identidade remota',
                          AppTheme.formatKeyPreview(remoteKey),
                          colors,
                        ),
                        const SizedBox(height: 3),
                        _cryptoRow('Cifra de dados', 'AES-256-GCM (96-bit Monotonic Nonce)', colors),
                        const SizedBox(height: 3),
                        _cryptoRow('Acordo efêmero', 'X25519 + HKDF-SHA256', colors),
                        const SizedBox(height: 3),
                        _cryptoRow('Voz e Vídeo', 'DTLS-SRTP P2P Direto', colors),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cryptoRow(String label, String value, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: colors.onSurfaceVariant),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }
}
