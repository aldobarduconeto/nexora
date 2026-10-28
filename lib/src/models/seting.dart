import 'dart:convert';

/// Only preferences with an implemented effect are persisted.
class Setting {
  final bool isDarkMode;
  final String accentColor;
  final double fontSize;
  final bool animationsEnabled;
  final int connectionTimeoutSeconds;
  final int localRetentionMinutes;

  const Setting({
    this.isDarkMode = true,
    this.accentColor = 'mint',
    this.fontSize = 14,
    this.animationsEnabled = true,
    this.connectionTimeoutSeconds = 30,
    this.localRetentionMinutes = 0,
  });

  Setting copyWith({
    bool? isDarkMode,
    String? accentColor,
    double? fontSize,
    bool? animationsEnabled,
    int? connectionTimeoutSeconds,
    int? localRetentionMinutes,
  }) => Setting(
    isDarkMode: isDarkMode ?? this.isDarkMode,
    accentColor: accentColor ?? this.accentColor,
    fontSize: fontSize ?? this.fontSize,
    animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    connectionTimeoutSeconds:
        connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
    localRetentionMinutes: localRetentionMinutes ?? this.localRetentionMinutes,
  );

  Map<String, dynamic> toMap() => {
    'v': 3,
    'd': isDarkMode,
    'c': accentColor,
    'f': fontSize,
    'a': animationsEnabled,
    'ct': connectionTimeoutSeconds,
    'rm': localRetentionMinutes,
  };

  factory Setting.fromMap(Map<String, dynamic> map) {
    if (map['v'] != 3 ||
        map['d'] is! bool ||
        map['a'] is! bool ||
        !const ['mint', 'blue', 'purple'].contains(map['c']) ||
        map['f'] is! num ||
        (map['f'] as num) < 12 ||
        (map['f'] as num) > 22 ||
        !const [10, 20, 30, 45, 60].contains(map['ct']) ||
        !const [
          -1,
          0,
          1,
          5,
          30,
          60,
          1440,
          10080,
          43200,
          129600,
          259200,
          525600,
        ].contains(map['rm'])) {
      throw const FormatException('Formato de configurações não suportado.');
    }
    return Setting(
      isDarkMode: map['d'] as bool,
      accentColor: map['c'] as String,
      fontSize: (map['f'] as num).toDouble(),
      animationsEnabled: map['a'] as bool,
      connectionTimeoutSeconds: map['ct'] as int,
      localRetentionMinutes: map['rm'] as int,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Setting.fromJson(String source) =>
      Setting.fromMap(jsonDecode(source) as Map<String, dynamic>);
  static const defaults = Setting();
}
