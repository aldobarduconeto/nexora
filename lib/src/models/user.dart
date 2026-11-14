import 'dart:convert';

class User {
  final String id;
  final String nickname;
  final String publicKey;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isActive;
  final List<String> blockedUserIds;

  const User({
    required this.id,
    required this.nickname,
    required this.publicKey,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isActive,
    required this.blockedUserIds,
  });

  User copyWith({
    String? id,
    String? nickname,
    String? publicKey,
    DateTime? createdAt,
    DateTime? lastSeenAt,
    bool? isActive,
    List<String>? blockedUserIds,
    required bool clearNickname,
  }) {
    return User(
      id: id ?? this.id,
      nickname: clearNickname ? '' : (nickname ?? this.nickname),
      publicKey: publicKey ?? this.publicKey,
      createdAt: createdAt ?? this.createdAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
      isActive: isActive ?? this.isActive,
      blockedUserIds: blockedUserIds ?? this.blockedUserIds,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nickname': nickname,
      'publicKey': publicKey,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
      'isActive': isActive,
      'blockedUserIds': blockedUserIds,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      nickname: map['nickname'] as String,
      publicKey: map['publicKey'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String).toLocal(),
      lastSeenAt: DateTime.parse(map['lastSeenAt'] as String).toLocal(),
      isActive: map['isActive'] as bool? ?? false,
      blockedUserIds: List<String>.from(
        map['blockedUserIds'] as List? ?? const [],
      ),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory User.fromJson(String source) {
    return User.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
