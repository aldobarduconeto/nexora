import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nexora/src/utils/serial_task_queue.dart';

/// Mensagem recebida e descriptografada com suporte a respostas, mídias e reações.
class DecryptedMessage {
  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime sentAt;
  final DateTime receivedAt;
  final String? replyToId;
  final String? replySnippet;
  final String? replySender;
  final String mediaType;
  final int? audioDurationSeconds;
  final List<double>? audioWaveform;
  final Map<String, List<String>> reactions;
  final bool isPinned;
  final bool isStarred;

  // Features de Comunidades e 1-a-1
  final String? channel;
  final String? pollQuestion;
  final List<String>? pollOptions;
  final Map<String, List<String>> pollVotes;
  final bool isViewOnce;
  final DateTime? viewedAt;
  final int? ephemeralSeconds;

  DecryptedMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.sentAt,
    DateTime? receivedAt,
    this.replyToId,
    this.replySnippet,
    this.replySender,
    this.mediaType = 'text',
    this.audioDurationSeconds,
    this.audioWaveform,
    this.reactions = const {},
    this.isPinned = false,
    this.isStarred = false,
    this.channel,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes = const {},
    this.isViewOnce = false,
    this.viewedAt,
    this.ephemeralSeconds,
  }) : receivedAt = receivedAt ?? DateTime.now();

  DecryptedMessage copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? content,
    DateTime? sentAt,
    DateTime? receivedAt,
    String? replyToId,
    String? replySnippet,
    String? replySender,
    String? mediaType,
    int? audioDurationSeconds,
    List<double>? audioWaveform,
    Map<String, List<String>>? reactions,
    bool? isPinned,
    bool? isStarred,
    String? channel,
    String? pollQuestion,
    List<String>? pollOptions,
    Map<String, List<String>>? pollVotes,
    bool? isViewOnce,
    DateTime? viewedAt,
    int? ephemeralSeconds,
  }) {
    return DecryptedMessage(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      receivedAt: receivedAt ?? this.receivedAt,
      replyToId: replyToId ?? this.replyToId,
      replySnippet: replySnippet ?? this.replySnippet,
      replySender: replySender ?? this.replySender,
      mediaType: mediaType ?? this.mediaType,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      audioWaveform: audioWaveform ?? this.audioWaveform,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
      channel: channel ?? this.channel,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVotes: pollVotes ?? this.pollVotes,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedAt: viewedAt ?? this.viewedAt,
      ephemeralSeconds: ephemeralSeconds ?? this.ephemeralSeconds,
    );
  }
}

/// Serviço de mensagens do Nexora.
/// Responsabilidades:
/// - Gerar identificadores únicos.
/// - Criptografar mensagens com AES-256-GCM.
/// - Transportar mensagens por RTCDataChannel.
/// - Receber e descriptografar mensagens.
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
  static const int _maxSequence = 9007199254740991;
  static final AesGcm _cipher = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<SecretKey> _directionKey(String sender) => _hkdf.deriveKey(
    secretKey: SecretKey(_sharedSecret),
    nonce: utf8.encode(sessionId),
    info: utf8.encode(jsonEncode(['nexora-message-v2', sender])),
  );

  late final Future<SecretKey> _sendKey = _directionKey(localUserId);
  late final Future<SecretKey> _receiveKey = _directionKey(remoteUserId);

  static Uint8List _nonce(int sequence) {
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
      onError: (Object error, StackTrace stackTrace) {},
    );
  }

  Future<String> sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? replyToId,
    String? replySnippet,
    String? replySender,
    String mediaType = 'text',
    int? audioDurationSeconds,
    List<double>? audioWaveform,
    String? channel,
    String? pollQuestion,
    List<String>? pollOptions,
    Map<String, List<String>>? pollVotes,
    bool isViewOnce = false,
    int? ephemeralSeconds,
  }) {
    return _outgoing.run(
      () => _sendMessage(
        conversationId: conversationId,
        senderId: senderId,
        content: content,
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
  }

  Future<String> _sendMessage({
    required String conversationId,
    required String senderId,
    required String content,
    String? replyToId,
    String? replySnippet,
    String? replySender,
    String mediaType = 'text',
    int? audioDurationSeconds,
    List<double>? audioWaveform,
    String? channel,
    String? pollQuestion,
    List<String>? pollOptions,
    Map<String, List<String>>? pollVotes,
    bool isViewOnce = false,
    int? ephemeralSeconds,
  }) async {
    final channelConn = _channel;
    if (_closed || channelConn == null || !isConnected) {
      throw StateError('O canal P2P não está conectado.');
    }
    if (content.trim().isEmpty && mediaType == 'text') {
      throw ArgumentError('A mensagem não pode estar vazia.');
    }

    final String wireContent;
    if (replyToId != null ||
        mediaType != 'text' ||
        audioDurationSeconds != null ||
        channel != null ||
        pollQuestion != null ||
        isViewOnce ||
        ephemeralSeconds != null) {
      wireContent = jsonEncode({
        'nx_type': 'rich',
        'text': content,
        if (replyToId != null) 'replyToId': replyToId,
        if (replySnippet != null) 'replySnippet': replySnippet,
        if (replySender != null) 'replySender': replySender,
        'mediaType': mediaType,
        if (audioDurationSeconds != null)
          'audioDurationSeconds': audioDurationSeconds,
        if (audioWaveform != null) 'audioWaveform': audioWaveform,
        if (channel != null) 'channel': channel,
        if (pollQuestion != null) 'pollQuestion': pollQuestion,
        if (pollOptions != null) 'pollOptions': pollOptions,
        if (pollVotes != null && pollVotes.isNotEmpty) 'pollVotes': pollVotes,
        if (isViewOnce) 'isViewOnce': true,
        if (ephemeralSeconds != null) 'ephemeralSeconds': ephemeralSeconds,
      });
    } else {
      wireContent = content;
    }

    final clearBytes = utf8.encode(wireContent);
    if (clearBytes.length > _maxMessageLength) {
      throw ArgumentError('A mensagem ultrapassa o limite permitido.');
    }
    if (senderId != localUserId) throw StateError('Remetente inválido.');
    if (_sendSequence >= _maxSequence) {
      throw StateError('Renegocie a sessão antes de enviar mais mensagens.');
    }
    final sequence = ++_sendSequence;
    final id = '$sequence';
    conversationId = sessionId;
    final sentAt = DateTime.now().toUtc();
    final timestamp = sentAt.toIso8601String();
    final aad = _buildAad(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      timestamp: timestamp,
    );
    final secretKey = await _sendKey;
    final encrypted = await _cipher.encrypt(
      clearBytes,
      secretKey: secretKey,
      nonce: _nonce(sequence),
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
    await channelConn.send(RTCDataChannelMessage(jsonEncode(envelope)));
    if (_closed) return id;
    _messageController.add(
      DecryptedMessage(
        id: id,
        conversationId: conversationId,
        senderId: senderId,
        content: content,
        sentAt: sentAt,
        receivedAt: sentAt,
        replyToId: replyToId,
        replySnippet: replySnippet,
        replySender: replySender,
        mediaType: mediaType,
        audioDurationSeconds: audioDurationSeconds,
        audioWaveform: audioWaveform,
        channel: channel,
        pollQuestion: pollQuestion,
        pollOptions: pollOptions,
        pollVotes: pollVotes ?? const {},
        isViewOnce: isViewOnce,
        ephemeralSeconds: ephemeralSeconds,
      ),
    );
    return id;
  }

  Future<void> _handleIncoming(String raw) async {
    try {
      if (raw.length > _maxMessageLength * 2) return;

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> || decoded['v'] != 2) return;

      final id = decoded['id'] as String?;
      final conversationId = decoded['conversationId'] as String?;
      final senderId = decoded['senderId'] as String?;
      final timestamp = decoded['sentAt'] as String?;
      if (id == null ||
          conversationId == null ||
          senderId == null ||
          timestamp == null) {
        return;
      }

      final sequence = int.tryParse(id);
      if (sequence == null ||
          sequence <= _receiveSequence ||
          sequence > _maxSequence ||
          id != sequence.toString() ||
          conversationId != sessionId ||
          senderId != remoteUserId) {
        return;
      }

      final nonce = base64Decode(decoded['nonce'] as String);
      final cipherText = base64Decode(decoded['cipherText'] as String);
      final mac = base64Decode(decoded['mac'] as String);

      if (nonce.length != _cipher.nonceLength ||
          mac.length != 16 ||
          cipherText.length > _maxMessageLength ||
          !listEquals(nonce, _nonce(sequence))) {
        return;
      }

      final sentAt = DateTime.parse(timestamp).toUtc();
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

      if (clearBytes.length > _maxMessageLength) return;
      final rawContent = utf8.decode(clearBytes);
      String content = rawContent;
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

      if (rawContent.startsWith('{"nx_type":"rich"')) {
        try {
          final rich = jsonDecode(rawContent) as Map<String, dynamic>;
          content = rich['text'] as String? ?? '';
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

      _receiveSequence = sequence;
      if (_closed) return;
      _messageController.add(
        DecryptedMessage(
          id: id,
          conversationId: conversationId,
          senderId: senderId,
          content: content,
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
    } on SecretBoxAuthenticationError {
      _closed = true;
      _messageController.addError(
        StateError('Falha de autenticação. Sessão encerrada.'),
      );
      await _channel?.close();
    } on Object {
      // Dados inválidos, mensagem adulterada ou chave incorreta.
    }
  }

  static List<int> _buildAad({
    required String id,
    required String conversationId,
    required String senderId,
    required String timestamp,
  }) => utf8.encode(
    jsonEncode([
      'nexora-message-v2',
      id,
      conversationId,
      senderId,
      timestamp,
    ]),
  );

  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    _channel = null;
    await _messageController.close();
  }
}
