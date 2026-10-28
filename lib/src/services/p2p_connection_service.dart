import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nexora/src/services/message_service.dart';
import 'package:nexora/src/services/identity_protocol.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:uuid/uuid.dart';
import 'package:nexora/src/services/p2p_network_configuration.dart';

enum P2PConnectionStatus {
  disconnected,
  negotiating,
  waitingForAnswer,
  connecting,
  connected,
  failed,
}

class P2PConnectionService extends ChangeNotifier {
  P2PConnectionService({
    required this.conversationId,
    required this.localUserId,
    required this.remotePublicKey,
    this.connectionTimeoutSeconds = 30,
    P2PNetworkConfiguration? networkConfiguration,
  }) : networkConfiguration =
           networkConfiguration ?? P2PNetworkConfiguration.fromEnvironment();

  final P2PNetworkConfiguration networkConfiguration;

  final String conversationId;
  final String localUserId;
  final String remotePublicKey;
  final int connectionTimeoutSeconds;
  String? _sessionId;
  String? _offerDigest;
  bool _answerAccepted = false;
  final StreamController<DecryptedMessage> _messageController =
      StreamController<DecryptedMessage>.broadcast();
  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  MessageService? _messageService;
  StreamSubscription<DecryptedMessage>? _messageSubscription;
  SimpleKeyPair? _ephemeralKeyPair;
  P2PConnectionStatus _status = P2PConnectionStatus.disconnected;
  bool _isOfferer = false;
  bool _profileSent = false;
  static const _profilePrefix = 'NEXORA_PROFILE_V1:';
  Stream<DecryptedMessage> get messages => _messageController.stream;
  P2PConnectionStatus get status => _status;
  bool get isConnected =>
      _status == P2PConnectionStatus.connected &&
      _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
  bool get canApplyAnswer => _isOfferer;

  void _assertContactAllowed() {
    if (LocalDataService.instance.isBlocked(remotePublicKey))
      throw StateError('Contato bloqueado. Desbloqueie nas configurações.');
  }

  Future<String> createOffer() async {
    _assertContactAllowed();
    await _resetPeerConnection();
    _ephemeralKeyPair = await X25519().newKeyPair();
    _isOfferer = true;
    _sessionId = const Uuid().v4();
    _setStatus(P2PConnectionStatus.negotiating);
    final peerConnection = await _createPeerConnection();
    final channel = await peerConnection.createDataChannel(
      'nexora-chat',
      RTCDataChannelInit(),
    );
    await _attachDataChannel(channel);
    final offer = await peerConnection.createOffer();
    await peerConnection.setLocalDescription(offer);
    await _waitForIceGathering(peerConnection);
    final localDescription = await peerConnection.getLocalDescription();
    if (localDescription?.sdp == null || localDescription!.sdp!.isEmpty) {
      throw StateError('O WebRTC não gerou uma oferta SDP válida.');
    }
    _setStatus(P2PConnectionStatus.waitingForAnswer);
    final encoded = await _encodeDescription(localDescription);
    _offerDigest = base64Encode(
      (await Sha256().hash(utf8.encode(encoded))).bytes,
    );
    return encoded;
  }

  Future<String> acceptOffer(String signalingData) async {
    _assertContactAllowed();
    final decodedOffer = await _decodeDescription(
      signalingData,
      expectedType: 'offer',
    );
    await _resetPeerConnection();
    _ephemeralKeyPair = await X25519().newKeyPair();
    _sessionId = decodedOffer.session;
    _offerDigest = base64Encode(
      (await Sha256().hash(utf8.encode(signalingData))).bytes,
    );
    await _deriveMessageKey(decodedOffer.publicKey);
    _isOfferer = false;
    _setStatus(P2PConnectionStatus.negotiating);
    final peerConnection = await _createPeerConnection();
    await peerConnection.setRemoteDescription(decodedOffer.description);
    final answer = await peerConnection.createAnswer();
    await peerConnection.setLocalDescription(answer);
    await _waitForIceGathering(peerConnection);
    final localDescription = await peerConnection.getLocalDescription();
    if (localDescription?.sdp == null || localDescription!.sdp!.isEmpty) {
      throw StateError('O WebRTC não gerou uma resposta SDP válida.');
    }
    _setStatus(P2PConnectionStatus.connecting);
    return _encodeDescription(localDescription);
  }

  Future<void> acceptAnswer(String signalingData) async {
    _assertContactAllowed();
    if (!_isOfferer || _peerConnection == null || _answerAccepted) {
      throw StateError('Crie um convite antes de aplicar uma resposta.');
    }
    final answer = await _decodeDescription(
      signalingData,
      expectedType: 'answer',
    );
    await _deriveMessageKey(answer.publicKey);
    await _peerConnection!.setRemoteDescription(answer.description);
    _answerAccepted = true;
    _updateConnectionStatus();
  }

  Future<void> sendMessage(String text) async {
    _assertContactAllowed();
    final channel = _dataChannel;
    if (!isConnected || channel == null) {
      throw StateError(
        'Conecte-se a outro dispositivo antes de enviar mensagens.',
      );
    }
    final normalizedText = text.trim();
    if (normalizedText.isEmpty) {
      throw ArgumentError('A mensagem não pode estar vazia.');
    }

    await _messageService!.sendMessage(
      conversationId: conversationId,
      senderId: localUserId,
      content: normalizedText,
    );
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final peerConnection = await createPeerConnection(
      networkConfiguration.toWebRtcConfiguration(),
    );
    _peerConnection = peerConnection;
    peerConnection.onConnectionState = (state) {
      switch (state) {
        case RTCPeerConnectionState.RTCPeerConnectionStateConnected:
          _updateConnectionStatus();
        case RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        case RTCPeerConnectionState.RTCPeerConnectionStateClosed:
          _setStatus(P2PConnectionStatus.failed);
        case RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
          _setStatus(P2PConnectionStatus.connecting);
        default:
          break;
      }
    };
    peerConnection.onDataChannel = (channel) {
      unawaited(_attachDataChannel(channel));
    };
    return peerConnection;
  }

  Future<void> _attachDataChannel(RTCDataChannel channel) async {
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      switch (state) {
        case RTCDataChannelState.RTCDataChannelOpen:
          _updateConnectionStatus();
        case RTCDataChannelState.RTCDataChannelClosing:
        case RTCDataChannelState.RTCDataChannelClosed:
          _setStatus(P2PConnectionStatus.failed);
        case RTCDataChannelState.RTCDataChannelConnecting:
          _setStatus(P2PConnectionStatus.connecting);
      }
    };
    final messageService = _messageService;
    if (messageService != null) {
      await messageService.attachChannel(channel);
    }
  }

  Future<void> _waitForIceGathering(RTCPeerConnection peerConnection) async {
    if (peerConnection.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }

    final completer = Completer<void>();
    peerConnection.onIceGatheringState = (state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !completer.isCompleted) {
        completer.complete();
      }
    };
    if (peerConnection.iceGatheringState ==
            RTCIceGatheringState.RTCIceGatheringStateComplete &&
        !completer.isCompleted) {
      completer.complete();
    }
    await completer.future.timeout(
      Duration(seconds: connectionTimeoutSeconds),
      onTimeout: () => throw TimeoutException(
        'A coleta de candidatos ICE excedeu $connectionTimeoutSeconds segundos. Verifique sua conexão.',
      ),
    );
  }

  Future<
    ({
      RTCSessionDescription description,
      SimplePublicKey publicKey,
      String session,
    })
  >
  _decodeDescription(
    String signalingData, {
    required String expectedType,
  }) async {
    final decoded = await IdentityProtocol.verify(
      signalingData,
      remotePublicKey,
    );
    final expires = DateTime.parse(decoded['expires'] as String);
    final session = decoded['session'] as String;
    if (decoded['v'] != 2 ||
        decoded['type'] != expectedType ||
        decoded['recipient'] != localUserId ||
        session.length != 36 ||
        expires.isBefore(DateTime.now()) ||
        expires.isAfter(DateTime.now().add(const Duration(minutes: 11))) ||
        decoded['sdp'] is! String ||
        (decoded['sdp'] as String).isEmpty) {
      throw const FormatException(
        'Convite inválido, expirado ou destinado a outra pessoa.',
      );
    }
    if (expectedType == 'answer' &&
        (session != _sessionId || decoded['offerDigest'] != _offerDigest)) {
      throw const FormatException('A resposta não pertence a este convite.');
    }
    final keyBytes = base64Decode(decoded['publicKey'] as String);
    if (keyBytes.length != 32 || keyBytes.every((b) => b == 0)) {
      throw const FormatException('Chave de sessão inválida.');
    }
    return (
      description: RTCSessionDescription(
        decoded['sdp'] as String,
        expectedType,
      ),
      publicKey: SimplePublicKey(keyBytes, type: KeyPairType.x25519),
      session: session,
    );
  }

  Future<String> _encodeDescription(RTCSessionDescription description) async {
    final key = await _ephemeralKeyPair!.extractPublicKey();
    return IdentityProtocol.sign({
      'v': 2,
      'type': description.type,
      'sdp': networkConfiguration.signalingSdp(description.sdp!),
      'publicKey': base64Encode(key.bytes),
      'identity': localUserId,
      'recipient': remotePublicKey,
      'session': _sessionId,
      'expires': DateTime.now()
          .toUtc()
          .add(const Duration(minutes: 10))
          .toIso8601String(),
      if (description.type == 'answer') 'offerDigest': _offerDigest,
    }, LocalDataService.instance.identityKeyPair);
  }

  Future<void> _deriveMessageKey(SimplePublicKey remotePublicKey) async {
    final keyPair = _ephemeralKeyPair;
    if (keyPair == null)
      throw StateError('A chave desta conexão não foi criada.');
    final sharedSecret = await X25519().sharedSecretKey(
      keyPair: keyPair,
      remotePublicKey: remotePublicKey,
    );
    final key = await Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
      secretKey: sharedSecret,
      nonce: utf8.encode(_sessionId!),
      info: utf8.encode(
        jsonEncode([
          'nexora-e2e-chat-v2',
          ...([localUserId, this.remotePublicKey]..sort()),
        ]),
      ),
    );
    final messageService = MessageService(
      sharedSecret: await key.extractBytes(),
      sessionId: _sessionId!,
      localUserId: localUserId,
      remoteUserId: this.remotePublicKey,
    );
    await _messageSubscription?.cancel();
    await _messageService?.close();
    _messageService = messageService;
    _messageSubscription = messageService.messages.listen(
      (message) {
        if (LocalDataService.instance.isBlocked(this.remotePublicKey)) return;
        if (message.content.startsWith(_profilePrefix)) {
          if (message.senderId == this.remotePublicKey) {
            unawaited(_receiveProfile(message.content));
          }
          return;
        }
        _messageController.add(message);
      },
      onError: (Object error, StackTrace stack) {
        _setStatus(P2PConnectionStatus.failed);
        _messageController.addError(error, stack);
        unawaited(_peerConnection?.close());
      },
    );
    final channel = _dataChannel;
    if (channel != null) await messageService.attachChannel(channel);
  }

  Future<void> _receiveProfile(String content) async {
    try {
      final profile = jsonDecode(
        content.substring(_profilePrefix.length),
      ) as Map<String, dynamic>;
      if (profile['nickname'] is String)
        await LocalDataService.instance.updateContactName(
          remotePublicKey,
          profile['nickname'] as String,
        );
    } catch (_) {
      /* Do not log remote payloads or connection data. */
    }
  }

  Future<void> _sendProfile() async {
    try {
      await sendMessage(
        '$_profilePrefix${jsonEncode({'nickname': LocalDataService.instance.currentUser.nickname})}',
      );
    } catch (_) {
      _profileSent = false;
    }
  }

  void _setStatus(P2PConnectionStatus status) {
    _status = status;
    notifyListeners();
    if (status == P2PConnectionStatus.connected && !_profileSent) {
      _profileSent = true;
      unawaited(_sendProfile());
    }
  }

  void _updateConnectionStatus() {
    final connected =
        _messageService != null &&
        _peerConnection?.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected &&
        _dataChannel?.state == RTCDataChannelState.RTCDataChannelOpen;
    _setStatus(
      connected
          ? P2PConnectionStatus.connected
          : P2PConnectionStatus.connecting,
    );
  }

  Future<void> _resetPeerConnection() async {
    await _messageSubscription?.cancel();
    _messageSubscription = null;
    await _messageService?.close();
    _messageService = null;
    _ephemeralKeyPair = null;
    _sessionId = null;
    _offerDigest = null;
    _answerAccepted = false;
    _profileSent = false;
    await _dataChannel?.close();
    _dataChannel = null;
    await _peerConnection?.close();
    _peerConnection = null;
    _setStatus(P2PConnectionStatus.disconnected);
  }

  Future<void> disconnect() => _resetPeerConnection();

  Future<void> close() async {
    await _resetPeerConnection();
    await _messageController.close();
  }
}
