import 'dart:convert';

import 'package:nexora/src/models/message.dart';

enum ConversationStatus { active, away, archived, deleted }

class Conversation {
  final String id;
  final bool isGroup;
  final String title;
  final List<Message> messages;
  final List<String> participantIds;
  final String? lastMessageId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final ConversationStatus status;

  // Features de conversas
  final bool isPinned;
  final bool isMuted;
  final int? ephemeralRetentionSeconds; // 30, 300, 3600, 86400 ou null
  final List<String> pinnedMessageIds;
  final bool isSavedMessages;

  // Features de Comunidades & Grupos
  final bool isCommunity;
  final List<String> channels; // ex: ['geral', 'anúncios', 'mídia']
  final String? description;
  final List<String> adminIds;
  final String? creatorId;

  // Features de Conversas 1-a-1
  final String? privateContactNotes; // Anotações privadas que só este dispositivo vê
  final bool isSafetyVerified; // Chaves de segurança verificadas (60 dígitos / QR)

  const Conversation({
    required this.id,
    this.isGroup = false,
    required this.title,
    required this.participantIds,
    this.lastMessageId,
    required this.messages,
    required this.createdAt,
    required this.updatedAt,
    this.lastMessageAt,
    required this.unreadCount,
    this.status = ConversationStatus.active,
    this.isPinned = false,
    this.isMuted = false,
    this.ephemeralRetentionSeconds,
    this.pinnedMessageIds = const [],
    this.isSavedMessages = false,
    this.isCommunity = false,
    this.channels = const [],
    this.description,
    this.adminIds = const [],
    this.creatorId,
    this.privateContactNotes,
    this.isSafetyVerified = false,
  });

  Conversation copyWith({
    String? id,
    bool? isGroup,
    String? title,
    List<String>? participantIds,
    List<Message>? messages,
    String? lastMessageId,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    int? ephemeralRetentionSeconds,
    List<String>? pinnedMessageIds,
    bool? isSavedMessages,
    bool? isCommunity,
    List<String>? channels,
    String? description,
    List<String>? adminIds,
    String? creatorId,
    String? privateContactNotes,
    bool? isSafetyVerified,
    ConversationStatus? status,
  }) {
    return Conversation(
      id: id ?? this.id,
      isGroup: isGroup ?? this.isGroup,
      title: title ?? this.title,
      participantIds: participantIds ?? this.participantIds,
      messages: messages ?? this.messages,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      status: status ?? this.status,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      ephemeralRetentionSeconds:
          ephemeralRetentionSeconds ?? this.ephemeralRetentionSeconds,
      pinnedMessageIds: pinnedMessageIds ?? this.pinnedMessageIds,
      isSavedMessages: isSavedMessages ?? this.isSavedMessages,
      isCommunity: isCommunity ?? this.isCommunity,
      channels: channels ?? this.channels,
      description: description ?? this.description,
      adminIds: adminIds ?? this.adminIds,
      creatorId: creatorId ?? this.creatorId,
      privateContactNotes: privateContactNotes ?? this.privateContactNotes,
      isSafetyVerified: isSafetyVerified ?? this.isSafetyVerified,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'isGroup': isGroup,
      'title': title,
      'participantIds': participantIds,
      'messages': messages.map((message) => message.toMap()).toList(),
      'lastMessageId': lastMessageId,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      'lastMessageAt': lastMessageAt?.toUtc().toIso8601String(),
      'unreadCount': unreadCount,
      'status': status.name,
      'isPinned': isPinned,
      'isMuted': isMuted,
      if (ephemeralRetentionSeconds != null)
        'ephemeralRetentionSeconds': ephemeralRetentionSeconds,
      if (pinnedMessageIds.isNotEmpty) 'pinnedMessageIds': pinnedMessageIds,
      'isSavedMessages': isSavedMessages,
      'isCommunity': isCommunity,
      if (channels.isNotEmpty) 'channels': channels,
      if (description != null) 'description': description,
      if (adminIds.isNotEmpty) 'adminIds': adminIds,
      if (creatorId != null) 'creatorId': creatorId,
      if (privateContactNotes != null) 'privateContactNotes': privateContactNotes,
      'isSafetyVerified': isSafetyVerified,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'] as String,
      isGroup: map['isGroup'] as bool? ?? false,
      title: map['title'] as String? ?? '',
      participantIds: List<String>.from(
        map['participantIds'] as List? ?? const [],
      ),
      messages: (map['messages'] as List? ?? const [])
          .map((message) => Message.fromMap(message as Map<String, dynamic>))
          .toList(),
      lastMessageId: map['lastMessageId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updatedAt'] as String).toLocal(),
      lastMessageAt: map['lastMessageAt'] == null
          ? null
          : DateTime.parse(map['lastMessageAt'] as String).toLocal(),
      unreadCount: map['unreadCount'] as int? ?? 0,
      status: ConversationStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => ConversationStatus.active,
      ),
      isPinned: map['isPinned'] as bool? ?? false,
      isMuted: map['isMuted'] as bool? ?? false,
      ephemeralRetentionSeconds: map['ephemeralRetentionSeconds'] as int?,
      pinnedMessageIds: List<String>.from(
        map['pinnedMessageIds'] as List? ?? const [],
      ),
      isSavedMessages: map['isSavedMessages'] as bool? ?? false,
      isCommunity: map['isCommunity'] as bool? ?? false,
      channels: List<String>.from(
        map['channels'] as List? ?? (map['isCommunity'] == true ? ['geral'] : const []),
      ),
      description: map['description'] as String?,
      adminIds: List<String>.from(map['adminIds'] as List? ?? const []),
      creatorId: map['creatorId'] as String?,
      privateContactNotes: map['privateContactNotes'] as String?,
      isSafetyVerified: map['isSafetyVerified'] as bool? ?? false,
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Conversation.fromJson(String source) {
    return Conversation.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
