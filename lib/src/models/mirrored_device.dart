import 'dart:convert';

class MirroredDevice {
  final String id;
  final String name;
  final String platform;
  final DateTime pairedAt;
  final DateTime lastActiveAt;

  const MirroredDevice({
    required this.id,
    required this.name,
    required this.platform,
    required this.pairedAt,
    required this.lastActiveAt,
  });

  MirroredDevice copyWith({
    String? id,
    String? name,
    String? platform,
    DateTime? pairedAt,
    DateTime? lastActiveAt,
  }) {
    return MirroredDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      pairedAt: pairedAt ?? this.pairedAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'pairedAt': pairedAt.toUtc().toIso8601String(),
      'lastActiveAt': lastActiveAt.toUtc().toIso8601String(),
    };
  }

  factory MirroredDevice.fromMap(Map<String, dynamic> map) {
    return MirroredDevice(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Dispositivo desconhecido',
      platform: map['platform'] as String? ?? 'unknown',
      pairedAt: map['pairedAt'] is String
          ? DateTime.parse(map['pairedAt'] as String).toLocal()
          : DateTime.now(),
      lastActiveAt: map['lastActiveAt'] is String
          ? DateTime.parse(map['lastActiveAt'] as String).toLocal()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory MirroredDevice.fromJson(String source) {
    return MirroredDevice.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }
}
