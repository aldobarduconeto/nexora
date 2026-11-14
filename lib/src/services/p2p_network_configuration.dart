/// Política de rede do serviço: STUN descobre endereços, nunca retransmite chat.
/// Em produção, configure um STUN da sua infraestrutura com --dart-define.
class P2PNetworkConfiguration {
  P2PNetworkConfiguration({
    required Iterable<String> stunUrls,
    this.relayOnly = false,
    Iterable<String> turnUrls = const [],
    this.turnUsername = '',
    this.turnCredential = '',
  }) : stunUrls = List.unmodifiable(stunUrls.map(_validateStunUrl)),
       turnUrls = List.unmodifiable(turnUrls.map(_validateTurnUrl)) {
    if (relayOnly &&
        (this.turnUrls.isEmpty ||
            turnUsername.trim().isEmpty ||
            turnCredential.trim().isEmpty)) {
      throw ArgumentError(
        'O modo privado exige TURN com usuário e credencial.',
      );
    }
  }

  factory P2PNetworkConfiguration.fromEnvironment() {
    const urls = String.fromEnvironment(
      'NEXORA_STUN_URLS',
      defaultValue: 'stun:stun.cloudflare.com:3478,stun:global.stun.twilio.com:3478,stun:stun.nextcloud.com:443,stun:stun.sipgate.net:3478',
    );
    return P2PNetworkConfiguration(
      relayOnly: const bool.fromEnvironment('NEXORA_RELAY_ONLY'),
      turnUrls: const String.fromEnvironment('NEXORA_TURN_URLS')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty),
      turnUsername: const String.fromEnvironment('NEXORA_TURN_USERNAME'),
      turnCredential: const String.fromEnvironment('NEXORA_TURN_CREDENTIAL'),
      stunUrls: urls
          .split(',')
          .map((url) => url.trim())
          .where((url) => url.isNotEmpty),
    );
  }

  final List<String> stunUrls;
  final List<String> turnUrls;
  final bool relayOnly;
  final String turnUsername;
  final String turnCredential;

  /// Do not export local or related addresses in relay-only signaling.
  String signalingSdp(String sdp) {
    if (!relayOnly) return sdp;
    var hasRelay = false;
    final lines = <String>[];
    for (var line in sdp.split(RegExp(r'\r?\n'))) {
      if (line.startsWith('a=candidate:')) {
        if (!RegExp(r'\styp relay(?:\s|$)').hasMatch(line)) continue;
        hasRelay = true;
        line = line
            .replaceAll(RegExp(r' raddr \S+'), ' raddr 0.0.0.0')
            .replaceAll(RegExp(r' rport \d+'), ' rport 0');
      }
      if (line.startsWith('a=remote-candidates:')) continue;
      if (line.startsWith('c=IN IP')) line = 'c=IN IP4 0.0.0.0';
      if (line.startsWith('o=')) {
        line = line.replaceFirst(RegExp(r'IN IP[46] \S+'), 'IN IP4 0.0.0.0');
      }
      if (line.isNotEmpty) lines.add(line);
    }
    if (!hasRelay)
      throw StateError(
        'Nenhum candidato TURN disponível. A conexão direta permanece desativada.',
      );
    return '${lines.join('\r\n')}\r\n';
  }

  static String _validateTurnUrl(String value) {
    final match = RegExp(
      r'^turns?:(\[[0-9a-fA-F:]+\]|[a-zA-Z0-9][a-zA-Z0-9.-]*)(?::([0-9]{1,5}))?(?:\?transport=(?:udp|tcp))?$',
    ).firstMatch(value);
    final port = match?.group(2);
    if (match == null ||
        (port != null && (int.parse(port) < 1 || int.parse(port) > 65535))) {
      throw ArgumentError('URL TURN inválida.');
    }
    return value;
  }

  static String _validateStunUrl(String value) {
    // URI STUN usa autoridade sem //, conforme RFC 7064. Rejeitamos TURN,
    // credenciais e parâmetros para manter a política de P2P direto.
    final match = RegExp(
      r'^stun:(\[[0-9a-fA-F:]+\]|[a-zA-Z0-9](?:[a-zA-Z0-9.-]*[a-zA-Z0-9])?)(?::([0-9]{1,5}))?$',
    ).firstMatch(value);
    if (match == null) {
      throw ArgumentError(
        'Informe uma URL STUN válida, sem credenciais ou relay.',
      );
    }
    final port = match.group(2);
    if (port != null && (int.parse(port) < 1 || int.parse(port) > 65535)) {
      throw ArgumentError('Porta STUN inválida.');
    }
    return value;
  }

  Map<String, dynamic> toWebRtcConfiguration() => {
    'iceServers': [
      if (!relayOnly && stunUrls.isNotEmpty)
        {'urls': List<String>.of(stunUrls)},
      if (turnUrls.isNotEmpty)
        {
          'urls': List<String>.of(turnUrls),
          'username': turnUsername,
          'credential': turnCredential,
        },
    ],
    'iceTransportPolicy': relayOnly ? 'relay' : 'all',
  };
}
