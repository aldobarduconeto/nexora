class CommunityVoiceRoom {
  const CommunityVoiceRoom(this.name, this.label);

  static const lobby = CommunityVoiceRoom('lobby', 'Sala geral');
  static const lounge = CommunityVoiceRoom('lounge', 'Convivência');
  static const meeting = CommunityVoiceRoom('meeting', 'Reunião');
  static const defaults = [lobby, lounge, meeting];

  final String name;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is CommunityVoiceRoom && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

class CommunityRoomChange {
  const CommunityRoomChange({
    required this.id,
    required this.name,
    required this.voice,
    required this.author,
    required this.revision,
    this.aliases = const [],
  });

  final String id;
  final String name;
  final bool voice;
  final String author;
  final int revision;
  final List<String> aliases;

  static String normalizeName(String name, {required bool voice}) {
    final normalized = name.trim().replaceAll(
      RegExp(r'\s+'),
      voice ? ' ' : '-',
    );
    return voice ? normalized : normalized.toLowerCase();
  }

  static bool validVoiceId(String id) =>
      RegExp(r'^(lobby|lounge|meeting|v-[a-f0-9-]{36})$').hasMatch(id);

  bool replaces(CommunityRoomChange other) =>
      revision > other.revision ||
      (revision == other.revision && author.compareTo(other.author) > 0);

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'voice': voice,
    'author': author,
    'revision': revision,
    if (aliases.isNotEmpty) 'aliases': aliases,
  };

  factory CommunityRoomChange.fromMap(Map<String, dynamic> map) {
    final voice = map['voice'] as bool;
    final name = map['name'] as String;
    final id = map['id'] as String;
    final revision = map['revision'] as int;
    final aliases = List<String>.from(map['aliases'] as List? ?? const []);
    if (name.isEmpty ||
        name.length > (voice ? 40 : 32) ||
        name != normalizeName(name, voice: voice) ||
        revision < 1 ||
        revision >= 9007199254740991 ||
        (voice ? !validVoiceId(id) : !id.startsWith('t:') || id.length > 128) ||
        aliases.length > 100 ||
        aliases.any((alias) => alias.isEmpty || alias.length > 100)) {
      throw const FormatException('Sala inválida.');
    }
    return CommunityRoomChange(
      id: id,
      name: name,
      voice: voice,
      author: map['author'] as String,
      revision: revision,
      aliases: aliases,
    );
  }
}
