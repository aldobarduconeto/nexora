import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nexora/src/models/conversation.dart';
import 'package:nexora/src/services/file_transfer_service.dart';
import 'package:nexora/src/services/message_service.dart';
import 'package:nexora/src/services/notification_service.dart';
import 'package:nexora/src/services/p2p_connection_service.dart';

/// A group is a full mesh: no participant forwards another author's messages.
/// Supports all features (encrypted chat, file transfer, voice/video calls, and screen sharing)
/// across both 1:1 and multi-peer group conversations.
class ConversationConnectionService extends ChangeNotifier {
  ConversationConnectionService({
    required this.conversation,
    required this.localUserId,
    required int connectionTimeoutSeconds,
    void Function(String)? onNotice,
    P2PConnectionService Function(String key)? createPeer,
  }) : _membership =
           (List<String>.from(conversation.participantIds)..sort()).join(',') {
    for (final key in conversation.participantIds.where(
      (id) => id != localUserId,
    )) {
      final peer =
          createPeer?.call(key) ??
          P2PConnectionService(
            conversationId: conversation.id,
            localUserId: localUserId,
            remotePublicKey: key,
            connectionTimeoutSeconds: connectionTimeoutSeconds,
          );
      _peers[key] = peer;
      _fileTransfers[key] = FileTransferService(
        send: peer.sendMessage,
        notice: onNotice ?? (_) {},
      );
      peer.addListener(_changed);
      _subscriptions.add(
        peer.messages.listen(
          (message) => _receive(key, message),
          onError: _messages.addError,
        ),
      );
    }
    _selected = _peers.keys.isNotEmpty ? _peers.keys.first : '';
    _focusedCallPeer = _selected;
  }

  final Conversation conversation;
  final String localUserId;
  final String _membership;
  final _peers = <String, P2PConnectionService>{};
  final _fileTransfers = <String, FileTransferService>{};
  final _subscriptions = <StreamSubscription<DecryptedMessage>>[];
  final _messages = StreamController<DecryptedMessage>.broadcast();
  late String _selected;
  late String _focusedCallPeer;
  int _id = DateTime.now().microsecondsSinceEpoch;
  bool _closed = false;
  static const _prefix = 'NEXORA_GROUP_V1:';
  static const _filePrefix = 'NEXORA_FILE_V1:';

  Stream<DecryptedMessage> get messages => _messages.stream;
  String get remotePublicKey => _selected;
  List<String> get peerKeys => _peers.keys.toList(growable: false);
  P2PConnectionService? get _peer => _peers[_selected];
  P2PConnectionService peerService(String key) => _peers[key]!;

  List<String> get activeCallPeerKeys => _peers.entries
      .where((e) => e.value.isInCall)
      .map((e) => e.key)
      .toList(growable: false);

  P2PConnectionService? get _callPeer {
    // Prefer an incoming call first so the user is alerted immediately
    for (final peer in _peers.values) {
      if (peer.callState == P2PCallState.incoming) return peer;
    }
    final focused = _peers[_focusedCallPeer];
    if (focused != null && focused.isInCall) return focused;
    for (final peer in _peers.values) {
      if (peer.isInCall) return peer;
    }
    return _peer;
  }

  String get callPeerKey => _callPeer?.remotePublicKey ?? '';
  P2PCallState get callState => _callPeer?.callState ?? P2PCallState.idle;
  bool get isInCall => _peers.values.any((peer) => peer.isInCall);
  bool get isVideoCall => _peers.values.any((peer) => peer.isVideoCall);
  bool get isAudioMuted => _callPeer?.isAudioMuted ?? false;
  bool get isVideoEnabled => _callPeer?.isVideoEnabled ?? false;
  bool get isScreenSharing => _peers.values.any((peer) => peer.isScreenSharing);
  bool get isRemoteVideoEnabled => _callPeer?.isRemoteVideoEnabled ?? false;
  bool get isRemoteAudioMuted => _callPeer?.isRemoteAudioMuted ?? false;
  bool get isRemoteScreenSharing => _callPeer?.isRemoteScreenSharing ?? false;
  bool get isSpeakerphoneOn => _callPeer?.isSpeakerphoneOn ?? false;
  DateTime? get callConnectedAt => _callPeer?.callConnectedAt;
  MediaStream? get localStream => _callPeer?.localStream;
  MediaStream? get remoteStream => _callPeer?.remoteStream;
  VideoStreamPreset get currentVideoPreset =>
      _callPeer?.currentVideoPreset ?? VideoStreamPreset.ultra4k60;
  VideoStreamPreset get remoteVideoPreset =>
      _callPeer?.remoteVideoPreset ?? VideoStreamPreset.ultra4k60;
  bool get canStartCall => hasConnectedPeers && !isInCall;

  int get connectedCount =>
      _peers.values.where((peer) => peer.isConnected).length;
  bool get hasConnectedPeers => _peers.values.any((peer) => peer.isConnected);
  bool get isConnected =>
      _peers.isNotEmpty && _peers.values.every((peer) => peer.isConnected);
  bool get canSend => conversation.isSavedMessages
      ? true
      : (conversation.isGroup ? hasConnectedPeers : isConnected);
  bool get canApplyAnswer => _peer?.canApplyAnswer ?? false;
  P2PConnectionStatus get status {
    if (conversation.isSavedMessages) {
      return P2PConnectionStatus.connected;
    }
    if (_peers.isEmpty) {
      return P2PConnectionStatus.disconnected;
    }
    if (conversation.isGroup && connectedCount > 0 && !isConnected) {
      return P2PConnectionStatus.connected;
    }
    return _peer?.status ?? P2PConnectionStatus.disconnected;
  }
  bool peerConnected(String key) => _peers[key]?.isConnected ?? false;

  void selectPeer(String key) {
    if (!_peers.containsKey(key)) throw ArgumentError('Participante inválido.');
    _selected = key;
    notifyListeners();
  }

  void selectCallPeer(String key) {
    if (!_peers.containsKey(key)) return;
    _focusedCallPeer = key;
    notifyListeners();
  }

  bool _wasInIncomingCall = false;

  void _changed() {
    if (!_closed) {
      final hasIncoming =
          _peers.values.any((p) => p.callState == P2PCallState.incoming);
      if (hasIncoming && !_wasInIncomingCall) {
        _wasInIncomingCall = true;
        unawaited(
          NotificationService.instance.notifyIncomingCall(
            callerName: conversation.title,
            conversationId: conversation.id,
            isVideo: isVideoCall,
          ),
        );
      } else if (!hasIncoming) {
        _wasInIncomingCall = false;
      }
      notifyListeners();
    }
  }

  Future<String> createOffer() {
    final p = _peer;
    if (p == null) throw StateError('Nenhum participante conectado.');
    return p.createOffer();
  }
  Future<String> acceptOffer(String text) {
    final p = _peer;
    if (p == null) throw StateError('Nenhum participante conectado.');
    return p.acceptOffer(text);
  }
  Future<void> acceptAnswer(String text) {
    final p = _peer;
    if (p == null) throw StateError('Nenhum participante conectado.');
    return p.acceptAnswer(text);
  }

  Future<void> pickAndSendFile() async {
    final targets = _peers.entries
        .where((e) => e.value.isConnected)
        .map((e) => _fileTransfers[e.key]!)
        .toList(growable: false);
    if (targets.isEmpty) {
      throw StateError('Conecte-se a pelo menos um participante antes de enviar arquivos.');
    }
    await FileTransferService.pickAndSendToTargets(targets);
  }

  Future<void> abortFiles() =>
      Future.wait(_fileTransfers.values.map((f) => f.abort()));

  Future<void> startCall({
    bool audio = true,
    required bool video,
    bool screenShare = false,
    DesktopCapturerSource? screenSource,
    VideoStreamPreset? preset,
  }) async {
    final connected = _peers.values
        .where((p) => p.isConnected && !p.isInCall)
        .toList(growable: false);
    if (connected.isEmpty) {
      throw StateError('Conecte-se a pelo menos um participante antes de ligar.');
    }
    _focusedCallPeer = connected.first.remotePublicKey;
    await Future.wait(
      connected.map(
        (peer) => peer.startCall(
          audio: audio,
          video: video,
          screenShare: screenShare,
          screenSource: screenSource,
          preset: preset,
        ),
      ),
    );
  }

  Future<void> acceptCall({
    bool withAudio = true,
    bool? withVideo,
    VideoStreamPreset? preset,
  }) async {
    final incoming = _peers.values
        .where((p) => p.callState == P2PCallState.incoming)
        .toList(growable: false);
    if (incoming.isEmpty) {
      await _callPeer?.acceptCall(
        withAudio: withAudio,
        withVideo: withVideo,
        preset: preset,
      );
      return;
    }
    _focusedCallPeer = incoming.first.remotePublicKey;
    await Future.wait(
      incoming.map(
        (peer) => peer.acceptCall(
          withAudio: withAudio,
          withVideo: withVideo,
          preset: preset,
        ),
      ),
    );
  }

  Future<void> setVideoQuality(VideoStreamPreset preset) => Future.wait(
    _peers.values
        .where((p) => p.isInCall)
        .map((p) => p.setVideoQuality(preset)),
  );

  Future<void> rejectCall() async {
    final targets = _peers.values
        .where((p) => p.callState == P2PCallState.incoming)
        .toList(growable: false);
    if (targets.isEmpty) {
      await _callPeer?.rejectCall();
      return;
    }
    await Future.wait(targets.map((p) => p.rejectCall()));
  }

  Future<void> endCall() => Future.wait(
    _peers.values.where((p) => p.isInCall).map((p) => p.endCall()),
  );

  Future<void> toggleMute() => Future.wait(
    _peers.values.where((p) => p.isInCall).map((p) => p.toggleMute()),
  );

  Future<void> toggleVideo() => Future.wait(
    _peers.values.where((p) => p.isInCall).map((p) => p.toggleVideo()),
  );

  Future<void> toggleScreenShare({DesktopCapturerSource? source}) =>
      Future.wait(
        _peers.values
            .where((p) => p.isInCall)
            .map((p) => p.toggleScreenShare(source: source)),
      );

  Future<void> stopScreenShare() => Future.wait(
    _peers.values.where((p) => p.isInCall).map((p) => p.stopScreenShare()),
  );

  Future<void> switchCamera() => Future.wait(
    _peers.values.where((p) => p.isInCall).map((p) => p.switchCamera()),
  );

  Future<void> toggleSpeakerphone() async {
    await _callPeer?.toggleSpeakerphone();
  }

  void _emit(String sender, String content, DateTime sentAt, {DecryptedMessage? original}) {
    if (!_closed) {
      if (original != null) {
        _messages.add(
          original.copyWith(
            id: '${++_id}',
            conversationId: conversation.id,
            senderId: sender,
          ),
        );
        return;
      }
      String text = content;
      String? replyToId;
      String? replySnippet;
      String? replySender;
      String mediaType = 'text';
      int? audioDurationSeconds;
      List<double>? audioWaveform;
      String? channel;
      String? pollQuestion;
      List<String>? pollOptions;
      Map<String, List<String>> pollVotes = {};
      bool isViewOnce = false;
      int? ephemeralSeconds;

      if (content.startsWith('{"nx_type":"rich"')) {
        try {
          final rich = jsonDecode(content) as Map<String, dynamic>;
          text = rich['text'] as String? ?? '';
          replyToId = rich['replyToId'] as String?;
          replySnippet = rich['replySnippet'] as String?;
          replySender = rich['replySender'] as String?;
          mediaType = rich['mediaType'] as String? ?? 'text';
          audioDurationSeconds = rich['audioDurationSeconds'] as int?;
          if (rich['audioWaveform'] is List) {
            audioWaveform = (rich['audioWaveform'] as List)
                .map((v) => (v as num).toDouble())
                .toList();
          }
          channel = rich['channel'] as String?;
          pollQuestion = rich['pollQuestion'] as String?;
          if (rich['pollOptions'] is List) {
            pollOptions = List<String>.from(rich['pollOptions'] as List);
          }
          if (rich['pollVotes'] is Map) {
            final rawVotes = rich['pollVotes'] as Map;
            for (final entry in rawVotes.entries) {
              if (entry.value is List) {
                pollVotes[entry.key.toString()] =
                    List<String>.from(entry.value as List);
              }
            }
          }
          isViewOnce = rich['isViewOnce'] as bool? ?? false;
          ephemeralSeconds = rich['ephemeralSeconds'] as int?;
        } catch (_) {}
      }

      _messages.add(
        DecryptedMessage(
          id: '${++_id}',
          conversationId: conversation.id,
          senderId: sender,
          content: text,
          sentAt: sentAt,
          replyToId: replyToId,
          replySnippet: replySnippet,
          replySender: replySender,
          mediaType: mediaType,
          audioDurationSeconds: audioDurationSeconds,
          audioWaveform: audioWaveform,
          channel: channel,
          pollQuestion: pollQuestion,
          pollOptions: pollOptions,
          pollVotes: pollVotes,
          isViewOnce: isViewOnce,
          ephemeralSeconds: ephemeralSeconds,
        ),
      );

      // Dispara notificação push para a nova mensagem recebida
      unawaited(
        NotificationService.instance.notifyIncomingMessage(
          conversationTitle: conversation.title,
          conversationId: conversation.id,
          senderPublicKey: sender,
          messageText: text,
          mediaType: mediaType,
          isGroup: conversation.isGroup,
        ),
      );
    }
  }

  void _receive(String peer, DecryptedMessage message) {
    if (message.content.startsWith(_filePrefix)) {
      if (message.senderId == peer) {
        unawaited(_fileTransfers[peer]?.receive(message.content));
      }
      return;
    }
    if (!conversation.isGroup) {
      _emit(message.senderId, message.content, message.sentAt, original: message);
      return;
    }
    if (message.senderId != peer || !message.content.startsWith(_prefix)) {
      return;
    }
    try {
      final body =
          jsonDecode(message.content.substring(_prefix.length))
              as Map<String, dynamic>;
      if (body['group'] != conversation.id ||
          body['members'] != _membership ||
          body['text'] is! String) {
        return;
      }
      _emit(peer, body['text'] as String, message.sentAt);
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (conversation.isSavedMessages) {
      _emit(localUserId, text, DateTime.now().toUtc());
      return;
    }
    if (!conversation.isGroup) {
      final p = _peer;
      if (p == null) throw StateError('Nenhum participante conectado.');
      await p.sendMessage(text);
      return;
    }
    final connected = _peers.values
        .where((peer) => peer.isConnected)
        .toList(growable: false);
    if (connected.isEmpty) {
      throw StateError(
        'Conecte-se a pelo menos um participante antes de enviar.',
      );
    }
    final content = text.trim();
    if (content.isEmpty) throw ArgumentError('Mensagem vazia.');
    final frame =
        '$_prefix${jsonEncode({'group': conversation.id, 'members': _membership, 'text': content})}';
    await Future.wait(connected.map((peer) => peer.sendMessage(frame)));
    _emit(localUserId, content, DateTime.now().toUtc());
  }

  Future<void> disconnect() =>
      Future.wait(_peers.values.map((peer) => peer.disconnect()));

  Future<void> close() async {
    _closed = true;
    for (final peer in _peers.values) {
      peer.removeListener(_changed);
    }
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await Future.wait(_fileTransfers.values.map((f) => f.close()));
    await Future.wait(_peers.values.map((peer) => peer.close()));
    await _messages.close();
  }
}
