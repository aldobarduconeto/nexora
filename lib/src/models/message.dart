import 'dart:convert';

class Message {
  final int messageId;
  final DateTime sentAt;
  final String textMsg;
  final String senderId;
  final String sessionId;
  final DateTime receivedAt;

  // Features de mensagens
  final String? replyToId;
  final String? replySnippet;
  final String? replySender;
  final Map<String, List<String>> reactions; // emoji -> lista de userIds
  final bool isPinned;
  final bool isStarred;
  final String mediaType; // 'text', 'audio', 'file', 'poll'
  final int? audioDurationSeconds;
  final List<double>? audioWaveform;
  final DateTime? expiresAt;

  // Features de Comunidades e Grupos
  final String? channel; // Tópico/canal da comunidade (ex: 'geral', 'anuncios')
  final String? pollQuestion;
  final List<String>? pollOptions;
  final Map<String, List<String>> pollVotes; // indexOpcao -> [userIds]

  // Features de Conversas 1-a-1
  final bool isViewOnce; // Visualização única (bomba / autodestrutiva)
  final DateTime? viewedAt; // Momento da visualização
  final int? ephemeralSeconds; // Duração efêmera em segundos

  Message({
    required this.messageId,
    required this.sentAt,
    required this.textMsg,
    required this.senderId,
    required this.sessionId,
    DateTime? receivedAt,
    this.replyToId,
    this.replySnippet,
    this.replySender,
    this.reactions = const {},
    this.isPinned = false,
    this.isStarred = false,
    this.mediaType = 'text',
    this.audioDurationSeconds,
    this.audioWaveform,
    this.expiresAt,
    this.channel,
    this.pollQuestion,
    this.pollOptions,
    this.pollVotes = const {},
    this.isViewOnce = false,
    this.viewedAt,
    this.ephemeralSeconds,
  }) : receivedAt = receivedAt ?? sentAt;

  Message copyWith({
    int? messageId,
    DateTime? sentAt,
    String? textMsg,
    String? senderId,
    String? sessionId,
    DateTime? receivedAt,
    String? replyToId,
    String? replySnippet,
    String? replySender,
    Map<String, List<String>>? reactions,
    bool? isPinned,
    bool? isStarred,
    String? mediaType,
    int? audioDurationSeconds,
    List<double>? audioWaveform,
    DateTime? expiresAt,
    String? channel,
    String? pollQuestion,
    List<String>? pollOptions,
    Map<String, List<String>>? pollVotes,
    bool? isViewOnce,
    DateTime? viewedAt,
    int? ephemeralSeconds,
  }) {
    return Message(
      messageId: messageId ?? this.messageId,
      sentAt: sentAt ?? this.sentAt,
      textMsg: textMsg ?? this.textMsg,
      senderId: senderId ?? this.senderId,
      sessionId: sessionId ?? this.sessionId,
      receivedAt: receivedAt ?? this.receivedAt,
      replyToId: replyToId ?? this.replyToId,
      replySnippet: replySnippet ?? this.replySnippet,
      replySender: replySender ?? this.replySender,
      reactions: reactions ?? this.reactions,
      isPinned: isPinned ?? this.isPinned,
      isStarred: isStarred ?? this.isStarred,
      mediaType: mediaType ?? this.mediaType,
      audioDurationSeconds: audioDurationSeconds ?? this.audioDurationSeconds,
      audioWaveform: audioWaveform ?? this.audioWaveform,
      expiresAt: expiresAt ?? this.expiresAt,
      channel: channel ?? this.channel,
      pollQuestion: pollQuestion ?? this.pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      pollVotes: pollVotes ?? this.pollVotes,
      isViewOnce: isViewOnce ?? this.isViewOnce,
      viewedAt: viewedAt ?? this.viewedAt,
      ephemeralSeconds: ephemeralSeconds ?? this.ephemeralSeconds,
    );
  }

  Map<String, dynamic> toMap() => {
    'messageId': messageId,
    'sentAt': sentAt.toUtc().toIso8601String(),
    'textMsg': textMsg,
    'senderId': senderId,
    'sessionId': sessionId,
    'receivedAt': receivedAt.toUtc().toIso8601String(),
    if (replyToId != null) 'replyToId': replyToId,
    if (replySnippet != null) 'replySnippet': replySnippet,
    if (replySender != null) 'replySender': replySender,
    if (reactions.isNotEmpty) 'reactions': reactions,
    'isPinned': isPinned,
    'isStarred': isStarred,
    'mediaType': mediaType,
    if (audioDurationSeconds != null)
      'audioDurationSeconds': audioDurationSeconds,
    if (audioWaveform != null) 'audioWaveform': audioWaveform,
    if (expiresAt != null) 'expiresAt': expiresAt!.toUtc().toIso8601String(),
    if (channel != null) 'channel': channel,
    if (pollQuestion != null) 'pollQuestion': pollQuestion,
    if (pollOptions != null) 'pollOptions': pollOptions,
    if (pollVotes.isNotEmpty) 'pollVotes': pollVotes,
    'isViewOnce': isViewOnce,
    if (viewedAt != null) 'viewedAt': viewedAt!.toUtc().toIso8601String(),
    if (ephemeralSeconds != null) 'ephemeralSeconds': ephemeralSeconds,
  };

  factory Message.fromMap(Map<String, dynamic> map) {
    Map<String, List<String>> parsedReactions = {};
    if (map['reactions'] is Map) {
      final rawReactions = map['reactions'] as Map;
      for (final entry in rawReactions.entries) {
        if (entry.value is List) {
          parsedReactions[entry.key.toString()] =
              List<String>.from(entry.value as List);
        }
      }
    }

    List<double>? parsedWaveform;
    if (map['audioWaveform'] is List) {
      parsedWaveform = (map['audioWaveform'] as List)
          .map((v) => (v as num).toDouble())
          .toList();
    }

    Map<String, List<String>> parsedPollVotes = {};
    if (map['pollVotes'] is Map) {
      final rawVotes = map['pollVotes'] as Map;
      for (final entry in rawVotes.entries) {
        if (entry.value is List) {
          parsedPollVotes[entry.key.toString()] =
              List<String>.from(entry.value as List);
        }
      }
    }

    return Message(
      messageId: map['messageId'] as int,
      sentAt: DateTime.parse(map['sentAt'] as String).toLocal(),
      textMsg: map['textMsg'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      sessionId: map['sessionId'] as String? ?? '',
      receivedAt: map['receivedAt'] != null
          ? DateTime.parse(map['receivedAt'] as String).toLocal()
          : null,
      replyToId: map['replyToId'] as String?,
      replySnippet: map['replySnippet'] as String?,
      replySender: map['replySender'] as String?,
      reactions: parsedReactions,
      isPinned: map['isPinned'] as bool? ?? false,
      isStarred: map['isStarred'] as bool? ?? false,
      mediaType: map['mediaType'] as String? ?? 'text',
      audioDurationSeconds: map['audioDurationSeconds'] as int?,
      audioWaveform: parsedWaveform,
      expiresAt: map['expiresAt'] is String
          ? DateTime.tryParse(map['expiresAt'] as String)?.toLocal()
          : null,
      channel: map['channel'] as String?,
      pollQuestion: map['pollQuestion'] as String?,
      pollOptions: map['pollOptions'] is List
          ? List<String>.from(map['pollOptions'] as List)
          : null,
      pollVotes: parsedPollVotes,
      isViewOnce: map['isViewOnce'] as bool? ?? false,
      viewedAt: map['viewedAt'] is String
          ? DateTime.tryParse(map['viewedAt'] as String)?.toLocal()
          : null,
      ephemeralSeconds: map['ephemeralSeconds'] as int?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Message.fromJson(String source) =>
      Message.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
