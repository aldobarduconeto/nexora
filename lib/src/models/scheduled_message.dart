import 'dart:convert';

/// Representa uma mensagem agendada para envio automático em data e hora futuras.
class ScheduledMessage {
  final String id;
  final String conversationId;
  final String content;
  final DateTime scheduledFor;
  final DateTime createdAt;
  final String? replyToId;
  final String? replySnippet;
  final String? replySender;
  final String? channel;
  final bool isViewOnce;
  final int? ephemeralSeconds;

  const ScheduledMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.scheduledFor,
    required this.createdAt,
    this.replyToId,
    this.replySnippet,
    this.replySender,
    this.channel,
    this.isViewOnce = false,
    this.ephemeralSeconds,
  });

  ScheduledMessage copyWith({
    String? id,
    String? conversationId,
    String? content,
    DateTime? scheduledFor,
    DateTime? createdAt,
    String? replyToId,
    String? replySnippet,
    String? replySender,
    String? channel,
    bool? isViewOnce,
    int? ephemeralSeconds,
  }) => ScheduledMessage(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    content: content ?? this.content,
    scheduledFor: scheduledFor ?? this.scheduledFor,
    createdAt: createdAt ?? this.createdAt,
    replyToId: replyToId ?? this.replyToId,
    replySnippet: replySnippet ?? this.replySnippet,
    replySender: replySender ?? this.replySender,
    channel: channel ?? this.channel,
    isViewOnce: isViewOnce ?? this.isViewOnce,
    ephemeralSeconds: ephemeralSeconds ?? this.ephemeralSeconds,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'conversationId': conversationId,
    'content': content,
    'scheduledFor': scheduledFor.toUtc().toIso8601String(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (replyToId != null) 'replyToId': replyToId,
    if (replySnippet != null) 'replySnippet': replySnippet,
    if (replySender != null) 'replySender': replySender,
    if (channel != null) 'channel': channel,
    'isViewOnce': isViewOnce,
    if (ephemeralSeconds != null) 'ephemeralSeconds': ephemeralSeconds,
  };

  factory ScheduledMessage.fromMap(Map<String, dynamic> map) => ScheduledMessage(
    id: map['id'] as String,
    conversationId: map['conversationId'] as String,
    content: map['content'] as String,
    scheduledFor: DateTime.parse(map['scheduledFor'] as String).toLocal(),
    createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
    replyToId: map['replyToId'] as String?,
    replySnippet: map['replySnippet'] as String?,
    replySender: map['replySender'] as String?,
    channel: map['channel'] as String?,
    isViewOnce: map['isViewOnce'] as bool? ?? false,
    ephemeralSeconds: map['ephemeralSeconds'] as int?,
  );

  String toJson() => jsonEncode(toMap());
  factory ScheduledMessage.fromJson(String source) =>
      ScheduledMessage.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
