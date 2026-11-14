import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/models/message.dart' as stored;
import 'package:nexora/src/models/scheduled_message.dart';
import 'package:nexora/src/services/background_connection_service.dart';
import 'package:nexora/src/services/conversation_connection_service.dart';
import 'package:nexora/src/services/conversation_tabs_service.dart';
import 'package:nexora/src/services/group_invitation_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/message_service.dart';
import 'package:nexora/src/services/p2p_connection_service.dart';
import 'package:nexora/src/services/scheduled_message_service.dart';
import 'package:nexora/src/services/settings_services.dart';
import 'package:nexora/src/utils/qr_code.dart';
import 'package:nexora/src/views/widgets/app_theme.dart';
import 'package:nexora/src/views/widgets/call_panel.dart';
import 'package:nexora/src/views/widgets/chat_wallpaper.dart';
import 'package:nexora/src/views/widgets/community_channels_bar.dart';
import 'package:nexora/src/views/widgets/confirmation_dialog.dart';
import 'package:nexora/src/views/widgets/connection_assistant_card.dart';
import 'package:nexora/src/views/widgets/crypto_avatar.dart';
import 'package:nexora/src/views/widgets/message_reactions_view.dart';
import 'package:nexora/src/views/widgets/pinned_messages_bar.dart';
import 'package:nexora/src/views/widgets/poll_widget.dart';
import 'package:nexora/src/views/widgets/reply_snippet_widget.dart';
import 'package:nexora/src/views/widgets/safety_numbers_dialog.dart';
import 'package:nexora/src/views/widgets/security_hud.dart';
import 'package:nexora/src/views/widgets/stealth_blur.dart';
import 'package:nexora/src/views/widgets/view_once_bubble.dart';
import 'package:nexora/src/views/widgets/voice_message_bubble.dart';

class P2PChatPage extends StatefulWidget {
  const P2PChatPage({
    super.key,
    required this.conversationTitle,
    required this.conversation,
    this.isTabMode = false,
  });
  final String conversationTitle;
  final Conversation conversation;
  final bool isTabMode;

  @override
  State<P2PChatPage> createState() => _P2PChatPageState();
}

class _P2PChatPageState extends State<P2PChatPage> {
  final _background = BackgroundConnectionService();
  final _user = LocalDataService.instance;
  final _settings = SettingsService.instance;
  final _scheduledService = ScheduledMessageService.instance;

  bool _busy = false;
  late bool _wasBlocked;
  bool _searching = false;
  bool _obscureSignaling = true;
  String _query = '';
  bool _clearAfterAction = false;
  bool _showConnection = true;
  bool _sending = false;
  bool _sendingFile = false;
  DecryptedMessage? _replyingTo;
  String _activeChannel = 'geral';
  bool _viewOnceMode = false;
  int? _ephemeralTimerSeconds;
  DateTime? _lastCommunitySentAt;

  Timer? _retentionTimer;
  Timer? _persistDebounceTimer;
  final List<DecryptedMessage> _messages = [];
  late final ConversationConnectionService _connection;
  final ScrollController _scrollController = ScrollController();
  late final StreamSubscription<DecryptedMessage> _messageSubscription;
  StreamSubscription<ScheduledMessage>? _scheduledSub;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _signalingController = TextEditingController();

  bool get _isBlocked => widget.conversation.isSavedMessages
      ? false
      : (widget.conversation.isGroup
          ? _connection.peerKeys.any(_user.isBlocked)
          : _user.isBlocked(_connection.remotePublicKey));

  @override
  void initState() {
    super.initState();
    _activeChannel = widget.conversation.channels.isNotEmpty
        ? widget.conversation.channels.first
        : 'geral';
    _ephemeralTimerSeconds = widget.conversation.ephemeralRetentionSeconds;
    _settings.addListener(_preferencesChanged);
    _scheduledService.addListener(_refresh);
    _scheduledSub = _scheduledService.onDueMessage.listen((dueMsg) {
      if (mounted && dueMsg.conversationId == widget.conversation.id) {
        _dispatchScheduledMessage(dueMsg);
      }
    });
    _retentionTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _pruneMessages(),
    );
    if (widget.conversation.isSavedMessages) {
      _showConnection = false;
    }
    _connection = ConversationConnectionService(
      conversation: widget.conversation,
      connectionTimeoutSeconds: _settings.settings.connectionTimeoutSeconds,
      localUserId: _user.currentUser.id,
      onNotice: (text) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(text)));
        }
      },
    );
    _connection.addListener(_refresh);
    _wasBlocked = _isBlocked;
    _user.addListener(_contactChanged);
    for (final saved in widget.conversation.messages) {
      _messages.add(
        DecryptedMessage(
          id: saved.messageId.toString(),
          conversationId: saved.sessionId,
          senderId: saved.senderId,
          content: saved.textMsg,
          sentAt: saved.sentAt,
          receivedAt: saved.receivedAt,
          replyToId: saved.replyToId,
          replySnippet: saved.replySnippet,
          replySender: saved.replySender,
          mediaType: saved.mediaType,
          audioDurationSeconds: saved.audioDurationSeconds,
          audioWaveform: saved.audioWaveform,
          reactions: saved.reactions,
          isPinned: saved.isPinned,
          isStarred: saved.isStarred,
          channel: saved.channel,
          pollQuestion: saved.pollQuestion,
          pollOptions: saved.pollOptions,
          pollVotes: saved.pollVotes,
          isViewOnce: saved.isViewOnce,
          viewedAt: saved.viewedAt,
          ephemeralSeconds: saved.ephemeralSeconds,
        ),
      );
    }
    _trimMessages();
    if (widget.conversation.messages.isNotEmpty) unawaited(_persistHistory());
    _messageSubscription = _connection.messages.listen(
      (message) {
        if (!mounted) return;
        setState(() {
          _messages.add(message);
          _trimMessages();
        });
        _schedulePersistHistory();
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
    _scheduledService.removeListener(_refresh);
    _scheduledSub?.cancel();
    _retentionTimer?.cancel();
    if (_persistDebounceTimer?.isActive ?? false) {
      _persistDebounceTimer!.cancel();
      unawaited(_persistHistory());
    }
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
      if (mounted) {
        _showError(
          StateError('Não foi possível encerrar o serviço de conexão.'),
        );
      }
    }
  }

  void _refresh() {
    if (!_busy &&
        !_connection.hasConnectedPeers &&
        (_connection.status == P2PConnectionStatus.disconnected ||
            _connection.status == P2PConnectionStatus.failed)) {
      unawaited(_stopBackground());
      unawaited(_connection.abortFiles());
    }
    if (mounted) {
      setState(() {
        if (_connection.isConnected) _showConnection = false;
      });
      ConversationTabsService.instance.setTabCallState(
        widget.conversation.id,
        _connection.isInCall,
      );
    }
  }

  void _trimMessages() {
    final minutes = _settings.settings.localRetentionMinutes;
    if (minutes <= 0) return;
    final cutoff = DateTime.now().subtract(Duration(minutes: minutes));
    _messages.removeWhere((message) => message.receivedAt.isBefore(cutoff));
  }

  void _pruneMessages() {
    if (!mounted || _settings.settings.localRetentionMinutes <= 0) return;
    final before = _messages.length;
    _trimMessages();
    if (_messages.length != before) {
      setState(() {});
      _schedulePersistHistory();
    }
  }

  void _preferencesChanged() {
    if (!mounted) return;
    final before = _messages.length;
    _trimMessages();
    setState(() {});
    if (_messages.length != before) _schedulePersistHistory();
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
      description:
          'Encerra a conexão, limpa o histórico local e impede novos convites e mensagens desta chave neste dispositivo.',
      action: 'Bloquear',
    );
    if (confirmed != true || !mounted) return;
    try {
      await _user.setBlocked(_connection.remotePublicKey, true);
    } catch (_) {
      if (mounted) {
        _showError(StateError('Não foi possível salvar o bloqueio.'));
      }
    }
  }

  void _schedulePersistHistory() {
    _persistDebounceTimer?.cancel();
    _persistDebounceTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_persistHistory()),
    );
  }

  Future<void> _persistHistory() async {
    _persistDebounceTimer?.cancel();
    final messages = _messages.asMap().entries
        .map(
          (entry) {
            final m = entry.value;
            return stored.Message(
              messageId: int.tryParse(m.id) ?? (entry.key + 1),
              sentAt: m.sentAt,
              textMsg: m.content,
              senderId: m.senderId,
              sessionId: m.conversationId,
              receivedAt: m.receivedAt,
              replyToId: m.replyToId,
              replySnippet: m.replySnippet,
              replySender: m.replySender,
              mediaType: m.mediaType,
              audioDurationSeconds: m.audioDurationSeconds,
              audioWaveform: m.audioWaveform,
              reactions: m.reactions,
              isPinned: m.isPinned,
              isStarred: m.isStarred,
              channel: m.channel,
              pollQuestion: m.pollQuestion,
              pollOptions: m.pollOptions,
              pollVotes: m.pollVotes,
              isViewOnce: m.isViewOnce,
              viewedAt: m.viewedAt,
              ephemeralSeconds: m.ephemeralSeconds,
            );
          },
        )
        .toList(growable: false);
    try {
      await _user.updateHistory(widget.conversation.id, messages);
    } catch (_) {
      if (mounted) {
        _showError(
          StateError(
            'Não foi possível atualizar o histórico no armazenamento seguro.',
          ),
        );
      }
    }
  }

  Future<void> _clearLocal() async {
    setState(() {
      _messages.clear();
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
      description:
          'As mensagens e o rascunho serão removidos desta tela. Cópias do contato permanecem.',
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
      if (!_connection.hasConnectedPeers &&
          (_connection.status == P2PConnectionStatus.disconnected ||
              _connection.status == P2PConnectionStatus.failed)) {
        await _connection.abortFiles();
        await _stopBackground();
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _prepareSignaling(
    Future<String> Function() prepare, {
    required String copiedNotice,
  }) => _runConnectionAction(() async {
    await _background.start();
    final signaling = await prepare();
    await Clipboard.setData(ClipboardData(text: signaling));
    if (mounted) {
      _signalingController.text = signaling;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(copiedNotice)));
    }
  });

  Future<void> _createOffer() => _prepareSignaling(
    _connection.createOffer,
    copiedNotice:
        'Convite gerado e copiado! Envie ao contato e aguarde a resposta.',
  );

  Future<void> _acceptOffer() => _prepareSignaling(
    () => _connection.acceptOffer(_signalingController.text.trim()),
    copiedNotice:
        'Resposta gerada e copiada! Envie de volta ao contato para conectar.',
  );

  Future<void> _acceptAnswer() => _runConnectionAction(
    () => _connection.acceptAnswer(_signalingController.text.trim()),
  );

  Future<void> _copySignalingData() async {
    if (_signalingController.text.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _signalingController.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dados de conexão copiados para a área de transferência.',
          ),
        ),
      );
    }
  }

  Future<void> _pasteSignalingData() async {
    final data = await Clipboard.getData('text/plain');
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _signalingController.text = text;
    });
  }

  Future<void> _startCall({required bool video}) async {
    if (!_connection.canStartCall || _busy || _isBlocked) return;
    try {
      VideoStreamPreset? preset;
      if (video) {
        preset = await pickVideoStreamPreset(
          context,
          current: VideoStreamPreset.fromId(
            SettingsService.instance.settings.videoStreamingPreset,
          ),
          forScreenShare: false,
          title: 'Resolução da Transmissão de Vídeo',
        );
        if (preset == null) return;
      }
      await _connection.startCall(video: video, preset: preset);
    } on Object catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _startOrToggleScreenShare() async {
    if (_busy || _isBlocked || !_connection.hasConnectedPeers) return;
    try {
      if (_connection.isInCall) {
        if (_connection.isScreenSharing) {
          await _connection.stopScreenShare();
        } else {
          final picked = await pickScreenShareSource(context);
          if (!picked.proceed || !mounted) return;
          final preset = await pickVideoStreamPreset(
            context,
            current: _connection.currentVideoPreset,
            forScreenShare: true,
            title: 'Resolução do Compartilhamento de Tela',
          );
          if (preset == null) return;
          await _connection.setVideoQuality(preset);
          await _connection.toggleScreenShare(source: picked.source);
        }
        return;
      }
      final picked = await pickScreenShareSource(context);
      if (!picked.proceed || !mounted) return;
      final preset = await pickVideoStreamPreset(
        context,
        current: VideoStreamPreset.fromId(
          SettingsService.instance.settings.videoStreamingPreset,
        ),
        forScreenShare: true,
        title: 'Resolução da Transmissão de Tela',
      );
      if (preset == null) return;
      await _connection.startCall(
        video: true,
        screenShare: true,
        screenSource: picked.source,
        preset: preset,
      );
    } on Object catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _sendFile() async {
    if (_sendingFile || _busy || _isBlocked || !_connection.hasConnectedPeers) {
      return;
    }
    final proceed = await confirmAction(
      context,
      title: widget.conversation.isGroup
          ? 'Enviar arquivo ao grupo P2P'
          : 'Enviar arquivo P2P',
      description:
          'Recomendamos enviar apenas arquivos .safe para ajudar a preservar sua privacidade. Qualquer formato é aceito, sem limite de tamanho imposto pelo app; o envio depende do espaço disponível e da conexão. Cada destinatário conectado escolherá onde salvar.',
      action: 'Escolher arquivo',
    );
    if (proceed != true || !mounted) return;
    setState(() => _sendingFile = true);
    try {
      await _connection.pickAndSendFile();
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sendingFile = false);
    }
  }

  Future<void> _sendMessage() async {
    if (_sending || _busy) return;
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (widget.conversation.isCommunity && _settings.settings.communitySlowModeSeconds > 0) {
      if (_lastCommunitySentAt != null) {
        final elapsed = DateTime.now().difference(_lastCommunitySentAt!).inSeconds;
        final waitSeconds = _settings.settings.communitySlowModeSeconds;
        if (elapsed < waitSeconds) {
          final remaining = waitSeconds - elapsed;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⏳ Modo lento ativo nesta comunidade: aguarde ${remaining}s para enviar outra mensagem.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      }
      _lastCommunitySentAt = DateTime.now();
    }

    if (_settings.settings.hapticFeedback) {
      HapticFeedback.lightImpact();
    }

    setState(() => _sending = true);
    final reply = _replyingTo;
    final isComm = widget.conversation.isCommunity || widget.conversation.channels.isNotEmpty;
    final ch = isComm ? _activeChannel : null;
    final isViewOnce = _viewOnceMode;
    final ephSeconds = _ephemeralTimerSeconds;

    try {
      final replySender = reply != null
          ? (reply.senderId == _user.currentUser.id
              ? 'Você'
              : _user.contactName(reply.senderId))
          : null;

      await _dispatchTextMessage(
        text: text,
        replyToId: reply?.id,
        replySnippet: reply?.content,
        replySender: replySender,
        channel: ch,
        isViewOnce: isViewOnce,
        ephemeralSeconds: ephSeconds,
      );

      if (mounted) {
        _messageController.clear();
        setState(() {
          _replyingTo = null;
          _viewOnceMode = false;
        });
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _dispatchTextMessage({
    required String text,
    String? replyToId,
    String? replySnippet,
    String? replySender,
    String? channel,
    bool isViewOnce = false,
    int? ephemeralSeconds,
  }) async {
    if (widget.conversation.isSavedMessages) {
      final id = '${DateTime.now().millisecondsSinceEpoch}';
      final now = DateTime.now();
      final msg = DecryptedMessage(
        id: id,
        conversationId: widget.conversation.id,
        senderId: _user.currentUser.id,
        content: text,
        sentAt: now,
        replyToId: replyToId,
        replySnippet: replySnippet,
        replySender: replySender,
        channel: channel,
        isViewOnce: isViewOnce,
        ephemeralSeconds: ephemeralSeconds,
      );
      if (mounted) {
        setState(() {
          _messages.add(msg);
        });
      }
      _schedulePersistHistory();
    } else {
      final richPayload = jsonEncode({
        'nx_type': 'rich',
        'text': text,
        if (replyToId != null) 'replyToId': replyToId,
        if (replySnippet != null) 'replySnippet': replySnippet,
        if (replySender != null) 'replySender': replySender,
        if (channel != null) 'channel': channel,
        if (isViewOnce) 'isViewOnce': true,
        if (ephemeralSeconds != null) 'ephemeralSeconds': ephemeralSeconds,
      });
      await _connection.sendMessage(richPayload);
    }
  }

  Future<void> _dispatchScheduledMessage(ScheduledMessage dueMsg) async {
    try {
      await _dispatchTextMessage(
        text: dueMsg.content,
        replyToId: dueMsg.replyToId,
        replySnippet: dueMsg.replySnippet,
        replySender: dueMsg.replySender,
        channel: dueMsg.channel,
        isViewOnce: dueMsg.isViewOnce,
        ephemeralSeconds: dueMsg.ephemeralSeconds,
      );
      await _scheduledService.markAsSent(dueMsg.id);
      if (mounted) {
        if (_settings.settings.hapticFeedback) {
          HapticFeedback.lightImpact();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🕒 Mensagem agendada enviada: "${dueMsg.content.length > 28 ? '${dueMsg.content.substring(0, 28)}...' : dueMsg.content}"',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Falha ao disparar mensagem agendada: $e');
    }
  }

  Future<void> _showScheduleSendDialog() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Digite uma mensagem antes de agendar o envio.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_settings.settings.hapticFeedback) {
      HapticFeedback.selectionClick();
    }

    DateTime selectedTime = DateTime.now().add(const Duration(minutes: 15));
    final colors = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String formatScheduleTime(DateTime dt) {
              final isToday = dt.day == DateTime.now().day &&
                  dt.month == DateTime.now().month &&
                  dt.year == DateTime.now().year;
              final hourStr = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              if (isToday) {
                return 'Hoje às $hourStr';
              }
              return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} às $hourStr';
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.schedule_send_rounded, color: colors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Enviar ou Agendar Mensagem',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mensagem:',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          text,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Atalhos rápidos para agendamento:',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('Em 5 min'),
                        onPressed: () {
                          setSheetState(() {
                            selectedTime = DateTime.now().add(const Duration(minutes: 5));
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('Em 15 min'),
                        onPressed: () {
                          setSheetState(() {
                            selectedTime = DateTime.now().add(const Duration(minutes: 15));
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.timer_outlined, size: 16),
                        label: const Text('Em 30 min'),
                        onPressed: () {
                          setSheetState(() {
                            selectedTime = DateTime.now().add(const Duration(minutes: 30));
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.hourglass_top_rounded, size: 16),
                        label: const Text('Em 1 hora'),
                        onPressed: () {
                          setSheetState(() {
                            selectedTime = DateTime.now().add(const Duration(hours: 1));
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                        label: const Text('Amanhã 09:00'),
                        onPressed: () {
                          final tomorrow = DateTime.now().add(const Duration(days: 1));
                          setSheetState(() {
                            selectedTime = DateTime(
                              tomorrow.year,
                              tomorrow.month,
                              tomorrow.day,
                              9,
                              0,
                            );
                          });
                        },
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                        label: const Text('Data personalizada...'),
                        onPressed: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: selectedTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (pickedDate != null && context.mounted) {
                            final pickedTime = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedTime),
                            );
                            if (pickedTime != null) {
                              setSheetState(() {
                                selectedTime = DateTime(
                                  pickedDate.year,
                                  pickedDate.month,
                                  pickedDate.day,
                                  pickedTime.hour,
                                  pickedTime.minute,
                                );
                              });
                            }
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.09),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: colors.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.event_available_rounded, color: colors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Horário de disparo: ${formatScheduleTime(selectedTime)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(bottomSheetContext);
                            unawaited(_sendMessage());
                          },
                          icon: const Icon(Icons.flash_on_rounded, size: 18),
                          label: const Text('Enviar Agora'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            final reply = _replyingTo;
                            final isComm = widget.conversation.isCommunity ||
                                widget.conversation.channels.isNotEmpty;
                            final ch = isComm ? _activeChannel : null;
                            final isViewOnce = _viewOnceMode;
                            final ephSeconds = _ephemeralTimerSeconds;
                            final replySender = reply != null
                                ? (reply.senderId == _user.currentUser.id
                                    ? 'Você'
                                    : _user.contactName(reply.senderId))
                                : null;

                            final scheduledMsg = ScheduledMessage(
                              id: 'sched_${DateTime.now().millisecondsSinceEpoch}',
                              conversationId: widget.conversation.id,
                              content: text,
                              scheduledFor: selectedTime,
                              createdAt: DateTime.now(),
                              replyToId: reply?.id,
                              replySnippet: reply?.content,
                              replySender: replySender,
                              channel: ch,
                              isViewOnce: isViewOnce,
                              ephemeralSeconds: ephSeconds,
                            );

                            await _scheduledService.scheduleMessage(scheduledMsg);

                            if (mounted) {
                              _messageController.clear();
                              setState(() {
                                _replyingTo = null;
                                _viewOnceMode = false;
                              });
                              if (_settings.settings.hapticFeedback) {
                                HapticFeedback.mediumImpact();
                              }
                              Navigator.pop(bottomSheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '🕒 Mensagem agendada para ${formatScheduleTime(selectedTime)}!',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: const Text('Agendar Envio'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showScheduledMessagesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final scheduled = _scheduledService.getMessagesForConversation(widget.conversation.id);
            final colors = Theme.of(context).colorScheme;

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, color: Colors.tealAccent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Mensagens Agendadas (${scheduled.length})',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (scheduled.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'Nenhuma mensagem agendada para esta conversa.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 340),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: scheduled.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = scheduled[i];
                          final time = item.scheduledFor;
                          final formattedTime =
                              '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')} às ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              item.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'Disparo previsto: $formattedTime',
                              style: const TextStyle(fontSize: 12, color: Colors.tealAccent),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.send_rounded, size: 20, color: Colors.tealAccent),
                                  tooltip: 'Enviar na hora agora',
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _dispatchScheduledMessage(item);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent),
                                  tooltip: 'Cancelar agendamento',
                                  onPressed: () async {
                                    await _scheduledService.cancelMessage(item.id);
                                    setSheetState(() {});
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildScheduledMessagesBar() {
    final scheduled = _scheduledService.getMessagesForConversation(widget.conversation.id);
    if (scheduled.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    final next = scheduled.first.scheduledFor;
    final nextStr = '${next.hour.toString().padLeft(2, '0')}:${next.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .12),
        border: Border(
          bottom: BorderSide(color: colors.primary.withValues(alpha: .25)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_send_rounded, size: 17, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${scheduled.length} mensagem(ns) agendada(s) • Próxima: $nextStr',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.primary,
              ),
            ),
          ),
          TextButton(
            onPressed: _showScheduledMessagesSheet,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Ver / Gerenciar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendVoiceMemo() async {
    if (_sending || _busy) return;
    setState(() => _sending = true);

    try {
      final now = DateTime.now();
      const duration = 12;
      const waveform = [0.3, 0.6, 0.9, 0.4, 0.7, 1.0, 0.5, 0.8, 0.4, 0.7, 0.9, 0.5];

      if (widget.conversation.isSavedMessages) {
        final id = '${now.millisecondsSinceEpoch}';
        final msg = DecryptedMessage(
          id: id,
          conversationId: widget.conversation.id,
          senderId: _user.currentUser.id,
          content: 'Nota de áudio (${duration}s)',
          sentAt: now,
          mediaType: 'audio',
          audioDurationSeconds: duration,
          audioWaveform: waveform,
        );
        setState(() => _messages.add(msg));
        _schedulePersistHistory();
      } else {
        final payload = jsonEncode({
          'nx_type': 'rich',
          'text': 'Nota de áudio (${duration}s)',
          'mediaType': 'audio',
          'audioDurationSeconds': duration,
          'audioWaveform': waveform,
        });
        await _connection.sendMessage(payload);
      }
    } on Object catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _toggleReaction(DecryptedMessage msg, String emoji) async {
    final msgId = int.tryParse(msg.id);
    if (msgId == null) return;
    final currentUserId = _user.currentUser.id;

    final currentReactions = Map<String, List<String>>.from(
      msg.reactions.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    final users = currentReactions[emoji] ?? [];
    if (users.contains(currentUserId)) {
      users.remove(currentUserId);
      if (users.isEmpty) {
        currentReactions.remove(emoji);
      } else {
        currentReactions[emoji] = users;
      }
    } else {
      users.add(currentUserId);
      currentReactions[emoji] = users;
    }

    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      setState(() {
        _messages[index] = msg.copyWith(reactions: currentReactions);
      });
      _schedulePersistHistory();
    }
    await _user.toggleMessageReaction(
      widget.conversation.id,
      msgId,
      emoji,
      currentUserId,
    );
  }

  Future<void> _togglePinMessage(DecryptedMessage msg) async {
    final msgId = int.tryParse(msg.id);
    if (msgId == null) return;

    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      setState(() {
        _messages[index] = msg.copyWith(isPinned: !msg.isPinned);
      });
      _schedulePersistHistory();
    }
    await _user.togglePinMessage(widget.conversation.id, msgId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isPinned ? 'Mensagem desafixada.' : 'Mensagem fixada no topo.'),
        ),
      );
    }
  }

  Future<void> _toggleStarMessage(DecryptedMessage msg) async {
    final msgId = int.tryParse(msg.id);
    if (msgId == null) return;

    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      setState(() {
        _messages[index] = msg.copyWith(isStarred: !msg.isStarred);
      });
      _schedulePersistHistory();
    }
    await _user.toggleStarMessage(widget.conversation.id, msgId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isStarred ? 'Removida dos favoritos.' : 'Mensagem salva com estrela!'),
        ),
      );
    }
  }

  void _showMessageActions(DecryptedMessage msg) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final emoji in MessageReactionsView.quickEmojis)
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _toggleReaction(msg, emoji);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(emoji, style: const TextStyle(fontSize: 24)),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply_rounded),
                title: const Text('Responder'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _replyingTo = msg);
                },
              ),
              ListTile(
                leading: Icon(msg.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined),
                title: Text(msg.isPinned ? 'Desafixar mensagem' : 'Fixar no topo'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _togglePinMessage(msg);
                },
              ),
              ListTile(
                leading: Icon(
                  msg.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: msg.isStarred ? Colors.amber : null,
                ),
                title: Text(msg.isStarred ? 'Remover estrela' : 'Favoritar mensagem'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _toggleStarMessage(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copiar texto'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await Clipboard.setData(ClipboardData(text: msg.content));
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mensagem copiada.')),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStarredMessagesDialog() {
    final starred = _messages.where((m) => m.isStarred).toList();
    final colors = Theme.of(context).colorScheme;

    showDialog<void>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star_rounded, color: Colors.amber, size: 22),
            SizedBox(width: 8),
            Text('Mensagens com Estrela'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: starred.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhuma mensagem com estrela nesta conversa.\nToque e segure em uma mensagem para favoritá-la.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.55,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: starred.length,
                    separatorBuilder: (_, _) => const Divider(),
                    itemBuilder: (ctx, idx) {
                      final m = starred[idx];
                      final isMe = m.senderId == _user.currentUser.id;
                      final senderName = isMe ? 'Você' : _user.contactName(m.senderId);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          senderName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.primary,
                          ),
                        ),
                        subtitle: Text(m.content),
                        trailing: IconButton(
                          icon: const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                          tooltip: 'Remover estrela',
                          onPressed: () {
                            _toggleStarMessage(m);
                            Navigator.pop(dlgCtx);
                          },
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChatDialog() async {
    final text = _user.exportConversationToText(widget.conversation.id);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.download_rounded, size: 22),
            SizedBox(width: 8),
            Text('Exportar Conversa'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'O backup textual da conversa inclui mensagens, remetentes e reações com data e hora.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    text,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup copiado para a área de transferência!')),
                );
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar Backup'),
          ),
        ],
      ),
    );
  }

  void _showSafetyNumbersDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => SafetyNumbersDialog(
        contactName: widget.conversationTitle,
        myPublicKey: _user.currentUser.publicKey,
        peerPublicKey: _connection.remotePublicKey,
        isVerified: widget.conversation.isSafetyVerified,
        onToggleVerified: (val) async {
          await _user.setSafetyVerified(widget.conversation.id, val);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _showContactNotesDialog() async {
    final controller = TextEditingController(
      text: widget.conversation.privateContactNotes ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.note_alt_outlined),
            const SizedBox(width: 8),
            Text('Anotações sobre ${widget.conversationTitle}'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Estas anotações são salvas somente neste dispositivo e nunca são transmitidas para o contato.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 4,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Ex: Colega de projeto cripto, mora em SP...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (saved == true && mounted) {
      await _user.setPrivateContactNotes(
        widget.conversation.id,
        controller.text.trim(),
      );
    }
  }

  Future<void> _showEphemeralTimerDialog() async {
    final options = [
      (0, 'Desativado'),
      (30, '30 segundos'),
      (300, '5 minutos'),
      (3600, '1 hora'),
      (86400, '24 horas'),
      (604800, '7 dias'),
    ];
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Mensagens efêmeras (Temporizador)'),
        children: options.map((opt) {
          final isCurr = (_ephemeralTimerSeconds ?? 0) == opt.$1;
          return SimpleDialogOption(
            onPressed: () => Navigator.pop(context, opt.$1),
            child: Row(
              children: [
                Icon(
                  isCurr ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: isCurr ? Theme.of(context).colorScheme.primary : null,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Text(opt.$2),
              ],
            ),
          );
        }).toList(),
      ),
    );
    if (selected != null && mounted) {
      final seconds = selected == 0 ? null : selected;
      setState(() => _ephemeralTimerSeconds = seconds);
      await _user.setEphemeralRetention(widget.conversation.id, seconds);
    }
  }

  void _showCommunityInfo() {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final conv = _user.conversations.where((c) => c.id == widget.conversation.id).firstOrNull ??
              widget.conversation;
          final channels = conv.channels.isNotEmpty ? conv.channels : ['geral'];
          final isOwner = conv.creatorId == _user.currentUser.id || conv.adminIds.contains(_user.currentUser.id);

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView(
                controller: scrollController,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header da Comunidade
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(Icons.hub_rounded, color: colors.primary, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              conv.title,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${conv.participantIds.length} membros na malha • ${channels.length} canais',
                              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (conv.description != null && conv.description!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        conv.description!,
                        style: TextStyle(color: colors.onSurfaceVariant, height: 1.4, fontSize: 13),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Divider(),

                  // Seção: Canais de Tópicos
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.tag_rounded, color: colors.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Canais de Tópicos (${channels.length})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          Navigator.pop(sheetCtx);
                          await _showAddChannelDialog();
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Novo Canal'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: channels.map((ch) {
                        final isActive = ch.toLowerCase() == _activeChannel.toLowerCase();
                        final isOnly = channels.length <= 1;

                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.tag_rounded,
                            size: 18,
                            color: isActive ? colors.primary : colors.onSurfaceVariant,
                          ),
                          title: Text(
                            '#$ch',
                            style: TextStyle(
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                              color: isActive ? colors.primary : null,
                            ),
                          ),
                          subtitle: isActive ? const Text('Canal ativo atualmente', style: TextStyle(fontSize: 11)) : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isActive)
                                TextButton(
                                  onPressed: () {
                                    setState(() => _activeChannel = ch);
                                    Navigator.pop(sheetCtx);
                                  },
                                  child: const Text('Entrar'),
                                ),
                              if (isOwner && !isOnly)
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                  tooltip: 'Excluir canal',
                                  onPressed: () async {
                                    final confirmed = await confirmAction(
                                      context,
                                      title: 'Excluir canal #$ch?',
                                      description: 'O canal #$ch será removido da comunidade.',
                                      action: 'Excluir',
                                    );
                                    if (confirmed) {
                                      await _user.removeChannelFromConversation(conv.id, ch);
                                      if (_activeChannel.toLowerCase() == ch.toLowerCase()) {
                                        setState(() => _activeChannel = 'geral');
                                      }
                                      setSheetState(() {});
                                    }
                                  },
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // Seção: Membros e Administradores
                  Row(
                    children: [
                      Icon(Icons.people_outline_rounded, color: colors.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Membros da Comunidade (${conv.participantIds.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colors.outlineVariant.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: conv.participantIds.map((key) {
                        final isMe = key == _user.currentUser.id;
                        final isCreator = conv.creatorId == key;
                        final isAdmin = conv.adminIds.contains(key);
                        final name = isMe ? 'Você' : _user.contactName(key);

                        return ListTile(
                          dense: true,
                          leading: CryptoAvatar(seedKey: key, title: name, size: 32),
                          title: Row(
                            children: [
                              Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              if (isCreator)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Criador', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                                )
                              else if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.teal.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Admin', style: TextStyle(fontSize: 10, color: Colors.tealAccent, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Text(AppTheme.formatKeyPreview(key), style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Divider(),

                  // Ações de Convite e Limpeza
                  ListTile(
                    leading: const Icon(Icons.qr_code_2_rounded, color: Colors.tealAccent),
                    title: const Text('Convite Criptografado da Comunidade'),
                    subtitle: const Text('Exibir QR Code e código assinado para convidar membros'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      try {
                        final code = await GroupInvitationService.export(conv, _user);
                        if (!context.mounted) return;
                        showDialog<void>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('Convite: ${conv.title}'),
                            content: SizedBox(
                              width: 320,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: CustomPaint(
                                      size: const Size(190, 190),
                                      painter: QrCodePainter(data: code, color: Colors.black),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Compartilhe este convite assinado para permitir entrada nesta comunidade P2P:',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: code));
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Convite copiado para a área de transferência!')),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 16),
                                label: const Text('Copiar Código'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Fechar'),
                              ),
                            ],
                          ),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Não foi possível gerar o convite.')),
                        );
                      }
                    },
                  ),
                  SwitchListTile(
                    secondary: Icon(conv.isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined),
                    title: const Text('Silenciar Notificações desta Comunidade'),
                    subtitle: const Text('Desativar avisos sonoros e notificações de mensagens'),
                    value: conv.isMuted,
                    onChanged: (val) async {
                      await _user.toggleMuteConversation(conv.id);
                      setSheetState(() {});
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: Colors.amber),
                    title: const Text('Limpar Mensagens Locais'),
                    subtitle: const Text('Apaga todas as mensagens salvas de todos os canais deste aparelho'),
                    onTap: () async {
                      final confirmed = await confirmAction(
                        context,
                        title: 'Limpar histórico local?',
                        description: 'Todas as mensagens dos canais desta comunidade serão apagadas do seu aparelho.',
                        action: 'Limpar',
                      );
                      if (confirmed) {
                        await _user.clearCommunityMessages(conv.id);
                        setState(() {
                          _messages.clear();
                        });
                        setSheetState(() {});
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAddChannelDialog() async {
    final controller = TextEditingController();
    final form = GlobalKey<FormState>();
    final added = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Novo canal de tópico'),
        content: Form(
          key: form,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
              labelText: 'Nome do canal',
              hintText: 'ex: anuncios, projetos, fotos',
              prefixText: '#',
            ),
            validator: (v) => v == null || v.trim().isEmpty ? 'Informe o nome.' : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Criar canal'),
          ),
        ],
      ),
    );
    if (added == true && mounted) {
      final name = controller.text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');
      await _user.addChannelToConversation(widget.conversation.id, name);
      setState(() => _activeChannel = name);
    }
  }

  Future<void> _showCreatePollDialog() async {
    final questionCtrl = TextEditingController();
    final opt1Ctrl = TextEditingController();
    final opt2Ctrl = TextEditingController();
    final opt3Ctrl = TextEditingController();
    final form = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.poll_rounded),
            SizedBox(width: 8),
            Text('Criar Enquete P2P'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: questionCtrl,
                    decoration: const InputDecoration(labelText: 'Pergunta da enquete'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Informe a pergunta' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: opt1Ctrl,
                    decoration: const InputDecoration(labelText: 'Opção 1'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Opção 1 obrigatória' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: opt2Ctrl,
                    decoration: const InputDecoration(labelText: 'Opção 2'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Opção 2 obrigatória' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: opt3Ctrl,
                    decoration: const InputDecoration(labelText: 'Opção 3 (opcional)'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, true);
            },
            child: const Text('Publicar enquete'),
          ),
        ],
      ),
    );
    if (created == true && mounted) {
      final opts = [opt1Ctrl.text.trim(), opt2Ctrl.text.trim()];
      if (opt3Ctrl.text.trim().isNotEmpty) opts.add(opt3Ctrl.text.trim());
      await _sendPoll(questionCtrl.text.trim(), opts);
    }
  }

  Future<void> _sendPoll(String question, List<String> options) async {
    final now = DateTime.now();
    final isComm = widget.conversation.isCommunity || widget.conversation.channels.isNotEmpty;
    final ch = isComm ? _activeChannel : null;

    if (widget.conversation.isSavedMessages) {
      final id = '${now.millisecondsSinceEpoch}';
      final msg = DecryptedMessage(
        id: id,
        conversationId: widget.conversation.id,
        senderId: _user.currentUser.id,
        content: '📊 Enquete: $question',
        sentAt: now,
        mediaType: 'poll',
        pollQuestion: question,
        pollOptions: options,
        pollVotes: const {},
        channel: ch,
      );
      setState(() => _messages.add(msg));
      _schedulePersistHistory();
    } else {
      final payload = jsonEncode({
        'nx_type': 'rich',
        'text': '📊 Enquete: $question',
        'mediaType': 'poll',
        'pollQuestion': question,
        'pollOptions': options,
        'pollVotes': <String, List<String>>{},
        if (ch != null) 'channel': ch,
      });
      await _connection.sendMessage(payload);
    }
  }

  Future<void> _votePoll(DecryptedMessage msg, int optionIndex) async {
    final msgId = int.tryParse(msg.id);
    if (msgId == null) return;
    final currentUserId = _user.currentUser.id;

    final currentVotes = Map<String, List<String>>.from(
      msg.pollVotes.map((k, v) => MapEntry(k, List<String>.from(v))),
    );
    for (final k in currentVotes.keys.toList()) {
      currentVotes[k]?.remove(currentUserId);
    }
    final key = optionIndex.toString();
    final list = currentVotes[key] ?? [];
    list.add(currentUserId);
    currentVotes[key] = list;

    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      setState(() {
        _messages[index] = msg.copyWith(pollVotes: currentVotes);
      });
      _schedulePersistHistory();
    }
    await _user.votePoll(widget.conversation.id, msgId, optionIndex, currentUserId);
  }

  Future<void> _markViewOnceAsViewed(DecryptedMessage msg) async {
    final msgId = int.tryParse(msg.id);
    if (msgId == null) return;
    final now = DateTime.now();
    final index = _messages.indexWhere((m) => m.id == msg.id);
    if (index != -1) {
      setState(() {
        _messages[index] = msg.copyWith(viewedAt: now);
      });
      _schedulePersistHistory();
    }
    await _user.markViewOnceAsViewed(widget.conversation.id, msgId);
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Não foi possível concluir a operação. Verifique a conexão ou permissões de mídia e tente novamente.',
        ),
      ),
    );
  }

  String get _statusLabel => widget.conversation.isSavedMessages
      ? 'Cofre pessoal seguro'
      : widget.conversation.isGroup
      ? '${_connection.connectedCount}/${_connection.peerKeys.length} participantes conectados'
      : _isBlocked
      ? 'Contato bloqueado'
      : switch (_connection.status) {
          P2PConnectionStatus.disconnected => 'Desconectado',
          P2PConnectionStatus.negotiating => 'Preparando sessão segura...',
          P2PConnectionStatus.waitingForAnswer =>
            'Aguardando resposta do convite',
          P2PConnectionStatus.connecting => 'Estabelecendo túnel P2P...',
          P2PConnectionStatus.connected => 'Conectado • Ponta a ponta (E2EE)',
          P2PConnectionStatus.failed => 'Conexão encerrada ou falhou',
        };

  Color _statusDotColor(ColorScheme colors) {
    if (widget.conversation.isSavedMessages) return const Color(0xFF36D399);
    if (_isBlocked) return colors.error;
    if (_connection.hasConnectedPeers) return const Color(0xFF36D399);
    return switch (_connection.status) {
      P2PConnectionStatus.negotiating ||
      P2PConnectionStatus.waitingForAnswer ||
      P2PConnectionStatus.connecting => const Color(0xFFFFC857),
      P2PConnectionStatus.failed => colors.error,
      _ => colors.outline,
    };
  }

  String _formatDayHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = today.difference(target).inDays;
    if (diff == 0) return 'Hoje';
    if (diff == 1) return 'Ontem';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final title = _user.conversationName(widget.conversation);
    final visible = _query.isEmpty
        ? _messages
        : _messages
              .where((m) => m.content.toLowerCase().contains(_query))
              .toList(growable: false);
    final canCall = _connection.canStartCall && !_busy && !_isBlocked;
    final canScreenShare =
        _connection.hasConnectedPeers &&
        !_busy &&
        !_isBlocked &&
        (!_connection.isInCall ||
            _connection.callState == P2PCallState.active);

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          leading: widget.isTabMode
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  tooltip: 'Voltar ao Início',
                  onPressed: () => ConversationTabsService.instance.openHome(),
                )
              : null,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Divider(height: 1, color: colors.outlineVariant),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: widget.conversation.isSavedMessages
                    ? Icon(
                        Icons.bookmark_rounded,
                        size: 20,
                        color: colors.onPrimaryContainer,
                      )
                    : (widget.conversation.isGroup
                        ? Icon(
                            Icons.groups_rounded,
                            size: 20,
                            color: colors.onPrimaryContainer,
                          )
                        : Text(
                            title.isEmpty
                                ? '?'
                                : title.substring(0, 1).toUpperCase(),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onPrimaryContainer,
                            ),
                          )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!widget.conversation.isGroup &&
                            widget.conversation.isSafetyVerified) ...[
                          const SizedBox(width: 4),
                          const Tooltip(
                            message: 'Criptografia verificada',
                            child: Icon(
                              Icons.verified_user_rounded,
                              color: Colors.green,
                              size: 16,
                            ),
                          ),
                        ],
                        if (widget.conversation.isCommunity) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: .18),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'COMUNIDADE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: _statusDotColor(colors),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: (widget.conversation.isSavedMessages ||
                                      _connection.hasConnectedPeers)
                                  ? colors.primary
                                  : colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (!widget.conversation.isSavedMessages) ...[
              IconButton(
                icon: const Icon(Icons.call_outlined),
                tooltip: canCall
                    ? 'Iniciar ligação de voz P2P'
                    : 'Conecte-se para ligar por voz',
                onPressed: canCall ? () => _startCall(video: false) : null,
              ),
              IconButton(
                icon: const Icon(Icons.videocam_outlined),
                tooltip: canCall
                    ? 'Iniciar videochamada P2P'
                    : 'Conecte-se para iniciar videochamada',
                onPressed: canCall ? () => _startCall(video: true) : null,
              ),
              IconButton(
                icon: Icon(
                  _connection.isScreenSharing
                      ? Icons.stop_screen_share_outlined
                      : Icons.screen_share_outlined,
                  color: _connection.isScreenSharing ? colors.primary : null,
                ),
                tooltip: canScreenShare
                    ? (_connection.isScreenSharing
                          ? 'Parar transmissão de tela'
                          : 'Transmitir tela P2P')
                    : 'Conecte-se para transmitir sua tela',
                onPressed: canScreenShare ? _startOrToggleScreenShare : null,
              ),
            ],
            IconButton(
              icon: Icon(
                _searching ? Icons.search_off_rounded : Icons.search_rounded,
              ),
              tooltip: 'Buscar mensagens locais',
              onPressed: () => setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              }),
            ),
            if (!widget.conversation.isSavedMessages)
              IconButton(
                icon: Badge(
                  isLabelVisible: !_connection.isConnected,
                  smallSize: 7,
                  backgroundColor: colors.primary,
                  child: Icon(
                    _showConnection ? Icons.hub_rounded : Icons.hub_outlined,
                  ),
                ),
                tooltip: 'Assistente de conexão P2P',
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
                } else if (value == 'starred') {
                  _showStarredMessagesDialog();
                } else if (value == 'export') {
                  unawaited(_exportChatDialog());
                } else if (value == 'safety') {
                  _showSafetyNumbersDialog();
                } else if (value == 'notes') {
                  unawaited(_showContactNotesDialog());
                } else if (value == 'ephemeral') {
                  unawaited(_showEphemeralTimerDialog());
                } else if (value == 'comm_info') {
                  _showCommunityInfo();
                } else if (value == 'add_channel') {
                  unawaited(_showAddChannelDialog());
                } else if (value == 'poll') {
                  unawaited(_showCreatePollDialog());
                } else {
                  unawaited(_runConnectionAction(_connection.disconnect));
                }
              },
              itemBuilder: (_) => [
                if (!widget.conversation.isGroup && !widget.conversation.isSavedMessages) ...[
                  const PopupMenuItem(
                    value: 'safety',
                    child: Row(
                      children: [
                        Icon(Icons.verified_user_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Verificação de segurança (60 dígitos)'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'notes',
                    child: Row(
                      children: [
                        Icon(Icons.note_alt_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Anotações privadas do contato'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'ephemeral',
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Mensagens efêmeras (Timer)'),
                      ],
                    ),
                  ),
                ],
                if (widget.conversation.isCommunity ||
                    widget.conversation.channels.isNotEmpty) ...[
                  const PopupMenuItem(
                    value: 'comm_info',
                    child: Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 18, color: Colors.tealAccent),
                        SizedBox(width: 10),
                        Text('Opções da comunidade', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_channel',
                    child: Row(
                      children: [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 10),
                        Text('Criar novo canal de tópico'),
                      ],
                    ),
                  ),
                ],
                if (widget.conversation.isGroup ||
                    widget.conversation.isCommunity)
                  const PopupMenuItem(
                    value: 'poll',
                    child: Row(
                      children: [
                        Icon(Icons.poll_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Criar enquete P2P'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'starred',
                  child: Row(
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                      SizedBox(width: 10),
                      Text('Mensagens com estrela'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'export',
                  child: Row(
                    children: [
                      Icon(Icons.download_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Exportar conversa'),
                    ],
                  ),
                ),
                if (!widget.conversation.isSavedMessages)
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
                if (!widget.conversation.isSavedMessages)
                  PopupMenuItem(
                    value: 'disconnect',
                    enabled: !_busy,
                    child: const Text('Desconectar sessão'),
                  ),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: PageFrame(
            maxWidth: 960,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pinned = _messages.where((m) => m.isPinned).toList();
                final isComm = widget.conversation.isCommunity ||
                    widget.conversation.channels.isNotEmpty;
                final visible = _messages.where((m) {
                  if (isComm) {
                    final mChan = (m.channel ?? 'geral').toLowerCase();
                    if (mChan != _activeChannel.toLowerCase()) return false;
                  }
                  if (_query.isNotEmpty &&
                      !m.content.toLowerCase().contains(_query)) {
                    return false;
                  }
                  return true;
                }).toList();

                return Column(
                  children: [
                    if (isComm)
                      CommunityChannelsBar(
                        channels: widget.conversation.channels,
                        activeChannel: _activeChannel,
                        onSelectChannel: (ch) =>
                            setState(() => _activeChannel = ch),
                        onAddChannel: _showAddChannelDialog,
                        onShowInfo: _showCommunityInfo,
                      ),
                    if (_connection.isInCall && !widget.conversation.isSavedMessages)
                      CallPanel(
                        connection: _connection,
                        peerName: _user.contactName(_connection.callPeerKey),
                        onError: _showError,
                      ),
                    if (_showConnection && !widget.conversation.isSavedMessages)
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .48,
                        ),
                        child: SingleChildScrollView(
                          child: ConnectionAssistantCard(
                            connection: _connection,
                            userService: _user,
                            signalingController: _signalingController,
                            isGroup: widget.conversation.isGroup,
                            busy: _busy,
                            isBlocked: _isBlocked,
                            obscureSignaling: _obscureSignaling,
                            onToggleObscure: () => setState(
                              () => _obscureSignaling = !_obscureSignaling,
                            ),
                            onHidePanel: () =>
                                setState(() => _showConnection = false),
                            onPeerChanged: (key) {
                              _signalingController.clear();
                              _connection.selectPeer(key);
                              _contactChanged();
                            },
                            onSignalingTextChanged: (_) => setState(() {}),
                            onPasteSignaling: _pasteSignalingData,
                            onCreateOffer: _createOffer,
                            onAcceptOffer: _acceptOffer,
                            onAcceptAnswer: _acceptAnswer,
                            onCopySignaling: _copySignalingData,
                          ),
                        ),
                      ),
                    if (_settings.settings.showSecurityInspector &&
                        !widget.conversation.isSavedMessages)
                      SecurityHud(
                        connection: _connection,
                        isGroup: widget.conversation.isGroup,
                        localUserId: _user.currentUser.id,
                        peerName: widget.conversationTitle,
                      ),
                    if (pinned.isNotEmpty)
                      PinnedMessagesBar(
                        pinnedText: pinned.last.content,
                        authorName: pinned.last.senderId == _user.currentUser.id
                            ? 'Você'
                            : _user.contactName(pinned.last.senderId),
                        count: pinned.length,
                        onTap: () {
                          final idx = visible.indexWhere((m) => m.id == pinned.last.id);
                          if (idx != -1 && _scrollController.hasClients) {
                            _scrollController.animateTo(
                              (idx * 65.0).clamp(0, _scrollController.position.maxScrollExtent),
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                        onUnpin: () => _togglePinMessage(pinned.last),
                      ),
                    if (_searching)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: TextField(
                          autofocus: true,
                          decoration: const InputDecoration(
                            hintText: 'Filtrar mensagens nesta conversa',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                          onChanged: (value) =>
                              setState(() => _query = value.trim().toLowerCase()),
                        ),
                      ),
                    Expanded(
                      child: ChatWallpaperBackground(
                        wallpaperStyle: _settings.settings.chatWallpaper,
                        child: _buildMessages(constraints, visible),
                      ),
                    ),
                    _buildComposer(),
                  ],
                );
              },
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
    if (visible.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isBlocked
                        ? Icons.block_rounded
                        : (widget.conversation.isSavedMessages
                            ? Icons.bookmark_rounded
                            : Icons.shield_outlined),
                    color: colors.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _query.isNotEmpty
                      ? 'Nenhuma mensagem encontrada'
                      : _isBlocked
                      ? 'Contato bloqueado'
                      : widget.conversation.isSavedMessages
                      ? 'Mensagens Salvas'
                      : 'Canal P2P Criptografado',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isBlocked
                      ? 'Desbloqueie nas configurações para conversar.'
                      : _query.isNotEmpty
                      ? 'Tente outro termo de busca.'
                      : widget.conversation.isSavedMessages
                      ? 'Guarde notas, ideias, links e lembretes aqui para consultá-los com privacidade neste dispositivo.'
                      : _connection.hasConnectedPeers
                      ? 'Túnel ativo! Envie mensagens, arquivos ou inicie voz, vídeo ou transmissão de tela no topo.'
                      : 'Use o assistente acima para trocar o convite e a resposta com os participantes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final message = visible[index];
        final local = message.senderId == _user.currentUser.id;
        final time = message.sentAt.toLocal();
        final prevTime = index > 0 ? visible[index - 1].sentAt.toLocal() : null;
        final showDateHeader =
            prevTime == null ||
            prevTime.year != time.year ||
            prevTime.month != time.month ||
            prevTime.day != time.day;

        final isCompact = _settings.settings.layoutDensity == 'compact';
        final bubbleStyle = _settings.settings.chatBubbleStyle;
        final bubbleBorderRadius = switch (bubbleStyle) {
          'minimal' => BorderRadius.circular(8),
          'bubble' => BorderRadius.only(
              topLeft: const Radius.circular(22),
              topRight: const Radius.circular(22),
              bottomLeft: Radius.circular(local ? 22 : 3),
              bottomRight: Radius.circular(local ? 3 : 22),
            ),
          _ => BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(local ? 18 : 4),
              bottomRight: Radius.circular(local ? 4 : 18),
            ),
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateHeader)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: .65,
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _formatDayHeader(time),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: local ? Alignment.centerRight : Alignment.centerLeft,
              child: GestureDetector(
                onLongPress: () => _showMessageActions(message),
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: (constraints.maxWidth * .80)
                        .clamp(180, 620)
                        .toDouble(),
                  ),
                  margin: EdgeInsets.only(bottom: isCompact ? 6 : 10),
                  padding: EdgeInsets.fromLTRB(15, isCompact ? 8 : 11, 15, isCompact ? 7 : 9),
                  decoration: BoxDecoration(
                    color: local ? colors.primaryContainer : colors.surface,
                    border: Border.all(
                      color: local
                          ? colors.primary.withValues(alpha: .28)
                          : colors.outlineVariant,
                    ),
                    borderRadius: bubbleBorderRadius,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.conversation.isGroup && !local)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            _user.contactName(message.senderId),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      if (message.replySnippet != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: ReplySnippetWidget(
                            senderName: message.replySender ?? 'Mensagem',
                            snippet: message.replySnippet!,
                            isEmbedded: true,
                          ),
                        ),
                      if (message.isViewOnce)
                        ViewOnceBubble(
                          content: message.content,
                          isLocal: local,
                          viewedAt: message.viewedAt,
                          onOpen: () => _markViewOnceAsViewed(message),
                        )
                      else if (message.mediaType == 'poll' &&
                          message.pollQuestion != null)
                        PollWidget(
                          question: message.pollQuestion!,
                          options: message.pollOptions ?? const [],
                          votes: message.pollVotes,
                          currentUserId: _user.currentUser.id,
                          isLocal: local,
                          onVote: (idx) => _votePoll(message, idx),
                        )
                      else if (message.mediaType == 'audio')
                        VoiceMessageBubble(
                          durationSeconds: message.audioDurationSeconds ?? 12,
                          waveform: message.audioWaveform,
                          isLocal: local,
                        )
                      else
                        StealthBlur(
                          enabled: _settings.settings.stealthMode,
                          child: SelectableText(
                            message.content,
                            style: TextStyle(
                              color: local
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                              height: 1.45,
                            ),
                          ),
                        ),
                      if (message.reactions.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: MessageReactionsView(
                            reactions: message.reactions,
                            currentUserId: _user.currentUser.id,
                            onReactionTap: (emoji) => _toggleReaction(message, emoji),
                          ),
                        ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (message.ephemeralSeconds != null) ...[
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 11.5,
                              color: Colors.amber.shade700,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${message.ephemeralSeconds}s',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.amber.shade700,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (message.isStarred) ...[
                            const Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (message.isPinned) ...[
                            Icon(
                              Icons.push_pin_rounded,
                              size: 11,
                              color: local
                                  ? colors.onPrimaryContainer.withValues(alpha: .75)
                                  : colors.primary,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (_settings.settings.showTimestamps) ...[
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 10.5,
                              color: local
                                  ? colors.onPrimaryContainer.withValues(alpha: .65)
                                  : colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: local
                                    ? colors.onPrimaryContainer.withValues(
                                        alpha: .72,
                                      )
                                    : colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildComposer() {
    final colors = Theme.of(context).colorScheme;
    final canSend = (widget.conversation.isSavedMessages || _connection.canSend) &&
        !_busy &&
        !_isBlocked;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.outlineVariant.withValues(alpha: .6)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildScheduledMessagesBar(),
          if (_viewOnceMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: Colors.amber.withValues(alpha: .15),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.amber),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Visualização Única: a mensagem será destruída após 15s de abertura.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.amber,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _viewOnceMode = false),
                  ),
                ],
              ),
            ),
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              color: colors.surfaceContainerHighest.withValues(alpha: .3),
              child: ReplySnippetWidget(
                senderName: _replyingTo!.senderId == _user.currentUser.id
                    ? 'Você'
                    : _user.contactName(_replyingTo!.senderId),
                snippet: _replyingTo!.content,
                onCancel: () => setState(() => _replyingTo = null),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            decoration: BoxDecoration(
              color: colors.surface,
              border: Border(
                top: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!widget.conversation.isSavedMessages) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: canSend && !_sendingFile ? _sendFile : null,
                    icon: _sendingFile
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded, size: 22),
                    tooltip: 'Enviar arquivo P2P',
                  ),
                ],
                if (!widget.conversation.isGroup && !widget.conversation.isSavedMessages) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _viewOnceMode = !_viewOnceMode),
                    icon: Icon(
                      _viewOnceMode
                          ? Icons.local_fire_department_rounded
                          : Icons.local_fire_department_outlined,
                      size: 22,
                      color: _viewOnceMode ? Colors.amber : null,
                    ),
                    tooltip: 'Visualização única',
                  ),
                ],
                if (widget.conversation.isGroup || widget.conversation.isCommunity) ...[
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: canSend ? _showCreatePollDialog : null,
                    icon: const Icon(Icons.poll_outlined, size: 22),
                    tooltip: 'Criar enquete',
                  ),
                ],
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canSend && !_sending ? _sendVoiceMemo : null,
                  icon: const Icon(Icons.mic_rounded, size: 22),
                  tooltip: 'Gravar áudio',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    child: TextField(
                      controller: _messageController,
                      enabled: canSend,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 16000,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: _settings.settings.enterIsSend
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      style: const TextStyle(fontSize: 14.5),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        hintText: widget.conversation.isSavedMessages
                            ? 'Escreva uma nota no cofre...'
                            : (_connection.canSend
                                ? 'Mensagem criptografada...'
                                : 'Conecte-se para enviar'),
                        counterText: '',
                      ),
                      onSubmitted: (_) {
                        if (canSend && _settings.settings.enterIsSend) {
                          unawaited(_sendMessage());
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: canSend ? _showScheduleSendDialog : null,
                  icon: const Icon(Icons.schedule_send_rounded, size: 22),
                  tooltip: 'Agendar mensagem',
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onLongPress: canSend ? _showScheduleSendDialog : null,
                  child: Material(
                    color: canSend && !_sending
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    shape: const CircleBorder(),
                    elevation: canSend && !_sending ? 2 : 0,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend && !_sending ? _sendMessage : null,
                      child: Padding(
                        padding: const EdgeInsets.all(11),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          size: 20,
                          color: canSend && !_sending
                              ? colors.onPrimary
                              : colors.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
