import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/services/device_mirror_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/utils/qr_code.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/mirror_qr_actions.dart';

class DeviceMirrorHostView extends StatefulWidget {
  const DeviceMirrorHostView({super.key});

  @override
  State<DeviceMirrorHostView> createState() => _DeviceMirrorHostViewState();
}

class _DeviceMirrorHostViewState extends State<DeviceMirrorHostView> {
  final _service = DeviceMirrorService.instance;
  final _user = LocalDataService.instance;
  final _codeController = TextEditingController();

  bool _processing = false;
  String? _authorizedResultCode;
  String? _authorizedDeviceName;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  IconData _platformIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return Icons.desktop_windows_rounded;
      case 'macos':
        return Icons.laptop_mac_rounded;
      case 'linux':
        return Icons.computer_rounded;
      case 'android':
        return Icons.phone_android_rounded;
      case 'ios':
        return Icons.phone_iphone_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  String _platformLabel(String platform) {
    switch (platform.toLowerCase()) {
      case 'windows':
        return 'Windows';
      case 'macos':
        return 'macOS';
      case 'linux':
        return 'Linux';
      case 'android':
        return 'Android';
      case 'ios':
        return 'iOS';
      default:
        return 'Dispositivo desconhecido';
    }
  }

  Future<void> _processRequest(String rawData) async {
    if (!mounted || _processing || _authorizedResultCode != null) return;
    final trimmed = rawData.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código de vinculação.')),
      );
      return;
    }

    NexoraMirrorRequest request;
    try {
      request = _service.parseMirrorRequest(trimmed);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'O código de vinculação é inválido.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _processing = true);
    try {
      final confirmed = await _showConfirmationDialog(request);
      if (confirmed != true || !mounted) return;

      final privateSeed = await _user.extractPrivateSeed();
      final authCode = await _service.authorizeMirrorRequest(
        request: request,
        currentUser: _user.currentUser,
        privateSeed: privateSeed,
      );

      if (mounted) {
        setState(() {
          _authorizedResultCode = authCode;
          _authorizedDeviceName = request.deviceName;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Falha ao autorizar espelhamento. Tente novamente.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<bool?> _showConfirmationDialog(NexoraMirrorRequest request) {
    final colors = Theme.of(context).colorScheme;
    final currentUser = _user.currentUser;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _platformIcon(request.platform),
                color: colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Confirmar Espelhamento',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Um dispositivo solicitou espelhamento da sua conta. Confira as informações abaixo antes de autorizar:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),

              // CARD DE DESTAQUE: Dispositivo que vai receber
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .35),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.arrow_downward_rounded,
                          size: 15,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'DISPOSITIVO QUE VAI RECEBER A CONTA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .5,
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      request.deviceName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sistema: ${_platformLabel(request.platform)} • ID: ${AppTheme.formatKeyPreview(request.deviceId)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Alerta de segurança
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.errorContainer.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colors.error.withValues(alpha: .3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 20,
                      color: colors.error,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ao confirmar, este dispositivo terá acesso total à identidade "${currentUser.nickname.isEmpty ? 'Nexora' : currentUser.nickname}" e poderá ler e enviar mensagens.',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar / Recusar'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.check_circle_rounded, size: 18),
            label: const Text('Confirmar e Espelhar Conta'),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteRequest() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || _processing || _authorizedResultCode != null) return;
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _codeController.text = text;
      await _processRequest(text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Área de transferência vazia.')),
        );
      }
    }
  }

  Future<void> _copyAuthorizationCode() async {
    final code = _authorizedResultCode;
    if (code == null) return;
    await Clipboard.setData(
      ClipboardData(text: _service.encodePrivateCode(code)),
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código privado copiado.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espelhar Conta em Outro Dispositivo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: FrostedCard(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.35),
                  width: 1.1,
                ),
                padding: const EdgeInsets.all(28),
                child: _authorizedResultCode != null
                    ? _buildSuccessView(colors)
                    : _buildScannerView(colors),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScannerView(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Ilustração / Ícone do Scanner
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.primaryContainer.withValues(alpha: .4),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 56,
              color: colors.primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Autorizar novo dispositivo',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'No novo dispositivo, abra “Espelhar Conta”. Escaneie o QR Code ou informe o código de vinculação para revisar o dispositivo.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        MirrorQrActions(onCode: _processing ? null : _processRequest),
        const SizedBox(height: 16),

        // Campo para inserir o código lido do QR Code
        TextField(
          controller: _codeController,
          enabled: !_processing,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Código de vinculação',
            hintText: 'Digite ou cole o código de vinculação',
            alignLabelWithHint: true,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(bottom: 50),
              child: Icon(Icons.qr_code_2_rounded),
            ),
            suffixIcon: IconButton(
              tooltip: 'Limpar',
              icon: const Icon(Icons.clear_rounded),
              onPressed: _processing ? null : _codeController.clear,
            ),
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _processing ? null : _pasteRequest,
                icon: const Icon(Icons.paste_rounded, size: 18),
                label: const Text('Colar da Área de Transferência'),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        FilledButton.icon(
          onPressed: _processing
              ? null
              : () => _processRequest(_codeController.text),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: _processing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.search_rounded),
          label: Text(
            _processing ? 'Processando...' : 'Revisar dispositivo',
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(ColorScheme colors) {
    final code = _authorizedResultCode!;
    final deviceName = _authorizedDeviceName ?? 'Dispositivo';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: .15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Colors.green,
              size: 56,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Dispositivo Autorizado!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Em "$deviceName", escaneie este QR Code ou informe o código privado para concluir a vinculação.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),

        // QR Code de autorização para o receptor
        Center(
          child: QrCodeWidget(
            data: code,
            size: 240,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
          ),
        ),

        const SizedBox(height: 20),

        FilledButton.tonalIcon(
          onPressed: _copyAuthorizationCode,
          icon: const Icon(Icons.copy_rounded, size: 18),
          label: const Text('Copiar código privado'),
        ),

        const SizedBox(height: 12),

        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Concluir'),
        ),
      ],
    );
  }
}
