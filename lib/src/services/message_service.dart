import 'package:nexora/src/utils/serial_task_queue.dart';

import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Mensagem recebida e descriptografada.
class DecryptedMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime sentAt;
  const DecryptedMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.sentAt,
  });
}

/// Serviço de mensagens do Nexora.
/// Responsabilidades:
/// - Gerar identificadores únicos.
/// - Criptografar mensagens com AES-256-GCM.
/// - Transportar mensagens por RTCDataChannel.
/// - Receber e descriptografar mensagens.
/// A conexão RTCPeerConnection e a negociação SDP/ICE
/// devem ser configuradas separadamente.
class MessageService {
  MessageService({
    required List<int> sharedSecret,
    required this.sessionId,
    required this.localUserId,
    required this.remoteUserId,
  }) : _sharedSecret = List<int>.unmodifiable(sharedSecret) {
    if (_sharedSecret.length != 32) {
      throw ArgumentError(
        'A chave compartilhada deve possuir exatamente 32 bytes.',
      );
    }
    if (sessionId.isEmpty ||
        localUserId.isEmpty ||
        remoteUserId.isEmpty ||
        localUserId == remoteUserId) {
      throw ArgumentError('Sessão e identidades distintas são obrigatórias.');
    }
  }

  final String sessionId;
  final String localUserId;
  final String remoteUserId;
  final List<int> _sharedSecret;
  int _sendSequence = 0;
  int _receiveSequence = 0;
  int _pendingIncoming = 0;
  bool _closed = false;
  Future<void> _incoming = Future.value();
  final _outgoing = SerialTaskQueue();
  static const int _maxMessageLength = 64 * 1024;
  final AesGcm _cipher = AesGcm.with256bits();
  Future<SecretKey> _directionKey(String sender) =>
      Hkdf(hmac: Hmac.sha256(), outputLength: 32).deriveKey(
        secretKey: SecretKey(_sharedSecret),
        nonce: utf8.encode(sessionId),
        info: utf8.encode(jsonEncode(['nexora-message-v2', sender])),
      );
  late final Future<SecretKey> _sendKey = _directionKey(localUserId);
  late final Future<SecretKey> _receiveKey = _directionKey(remoteUserId);

  List<int> _nonce(int sequence) {
    final bytes = ByteData(12);
    bytes.setUint32(4, sequence ~/ 0x100000000);
    bytes.setUint32(8, sequence % 0x100000000);
    return bytes.buffer.asUint8List();
  }

  RTCDataChannel? _channel;
  StreamSubscription<RTCDataChannelMessage>? _subscription;
  final StreamController<DecryptedMessage> _messageController =
      StreamController<DecryptedMessage>.broadcast();
  Stream<DecryptedMessage> get messages => _messageController.stream;
  bool get isConnected =>
      _channel?.state == RTCDataChannelState.RTCDataChannelOpen;

  /// Conecta o serviço a um canal de dados já negociado.
  /// Pode receber o canal criado pelo iniciador ou o canal
  /// recebido pelo callback onDataChannel do outro dispositivo.
  Future<void> attachChannel(RTCDataChannel channel) async {
    await _subscription?.cancel();
    _channel = channel;
    _subscription = channel.messageStream.listen(
      (message) {
        if (_closed ||
            message.isBinary ||
            message.text.length > _maxMessageLength * 2 ||
            _pendingIncoming >= 32) {
          return;
        }
        _pendingIncoming++;
        _incoming = _incoming.then((_) async {
          try {
            if (!_closed) await _handleIncoming(message.text);
          } finally {
            _pendingIncoming--;
          }
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        // Conecte aqui ao seu sistema de logging.
      },
    );
  }

  /// Criptografa e envia uma mensagem de texto.
  ///
  /// Retorna o ID local da mensagem após o envio pelo canal.
  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) {
    return _outgoing.run(
      () => _sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
      ),
    );
  }

  Future<String> _sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
  }) async {
    final channel = _channel;
    if (_closed || channel == null || !isConnected) {
      throw StateError('O canal P2P não está conectado.');
    }
    if (content.trim().isEmpty) {
      throw ArgumentError('A mensagem não pode estar vazia.');
    }
    if (utf8.encode(content).length > _maxMessageLength) {
      throw ArgumentError('A mensagem ultrapassa o limite permitido.');
    }
    if (senderId != localUserId) throw StateError('Remetente inválido.');
    if (_sendSequence >= 9007199254740991) {
      throw StateError('Renegocie a sessão antes de enviar mais mensagens.');
    }
    final id = '${++_sendSequence}';
    conversationId = sessionId;
    final sentAt = DateTime.now().toUtc();
    final timestamp = sentAt.toIso8601String();
    // Os metadados autenticados não podem ser alterados sem
    // que a verificação de autenticação falhe.
    final aad = _buildAad(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      timestamp: timestamp,
    );
    final secretKey = await _sendKey;
    final encrypted = await _cipher.encrypt(
      utf8.encode(content),
      secretKey: secretKey,
      nonce: _nonce(_sendSequence),
      aad: aad,
    );
    final envelope = <String, dynamic>{
      'v': 2,
      'id': id,
      'conversationId': conversationId,
      'senderId': senderId,
      'sentAt': timestamp,
      'nonce': base64Encode(encrypted.nonce),
      'cipherText': base64Encode(encrypted.cipherText),
      'mac': base64Encode(encrypted.mac.bytes),
    };
    await channel.send(RTCDataChannelMessage(jsonEncode(envelope)));
    if (_closed) return id;
    _messageController.add(
      DecryptedMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        sentAt: sentAt,
      ),
    );
    return id;
  }

  Future<void> _handleIncoming(String raw) async {
    try {
      if (utf8.encode(raw).length > _maxMessageLength * 2) {
        return;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return;
      }

      if (decoded['v'] != 2) {
        return;
      }

      final id = decoded['id'] as String;
      final conversationId = decoded['conversationId'] as String;
      final senderId = decoded['senderId'] as String;
      final timestamp = decoded['sentAt'] as String;

      final nonce = base64Decode(decoded['nonce'] as String);
      final cipherText = base64Decode(decoded['cipherText'] as String);
      final mac = base64Decode(decoded['mac'] as String);

      if (conversationId != sessionId ||
          senderId != remoteUserId ||
          int.tryParse(id) == null ||
          int.parse(id) <= _receiveSequence ||
          id.isEmpty ||
          conversationId.isEmpty ||
          senderId.isEmpty ||
          nonce.length != _cipher.nonceLength ||
          mac.length != 16 ||
          cipherText.length > _maxMessageLength) {
        return;
      }

      final sentAt = DateTime.parse(timestamp).toUtc();
      if (id != int.parse(id).toString() ||
          int.parse(id) > 9007199254740991 ||
          !listEquals(nonce, _nonce(int.parse(id))))
        return;
      final secretKey = await _receiveKey;

      final secretBox = SecretBox(cipherText, nonce: nonce, mac: Mac(mac));
      final clearBytes = await _cipher.decrypt(
        secretBox,
        secretKey: secretKey,
        aad: _buildAad(
          id: id,
          conversationId: conversationId,
          senderId: senderId,
          timestamp: timestamp,
        ),
      );

      if (clearBytes.length > _maxMessageLength) {
        return;
      }
      final content = utf8.decode(clearBytes);
      _receiveSequence = int.parse(id);
      if (_closed) return;
      _messageController.add(
        DecryptedMessage(
          id: id,
          conversationId: conversationId,
          senderId: senderId,
          content: content,
          sentAt: sentAt,
        ),
      );
    } on SecretBoxAuthenticationError {
      _closed = true;
      _messageController.addError(
        StateError('Falha de autenticação. Sessão encerrada.'),
      );
      await _channel?.close();
    } on Object {
      // Dados inválidos, mensagem adulterada ou chave incorreta.
      // Não exponha conteúdo ou segredos nos logs.
    }
  }

  List<int> _buildAad({
    required String id,
    required String conversationId,
    required String senderId,
    required String timestamp,
  }) {
    return utf8.encode(
      jsonEncode([
        'nexora-message-v2',
        id,
        conversationId,
        senderId,
        timestamp,
      ]),
    );
  }

  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    _channel = null;
    await _messageController.close();
  }
}
