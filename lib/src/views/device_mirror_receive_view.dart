import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/services/device_mirror_service.dart';
import 'package:nexora/src/utils/qr_code.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';

class DeviceMirrorReceiveView extends StatefulWidget {
  const DeviceMirrorReceiveView({
    super.key,
    required this.onAccountMirrored,
  });

  final VoidCallback onAccountMirrored;

  @override
  State<DeviceMirrorReceiveView> createState() =>
      _DeviceMirrorReceiveViewState();
}

class _DeviceMirrorReceiveViewState extends State<DeviceMirrorReceiveView> {
  final _service = DeviceMirrorService.instance;
  NexoraMirrorSession? _session;
  String _deviceName = '';
  bool _loading = true;
  bool _applying = false;
  String? _errorMessage;

  final _authCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _deviceName = _service.detectDeviceName();
    _generateMirrorSession();
  }

  @override
  void dispose() {
    _authCodeController.dispose();
    super.dispose();
  }

  Future<void> _generateMirrorSession() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final session = await _service.createMirrorRequest(
        customDeviceName: _deviceName,
      );
      if (mounted) {
        setState(() {
          _session = session;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Não foi possível gerar a solicitação de espelhamento.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _editDeviceName() async {
    String current = _deviceName;
    final formKey = GlobalKey<FormState>();

    final chosen = await showDialog<String>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, size: 20),
            SizedBox(width: 8),
            Text('Nome deste dispositivo'),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Este é o nome que aparecerá na tela do dispositivo host para você confirmar o espelhamento:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: current,
                maxLength: 40,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nome do dispositivo',
                  hintText: 'Ex: Meu Notebook, Celular Trabalho',
                  prefixIcon: Icon(Icons.devices_rounded),
                ),
                onChanged: (val) => current = val,
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Informe um nome.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogCtx, current.trim());
              }
            },
            child: const Text('Salvar e Atualizar QR Code'),
          ),
        ],
      ),
    );

    if (chosen != null && chosen.isNotEmpty && chosen != _deviceName) {
      setState(() => _deviceName = chosen);
      await _generateMirrorSession();
    }
  }

  Future<void> _copyQrData() async {
    final session = _session;
    if (session == null) return;
    await Clipboard.setData(ClipboardData(text: session.request.serialize()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dados do dispositivo copiados para a área de transferência.'),
        ),
      );
    }
  }

  Future<void> _applyAuthorization([String? code]) async {
    final rawCode = code ?? _authCodeController.text.trim();
    if (rawCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o código de autorização gerado pelo host.')),
      );
      return;
    }

    final session = _session;
    if (session == null) return;

    setState(() => _applying = true);

    try {
      await _service.completeMirrorReceive(
        authorizationPackage: rawCode,
        receiverEphemeralKeyPair: session.receiverEphemeralKeyPair,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Conta espelhada com sucesso!')),
              ],
            ),
            backgroundColor: Color(0xFF2E7D32),
          ),
        );
        widget.onAccountMirrored();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Código de autorização inválido ou expirado. Tente novamente.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _authCodeController.text = text;
      await _applyAuthorization(text);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum texto encontrado na área de transferência.')),
        );
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Espelhar Conta neste Dispositivo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 540),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cabeçalho explicativo
                  const Text(
                    'Vincular Dispositivo',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No seu dispositivo principal com a conta do Nexora, aponte a câmera para ler o QR Code abaixo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 13.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // QR Code centralizado na tela
                  if (_loading)
                    Container(
                      height: 260,
                      width: 260,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Gerando QR Code seguro...'),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    Container(
                      height: 260,
                      width: 260,
                      padding: const EdgeInsets.all(16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.errorContainer.withValues(alpha: .2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 40, color: colors.error),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.error, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: _generateMirrorSession,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  else if (_session != null)
                    Center(
                      child: Hero(
                        tag: 'mirror_qr_code',
                        child: QrCodeWidget(
                          data: _session!.request.serialize(),
                          size: 250,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          centerWidget: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _platformIcon(_session!.request.platform),
                              size: 20,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Identificação do dispositivo que vai receber
                  Card(
                    elevation: 0,
                    color: colors.surfaceContainerHighest.withValues(alpha: .45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: .7),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.primaryContainer.withValues(alpha: .6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _platformIcon(_service.detectPlatform()),
                              color: colors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Dispositivo Receptor',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _deviceName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Alterar nome do dispositivo',
                            onPressed: _editDeviceName,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Botão alternativo para copiar dados
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _session == null ? null : _copyQrData,
                        icon: const Icon(Icons.copy_rounded, size: 17),
                        label: const Text('Copiar código do QR Code'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _generateMirrorSession,
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        label: const Text('Atualizar QR Code'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Área para inserir autorização do Host
                  Text(
                    'Etapa final: Concluir espelhamento',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Após você confirmar o espelhamento no dispositivo host, insira o código de autorização gerado:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _authCodeController,
                          enabled: !_applying,
                          decoration: const InputDecoration(
                            labelText: 'Código de autorização do Host',
                            hintText: 'Cole a resposta autorizada aqui',
                            prefixIcon: Icon(Icons.vpn_key_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        tooltip: 'Colar da área de transferência',
                        onPressed: _applying ? null : _pasteFromClipboard,
                        icon: const Icon(Icons.paste_rounded),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  FilledButton.icon(
                    onPressed: _applying ? null : () => _applyAuthorization(),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    icon: _applying
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded),
                    label: Text(
                      _applying
                          ? 'Validando e espelhando...'
                          : 'Concluir Espelhamento de Conta',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
