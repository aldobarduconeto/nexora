import 'package:nexora/src/services/conversation_connection_service.dart';
import 'package:nexora/src/services/file_transfer_service.dart';
import 'package:nexora/src/views/widgets/confirmation_dialog.dart';
import 'package:nexora/src/services/background_connection_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/models/message.dart' as stored;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/services/message_service.dart';
import 'package:nexora/src/services/p2p_connection_service.dart';

class P2PChatPage extends StatefulWidget {
  const P2PChatPage({
    super.key,
    required this.conversationTitle,
    required this.conversation,
  });
  final String conversationTitle;
  final Conversation conversation;

  @override
  State<P2PChatPage> createState() => _P2PChatPageState();
}

class _P2PChatPageState extends State<P2PChatPage> {
  final _background = BackgroundConnectionService();
  bool _busy = false;
  late bool _wasBlocked;
  bool _searching = false;
  String _query = '';
  final _user = LocalDataService.instance;
  bool get _isBlocked => widget.conversation.isGroup
      ? _connection.peerKeys.any(_user.isBlocked)
      : _user.isBlocked(_connection.remotePublicKey);
  bool _clearAfterAction = false;
  bool _showConnection = true;
  Timer? _retentionTimer;
  final _settings = SettingsService.instance;
  final Map<DecryptedMessage, DateTime> _receivedAt = {};
  bool _sending = false;
  bool _sendingFile = false;
  late final FileTransferService _files;
  final List<DecryptedMessage> _messages = [];
  late final ConversationConnectionService _connection;
  final ScrollController _scrollController = ScrollController();
  late final StreamSubscription<DecryptedMessage> _messageSubscription;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _signalingController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_preferencesChanged);
    _retentionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pruneMessages(),
    );
    _connection = ConversationConnectionService(
      conversation: widget.conversation,
      connectionTimeoutSeconds: _settings.settings.connectionTimeoutSeconds,
      localUserId: _user.currentUser.id,
    );
    _files = FileTransferService(
      send: _connection.sendMessage,
      notice: (text) {
        if (mounted)
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(text)));
      },
    );
    _connection.addListener(_refresh);
    _wasBlocked = _isBlocked;
    _user.addListener(_contactChanged);
    for (final saved in widget.conversation.messages) {
      final message = DecryptedMessage(
        id: saved.messageId.toString(),
        conversationId: saved.sessionId,
        senderId: saved.senderId,
        content: saved.textMsg,
        sentAt: saved.sentAt,
      );
      _messages.add(message);
      _receivedAt[message] = saved.receivedAt;
    }
    _trimMessages();
    if (widget.conversation.messages.isNotEmpty) unawaited(_persistHistory());
    _messageSubscription = _connection.messages.listen(
      (message) {
        if (!mounted) return;
        if (message.content.startsWith('NEXORA_FILE_V1:')) {
          if (message.senderId != _user.currentUser.id) {
            unawaited(_files.receive(message.content));
          }
          return;
        }
        setState(() {
          _messages.add(message);
          _receivedAt[message] = DateTime.now();
          _trimMessages();
        });
        unawaited(_persistHistory());
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            if (!_settings.settings.animationsEnabled ||
                MediaQuery.of(context).disableAnimations) {
              _scrollController.jumpTo(
                _scrollController.position.maxScrollExtent,
              );
              return;
            }
            _scrollController.animateTo(
              curve: Curves.easeOut,
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 200),
            );
          }
        });
      },
      onError: (Object error) {
        if (mounted) _showError(error);
      },
    );
  }

  @override
  void dispose() {
    _settings.removeListener(_preferencesChanged);
    _retentionTimer?.cancel();
    unawaited(_files.close());
    unawaited(_stopBackground());
    if (_settings.settings.localRetentionMinutes == 0 &&
        _user.conversations.any((c) => c.id == widget.conversation.id)) {
      unawaited(
        _user
            .updateHistory(widget.conversation.id, const [])
            .catchError((Object _) {}),
      );
    }
    _user.removeListener(_contactChanged);
    _connection.removeListener(_refresh);
    unawaited(_messageSubscription.cancel());
    unawaited(_connection.close());
    _signalingController.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _stopBackground() async {
    try {
      await _background.stop();
    } catch (_) {
      if (mounted)
        _showError(
          StateError('Não foi possível encerrar o serviço de conexão.'),
        );
    }
  }

  void _refresh() {
    if (!_busy &&
        (_connection.status == P2PConnectionStatus.disconnected ||
            _connection.status == P2PConnectionStatus.failed)) {
      unawaited(_stopBackground());
      unawaited(_files.abort());
    }
    if (mounted)
      setState(() {
        if (_connection.isConnected) _showConnection = false;
      });
  }

  void _trimMessages() {
    final minutes = _settings.settings.localRetentionMinutes;
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    _messages.removeWhere(
      (message) =>
          minutes > 0 && (_receivedAt[message]?.isBefore(cutoff) ?? false),
    );
    final retained = _messages.toSet();
    _receivedAt.removeWhere((message, _) => !retained.contains(message));
  }

  void _pruneMessages() {
    if (!mounted || _settings.settings.localRetentionMinutes == 0) return;
    final before = _messages.length;
    _trimMessages();
    if (_messages.length != before) {
      setState(() {});
      unawaited(_persistHistory());
    }
  }

  void _preferencesChanged() {
    if (!mounted) return;
    final before = _messages.length;
    _trimMessages();
    setState(() {});
    if (_messages.length != before) unawaited(_persistHistory());
  }

  void _contactChanged() {
    if (!mounted) return;
    setState(() {});
    if (_wasBlocked == _isBlocked) return;
    _wasBlocked = _isBlocked;
    setState(() {});
    if (!_isBlocked) return;
    unawaited(_clearLocal());
    if (_busy) {
      _clearAfterAction = true;
    } else {
      unawaited(_runConnectionAction(_connection.disconnect));
    }
  }

  Future<void> _blockContact() async {
    final confirmed = await confirmAction(
      context,
      title: 'Bloquear contato?',
      description: 'Encerra a conexão, limpa o histórico local e impede novos convites e mensagens desta chave neste dispositivo.',
      action: 'Bloquear',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _user.setBlocked(_connection.remotePublicKey, true);
    } catch (_) {
      if (mounted)
        _showError(StateError('Não foi possível salvar o bloqueio.'));
    }
  }

  Future<void> _persistHistory() async {
    final messages = _messages
        .map(
          (m) => stored.Message(
            messageId: int.parse(m.id),
            sentAt: m.sentAt,
            textMsg: m.content,
            senderId: m.senderId,
            sessionId: m.conversationId,
            receivedAt: _receivedAt[m] ?? m.sentAt,
          ),
        )
        .toList();
    try {
      await _user.updateHistory(widget.conversation.id, messages);
    } catch (_) {
      if (mounted)
        _showError(
          StateError(
            'Não foi possível atualizar o histórico no armazenamento seguro.',
          ),
        );
    }
  }

  Future<void> _clearLocal() async {
    setState(() {
      _messages.clear();
      _receivedAt.clear();
      _query = '';
      _searching = false;
      _messageController.clear();
      _signalingController.clear();
    });
    await _persistHistory();
  }

  Future<void> _confirmClear() async {
    final clear = await confirmAction(
      context,
      title: 'Limpar mensagens locais?',
      description: 'As mensagens e o rascunho serão removidos desta tela. Cópias do contato permanecem.',
      action: 'Limpar',
    );
    if (clear == true && mounted) await _clearLocal();
  }

  Future<void> _runConnectionAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      await _connection.disconnect();
      if (mounted) _showError(error);
    } finally {
      if (_clearAfterAction) {
        await _connection.disconnect();
        if (mounted) await _clearLocal();
        _clearAfterAction = false;
      }
      if (_connection.status == P2PConnectionStatus.disconnected ||
          _connection.status == P2PConnectionStatus.failed) {
        await _files.abort();
        await _stopBackground();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareSignaling(Future<String> Function() prepare) =>
      _runConnectionAction(() async {
        await _background.start();
        final signaling = await prepare();
        if (mounted) _signalingController.text = signaling;
      });

  Future<void> _createOffer() => _prepareSignaling(_connection.createOffer);

  Future<void> _acceptOffer() => _prepareSignaling(
    () => _connection.acceptOffer(_signalingController.text.trim()),
  );

  Future<void> _acceptAnswer() => _runConnectionAction(
    () => _connection.acceptAnswer(_signalingController.text.trim()),
  );

  Future<void> _copySignalingData() async {
    if (_signalingController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _signalingController.text));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Convite copiado.')));
    }
  }

  Future<void> _sendFile() async {
    if (_sendingFile || _busy || _isBlocked) return;
    final proceed = await confirmAction(
      context,
      title: 'Enviar arquivo',
      description: 'Recomendamos enviar apenas arquivos .safe para ajudar a preservar sua privacidade. A extensão sozinha não garante proteção: use arquivos preparados por uma ferramenta confiável. Qualquer formato é aceito, sem limite de tamanho imposto pelo app; o envio depende do espaço disponível e da conexão. O destinatário escolherá onde salvar.',
      action: 'Escolher arquivo',
    );
    if (proceed != true || !mounted) return;
    setState(() => _sendingFile = true);
    try {
      await _files.pickAndSend();
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sendingFile = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_sending || _busy) return;
    setState(() => _sending = true);
    final text = _messageController.text;
    try {
      await _connection.sendMessage(text);
      if (mounted && _messageController.text == text)
        _messageController.clear();
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível concluir a operação. Verifique a conexão e tente novamente.',
        ),
      ),
    );
  }

  String get _statusLabel => widget.conversation.isGroup
      ? '${_connection.connectedCount}/${_connection.peerKeys.length} participantes conectados'
      : _isBlocked
      ? 'Contato bloqueado'
      : switch (_connection.status) {
          P2PConnectionStatus.disconnected => 'Desconectado',
          P2PConnectionStatus.negotiating => 'Preparando conexão...',
          P2PConnectionStatus.waitingForAnswer => 'Aguardando resposta',
          P2PConnectionStatus.connecting => 'Conectando...',
          P2PConnectionStatus.connected => 'Conectado com criptografia',
          P2PConnectionStatus.failed => 'Conexão encerrada ou falhou',
        };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final visible = _query.isEmpty
        ? _messages
        : _messages
              .where((m) => m.content.toLowerCase().contains(_query))
              .toList();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _user.conversationName(widget.conversation),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: _connection.isConnected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: Icon(_searching ? Icons.search_off : Icons.search),
              tooltip: 'Buscar mensagens locais',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              }),
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: 'Dados de conexão',
              onPressed: () =>
                  setState(() => _showConnection = !_showConnection),
            ),
            PopupMenuButton<String>(
              tooltip: 'Opções da conversa',
              onSelected: (value) {
                if (value == 'clear') {
                  unawaited(_confirmClear());
                } else if (value == 'block') {
                  unawaited(_blockContact());
                } else {
                  unawaited(_runConnectionAction(_connection.disconnect));
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'block',
                  enabled: !_busy && !_isBlocked,
                  child: Text(
                    widget.conversation.isGroup
                        ? 'Bloquear participante selecionado'
                        : 'Bloquear contato',
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear',
                  child: Text('Limpar mensagens locais'),
                ),
                PopupMenuItem(
                  value: 'disconnect',
                  enabled: !_busy,
                  child: const Text('Desconectar'),
                ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: PageFrame(
            maxWidth: 960,
            child: LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  if (_showConnection)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * .45,
                      ),
                      child: SingleChildScrollView(
                        child: _buildConnectionPanel(),
                      ),
                    ),
                  if (_searching)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: TextField(
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Buscar nesta conversa',
                          prefixIcon: Icon(Icons.search),
                          isDense: true,
                        ),
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                  Expanded(child: _buildMessages(constraints, visible)),
                  _buildComposer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessages(
    BoxConstraints constraints,
    List<DecryptedMessage> visible,
  ) {
    final colors = Theme.of(context).colorScheme;
    if (visible.isEmpty)
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isBlocked ? Icons.block : Icons.lock_outline,
                color: colors.primary,
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                _query.isNotEmpty
                    ? 'Nenhuma mensagem encontrada'
                    : _isBlocked
                    ? 'Contato bloqueado'
                    : 'Somente entre vocês',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isBlocked
                    ? 'Desbloqueie nas configurações para conversar.'
                    : _query.isNotEmpty
                    ? 'Tente outro termo de busca.'
                    : _connection.isConnected
                    ? 'Conexão pronta. Envie sua primeira mensagem.'
                    : 'Troquem convite e resposta para iniciar.',
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final message = visible[index];
        final local = message.senderId == _user.currentUser.id;
        final time = message.sentAt.toLocal();
        return Align(
          alignment: local ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: (constraints.maxWidth * .82).clamp(180, 620).toDouble(),
            ),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            decoration: BoxDecoration(
              color: local ? colors.primaryContainer : colors.surface,
              border: Border.all(color: colors.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.conversation.isGroup)
                  Text(
                    _user.contactName(message.senderId),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                SelectableText(
                  message.content,
                  style: TextStyle(
                    color: local ? colors.onPrimaryContainer : colors.onSurface,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: local
                        ? colors.onPrimaryContainer.withValues(alpha: .7)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionPanel() {
    final colors = Theme.of(context).colorScheme;
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
                  Icon(Icons.hub_outlined, color: colors.primary, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Conectar com o contato',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (_busy)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Crie e compartilhe um convite. Quem receber gera uma resposta; quem convidou aplica a resposta.',
                style: TextStyle(
                  color: colors.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              if (widget.conversation.isGroup) ...[
                const SizedBox(height: 12),
                const Text(
                  'Conecte cada participante separadamente. Todos precisam conectar entre si para receber o grupo completo.',
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _connection.remotePublicKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Participante para conectar',
                  ),
                  items: _connection.peerKeys
                      .map(
                        (key) => DropdownMenuItem(
                          value: key,
                          child: Text(
                            '${_user.contactName(key)}${_user.hasContactName(key) ? "" : " (participante ${_connection.peerKeys.indexOf(key) + 1})"}${_connection.peerConnected(key) ? " - conectado" : ""}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _busy
                      ? null
                      : (key) {
                          if (key == null) return;
                          _signalingController.clear();
                          _connection.selectPeer(key);
                          _contactChanged();
                        },
                ),
              ],
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Conferir chave pública',
                  style: TextStyle(fontSize: 13),
                ),
                children: [
                  SelectableText(
                    _connection.remotePublicKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Compare a chave com seu contato por outro canal antes de continuar.',
                    style: TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _signalingController,
                enabled: !_busy,
                obscureText: true,
                maxLines: 1,
                enableIMEPersonalizedLearning: false,
                maxLength: 131072,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                  hintText: 'Cole o convite ou a resposta recebida',
                  counterText: 'Convite válido por 10 minutos',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton(
                    onPressed: _busy || _isBlocked ? null : _createOffer,
                    child: const Text('Criar convite'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy ||
                            _isBlocked ||
                            _signalingController.text.trim().isEmpty
                        ? null
                        : _acceptOffer,
                    child: const Text('Gerar resposta'),
                  ),
                  OutlinedButton(
                    onPressed:
                        _busy ||
                            _isBlocked ||
                            !_connection.canApplyAnswer ||
                            _signalingController.text.trim().isEmpty
                        ? null
                        : _acceptAnswer,
                    child: const Text('Aplicar resposta'),
                  ),
                  TextButton.icon(
                    onPressed: _busy || _signalingController.text.isEmpty
                        ? null
                        : _copySignalingData,
                    icon: const Icon(Icons.copy_outlined, size: 16),
                    label: const Text('Copiar'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'No modo direto, seu contato pode descobrir seu IP. STUN não anonimiza. Para ocultar o IP do contato, use uma compilação configurada para TURN exclusivo. Convites contêm metadados de rede; compartilhe por um canal confiável.',
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          onPressed:
              _connection.isConnected &&
                  !_sendingFile &&
                  !_busy &&
                  !_isBlocked &&
                  !widget.conversation.isGroup
              ? _sendFile
              : null,
          icon: _sendingFile
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.attach_file),
          tooltip: widget.conversation.isGroup
              ? 'Arquivos disponíveis em conversas individuais'
              : 'Enviar arquivo — recomendamos .safe',
        ),
        Expanded(
          child: TextField(
            controller: _messageController,
            enabled: _connection.isConnected && !_busy && !_isBlocked,
            minLines: 1,
            maxLines: 4,
            maxLength: 16000,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: _connection.isConnected
                  ? 'Escreva uma mensagem'
                  : 'Conecte-se para conversar',
              counterText: '',
            ),
            onSubmitted: (_) {
              if (_connection.isConnected) unawaited(_sendMessage());
            },
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filled(
          onPressed:
              _connection.isConnected && !_sending && !_busy && !_isBlocked
              ? _sendMessage
              : null,
          icon: const Icon(Icons.arrow_upward),
          tooltip: 'Enviar mensagem',
          padding: const EdgeInsets.all(14),
        ),
      ],
    ),
  );
}
