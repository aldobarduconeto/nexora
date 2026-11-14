import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/utils/qr_code.dart';

class SafetyNumbersDialog extends StatefulWidget {
  const SafetyNumbersDialog({
    super.key,
    required this.contactName,
    required this.myPublicKey,
    required this.peerPublicKey,
    required this.isVerified,
    required this.onToggleVerified,
  });

  final String contactName;
  final String myPublicKey;
  final String peerPublicKey;
  final bool isVerified;
  final ValueChanged<bool> onToggleVerified;

  @override
  State<SafetyNumbersDialog> createState() => _SafetyNumbersDialogState();
}

class _SafetyNumbersDialogState extends State<SafetyNumbersDialog> {
  late bool _verified;

  @override
  void initState() {
    super.initState();
    _verified = widget.isVerified;
  }

  String _computeSafetyNumbers() {
    final keys = [widget.myPublicKey, widget.peerPublicKey]..sort();
    final combined = utf8.encode('${keys[0]}:${keys[1]}');
    final digest = sha256.convert(combined);
    final bytes = digest.bytes;

    final buffer = StringBuffer();
    for (int i = 0; i < 30; i += 2) {
      final val = (bytes[i % bytes.length] << 8) | bytes[(i + 1) % bytes.length];
      final num = (val % 100000).toString().padLeft(5, '0');
      buffer.write(num);
    }
    final raw = buffer.toString().padRight(60, '0').substring(0, 60);

    // Format into 12 blocks of 5 digits
    final blocks = <String>[];
    for (int i = 0; i < 60; i += 5) {
      blocks.add(raw.substring(i, i + 5));
    }
    return blocks.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final safetyNumbers = _computeSafetyNumbers();
    final qrPayload = 'nexora-verify:${widget.peerPublicKey.substring(0, 16)}:$safetyNumbers';

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _verified ? Icons.verified_user_rounded : Icons.shield_outlined,
            color: _verified ? Colors.green : colors.primary,
          ),
          const SizedBox(width: 10),
          const Text('Verificação de Segurança'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Compare os 60 dígitos ou escaneie o código com ${widget.contactName} pessoalmente para garantir autenticidade ponta a ponta sem interceptação (MITM).',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              // QR Code Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: 160,
                  height: 160,
                  child: CustomPaint(
                    painter: QrCodePainter(
                      data: qrPayload,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Safety Number Grid
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: SelectableText(
                  safetyNumbers,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: safetyNumbers));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Código de segurança copiado!')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copiar números de segurança'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Marcar como verificado',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: const Text(
                  'Ativa o escudo de segurança verificado no chat',
                  style: TextStyle(fontSize: 12),
                ),
                value: _verified,
                onChanged: (val) {
                  setState(() => _verified = val);
                  widget.onToggleVerified(val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Concluído'),
        ),
      ],
    );
  }
}
