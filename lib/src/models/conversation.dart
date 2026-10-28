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
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Conversation.fromJson(String source) {
    return Conversation.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
