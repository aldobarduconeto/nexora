import 'dart:convert';

/// Configurações do aplicativo com suporte avançado a personalização de layout,
/// temas, mensagens, envio agendado, conexões P2P e privacidade.
class Setting {
  final String languageCode;
  final bool isDarkMode;
  final bool isAmoledMode;
  final String accentColor; // 'mint', 'blue', 'purple', 'amber', 'crimson', 'monochrome'
  final double fontSize;
  final bool animationsEnabled;
  final int connectionTimeoutSeconds;
  final int localRetentionMinutes;

  // Personalização de layout e experiência visual
  final String navigationStyle; // 'auto', 'side', 'bottom'
  final String layoutDensity; // 'comfortable', 'compact'
  final String chatBubbleStyle; // 'modern', 'minimal', 'bubble'
  final String chatWallpaper; // 'none', 'mesh', 'grid', 'dots'
  final bool stealthMode; // Modo furtivo com proteção anti-ombro (blur temporário)
  final double cardRadius; // 8.0 (discreto), 16.0 (moderno), 24.0 (suave)
  final bool showSecurityInspector; // HUD de métricas criptográficas no chat
  final bool showTimestamps; // Exibir horários detalhados abaixo das bolhas

  // Mensagens e Envio
  final bool enterIsSend; // Pressionar Enter no teclado físico envia a mensagem
  final bool confirmBeforeSendingMedia; // Exibir confirmação antes de transferir mídias/arquivos
  final bool scheduledMessagesNotification; // Notificar ao disparar mensagens agendadas
  final bool hapticFeedback; // Vibração e retorno tátil ao tocar e enviar

  // Notificações e boas-vindas / onboarding
  final bool hasCompletedWelcome; // Se o usuário já concluiu o onboarding de boas-vindas
  final bool notificationsEnabled; // Notificações push gerais
  final bool notificationSound; // Alerta sonoro
  final bool notificationPreview; // Exibir prévia de texto na notificação

  // Opções específicas para Comunidades P2P
  final String communityNotificationsMode; // 'all', 'mentions', 'none'
  final bool communityAutoJoinChannels; // Sincronizar e entrar automaticamente em novos canais criados
  final bool communityMediaAutoDownload; // Download automático de mídia em comunidades
  final bool allowCommunityInvites; // Permitir receber convites de comunidades
  final int communitySlowModeSeconds; // Modo lento local / intervalo entre mensagens (0, 5, 15, 30s)

  // Streaming de Vídeo & Chamadas P2P (Até 4K@60fps para todos os usuários)
  final String videoStreamingPreset; // '4k60', '4k30', '2k60', '1080p60', '1080p30', '720p30', '480p24'
  final bool enable4kStreaming; // Habilita resolução Ultra HD 4K@60fps nativa
  final bool videoHardwareAcceleration; // Aceleração de hardware/GPU para codificação/decodificação

  // Conexão P2P avançada, privacidade e armazenamento
  final String stunServer; // Servidor STUN/ICE para bypass de NAT
  final bool biometricsEnabled; // Bloqueio por biometria / PIN
  final bool autoDownloadFiles; // Download automático de arquivos até 5MB
  final bool readReceipts; // Confirmação de leitura e recebimento
  final bool linkPreviews; // Pré-visualização de links da web (off preserva IP/DNS)
  final bool p2pDataSaver; // Modo economia de dados P2P
  final int keepAliveIntervalSeconds; // Frequência do Keep-Alive WebRTC (5, 10, 15, 30s)
  final bool autoReconnectP2P; // Tentativa automática de reconectar ao par

  const Setting({
    this.languageCode = '',
    this.isDarkMode = true,
    this.isAmoledMode = false,
    this.accentColor = 'mint',
    this.fontSize = 14,
    this.animationsEnabled = true,
    this.connectionTimeoutSeconds = 30,
    this.localRetentionMinutes = 0,
    this.navigationStyle = 'auto',
    this.layoutDensity = 'comfortable',
    this.chatBubbleStyle = 'modern',
    this.chatWallpaper = 'mesh',
    this.stealthMode = false,
    this.cardRadius = 16.0,
    this.showSecurityInspector = true,
    this.showTimestamps = true,
    this.enterIsSend = false,
    this.confirmBeforeSendingMedia = true,
    this.scheduledMessagesNotification = true,
    this.hapticFeedback = true,
    this.hasCompletedWelcome = false,
    this.notificationsEnabled = true,
    this.notificationSound = true,
    this.notificationPreview = true,
    this.communityNotificationsMode = 'mentions',
    this.communityAutoJoinChannels = true,
    this.communityMediaAutoDownload = false,
    this.allowCommunityInvites = true,
    this.communitySlowModeSeconds = 0,
    this.videoStreamingPreset = '4k60',
    this.enable4kStreaming = true,
    this.videoHardwareAcceleration = true,
    this.stunServer = 'stun:stun.l.google.com:19302',
    this.biometricsEnabled = false,
    this.autoDownloadFiles = false,
    this.readReceipts = true,
    this.linkPreviews = false,
    this.p2pDataSaver = false,
    this.keepAliveIntervalSeconds = 15,
    this.autoReconnectP2P = true,
  });

  Setting copyWith({
    String? languageCode,
    bool? isDarkMode,
    bool? isAmoledMode,
    String? accentColor,
    double? fontSize,
    bool? animationsEnabled,
    int? connectionTimeoutSeconds,
    int? localRetentionMinutes,
    String? navigationStyle,
    String? layoutDensity,
    String? chatBubbleStyle,
    String? chatWallpaper,
    bool? stealthMode,
    double? cardRadius,
    bool? showSecurityInspector,
    bool? showTimestamps,
    bool? enterIsSend,
    bool? confirmBeforeSendingMedia,
    bool? scheduledMessagesNotification,
    bool? hapticFeedback,
    bool? hasCompletedWelcome,
    bool? notificationsEnabled,
    bool? notificationSound,
    bool? notificationPreview,
    String? communityNotificationsMode,
    bool? communityAutoJoinChannels,
    bool? communityMediaAutoDownload,
    bool? allowCommunityInvites,
    int? communitySlowModeSeconds,
    String? videoStreamingPreset,
    bool? enable4kStreaming,
    bool? videoHardwareAcceleration,
    String? stunServer,
    bool? biometricsEnabled,
    bool? autoDownloadFiles,
    bool? readReceipts,
    bool? linkPreviews,
    bool? p2pDataSaver,
    int? keepAliveIntervalSeconds,
    bool? autoReconnectP2P,
  }) => Setting(
    languageCode: languageCode ?? this.languageCode,
    isDarkMode: isDarkMode ?? this.isDarkMode,
    isAmoledMode: isAmoledMode ?? this.isAmoledMode,
    accentColor: accentColor ?? this.accentColor,
    fontSize: fontSize ?? this.fontSize,
    animationsEnabled: animationsEnabled ?? this.animationsEnabled,
    connectionTimeoutSeconds:
        connectionTimeoutSeconds ?? this.connectionTimeoutSeconds,
    localRetentionMinutes: localRetentionMinutes ?? this.localRetentionMinutes,
    navigationStyle: navigationStyle ?? this.navigationStyle,
    layoutDensity: layoutDensity ?? this.layoutDensity,
    chatBubbleStyle: chatBubbleStyle ?? this.chatBubbleStyle,
    chatWallpaper: chatWallpaper ?? this.chatWallpaper,
    stealthMode: stealthMode ?? this.stealthMode,
    cardRadius: cardRadius ?? this.cardRadius,
    showSecurityInspector:
        showSecurityInspector ?? this.showSecurityInspector,
    showTimestamps: showTimestamps ?? this.showTimestamps,
    enterIsSend: enterIsSend ?? this.enterIsSend,
    confirmBeforeSendingMedia:
        confirmBeforeSendingMedia ?? this.confirmBeforeSendingMedia,
    scheduledMessagesNotification:
        scheduledMessagesNotification ?? this.scheduledMessagesNotification,
    hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    hasCompletedWelcome: hasCompletedWelcome ?? this.hasCompletedWelcome,
    notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
    notificationSound: notificationSound ?? this.notificationSound,
    notificationPreview: notificationPreview ?? this.notificationPreview,
    communityNotificationsMode:
        communityNotificationsMode ?? this.communityNotificationsMode,
    communityAutoJoinChannels:
        communityAutoJoinChannels ?? this.communityAutoJoinChannels,
    communityMediaAutoDownload:
        communityMediaAutoDownload ?? this.communityMediaAutoDownload,
    allowCommunityInvites:
        allowCommunityInvites ?? this.allowCommunityInvites,
    communitySlowModeSeconds:
        communitySlowModeSeconds ?? this.communitySlowModeSeconds,
    videoStreamingPreset: videoStreamingPreset ?? this.videoStreamingPreset,
    enable4kStreaming: enable4kStreaming ?? this.enable4kStreaming,
    videoHardwareAcceleration:
        videoHardwareAcceleration ?? this.videoHardwareAcceleration,
    stunServer: stunServer ?? this.stunServer,
    biometricsEnabled: biometricsEnabled ?? this.biometricsEnabled,
    autoDownloadFiles: autoDownloadFiles ?? this.autoDownloadFiles,
    readReceipts: readReceipts ?? this.readReceipts,
    linkPreviews: linkPreviews ?? this.linkPreviews,
    p2pDataSaver: p2pDataSaver ?? this.p2pDataSaver,
    keepAliveIntervalSeconds:
        keepAliveIntervalSeconds ?? this.keepAliveIntervalSeconds,
    autoReconnectP2P: autoReconnectP2P ?? this.autoReconnectP2P,
  );

  Map<String, dynamic> toMap() => {
    'v': 5,
    'languageCode': languageCode,
    'd': isDarkMode,
    'am': isAmoledMode,
    'c': accentColor,
    'f': fontSize,
    'a': animationsEnabled,
    'ct': connectionTimeoutSeconds,
    'rm': localRetentionMinutes,
    'ns': navigationStyle,
    'ld': layoutDensity,
    'cbs': chatBubbleStyle,
    'cw': chatWallpaper,
    'sm': stealthMode,
    'cr': cardRadius,
    'si': showSecurityInspector,
    'st': showTimestamps,
    'eis': enterIsSend,
    'cbsm': confirmBeforeSendingMedia,
    'smn': scheduledMessagesNotification,
    'hf': hapticFeedback,
    'hcw': hasCompletedWelcome,
    'ne': notificationsEnabled,
    'nsound': notificationSound,
    'np': notificationPreview,
    'cnm': communityNotificationsMode,
    'cajc': communityAutoJoinChannels,
    'cmad': communityMediaAutoDownload,
    'aci': allowCommunityInvites,
    'csms': communitySlowModeSeconds,
    'vsp': videoStreamingPreset,
    'e4k': enable4kStreaming,
    'vha': videoHardwareAcceleration,
    'stun': stunServer,
    'bio': biometricsEnabled,
    'adf': autoDownloadFiles,
    'rr': readReceipts,
    'lp': linkPreviews,
    'pds': p2pDataSaver,
    'kai': keepAliveIntervalSeconds,
    'arp': autoReconnectP2P,
  };

  factory Setting.fromMap(Map<String, dynamic> map) {
    // Validadores com fallback amigável
    final rawColor = map['c'] as String? ?? 'mint';
    final accentColor = const [
      'mint',
      'blue',
      'purple',
      'amber',
      'crimson',
      'monochrome',
    ].contains(rawColor)
        ? rawColor
        : 'mint';

    final rawFontSize = (map['f'] is num) ? (map['f'] as num).toDouble() : 14.0;
    final fontSize = rawFontSize.clamp(12.0, 22.0);

    final rawCt = map['ct'] as int? ?? 30;
    final connectionTimeoutSeconds =
        const [10, 20, 30, 45, 60].contains(rawCt) ? rawCt : 30;

    final rawRm = map['rm'] as int? ?? 0;
    final validRetention = const [
      -1, 0, 1, 5, 30, 60, 1440, 10080, 43200, 129600, 259200, 525600,
    ].contains(rawRm)
        ? rawRm
        : 0;

    final rawNav = map['ns'] as String? ?? 'auto';
    final navigationStyle =
        const ['auto', 'side', 'bottom'].contains(rawNav) ? rawNav : 'auto';

    final rawDensity = map['ld'] as String? ?? 'comfortable';
    final layoutDensity =
        const ['comfortable', 'compact'].contains(rawDensity)
            ? rawDensity
            : 'comfortable';

    final rawBubble = map['cbs'] as String? ?? 'modern';
    final chatBubbleStyle =
        const ['modern', 'minimal', 'bubble'].contains(rawBubble)
            ? rawBubble
            : 'modern';

    final rawWallpaper = map['cw'] as String? ?? 'mesh';
    final chatWallpaper =
        const ['none', 'mesh', 'grid', 'dots'].contains(rawWallpaper)
            ? rawWallpaper
            : 'mesh';

    final rawRadius = (map['cr'] is num) ? (map['cr'] as num).toDouble() : 16.0;
    final cardRadius = rawRadius.clamp(6.0, 28.0);

    final rawKai = map['kai'] as int? ?? 15;
    final keepAliveIntervalSeconds =
        const [5, 10, 15, 30].contains(rawKai) ? rawKai : 15;

    final rawCnm = map['cnm'] as String? ?? 'mentions';
    final communityNotificationsMode =
        const ['all', 'mentions', 'none'].contains(rawCnm) ? rawCnm : 'mentions';

    final rawCsms = map['csms'] as int? ?? 0;
    final communitySlowModeSeconds =
        const [0, 5, 15, 30, 60].contains(rawCsms) ? rawCsms : 0;

    final rawVsp = map['vsp'] as String? ?? '4k60';
    final videoStreamingPreset = const [
      '4k60',
      '4k30',
      '2k60',
      '1080p60',
      '1080p30',
      '720p30',
      '480p24',
    ].contains(rawVsp)
        ? rawVsp
        : '4k60';

    return Setting(
      languageCode: map['languageCode'] is String
          ? map['languageCode'] as String
          : '',
      isDarkMode: map['d'] as bool? ?? true,
      isAmoledMode: map['am'] as bool? ?? false,
      accentColor: accentColor,
      fontSize: fontSize,
      animationsEnabled: map['a'] as bool? ?? true,
      connectionTimeoutSeconds: connectionTimeoutSeconds,
      localRetentionMinutes: validRetention,
      navigationStyle: navigationStyle,
      layoutDensity: layoutDensity,
      chatBubbleStyle: chatBubbleStyle,
      chatWallpaper: chatWallpaper,
      stealthMode: map['sm'] as bool? ?? false,
      cardRadius: cardRadius,
      showSecurityInspector: map['si'] as bool? ?? true,
      showTimestamps: map['st'] as bool? ?? true,
      enterIsSend: map['eis'] as bool? ?? false,
      confirmBeforeSendingMedia: map['cbsm'] as bool? ?? true,
      scheduledMessagesNotification: map['smn'] as bool? ?? true,
      hapticFeedback: map['hf'] as bool? ?? true,
      hasCompletedWelcome: map['hcw'] as bool? ?? false,
      notificationsEnabled: map['ne'] as bool? ?? true,
      notificationSound: map['nsound'] as bool? ?? true,
      notificationPreview: map['np'] as bool? ?? true,
      communityNotificationsMode: communityNotificationsMode,
      communityAutoJoinChannels: map['cajc'] as bool? ?? true,
      communityMediaAutoDownload: map['cmad'] as bool? ?? false,
      allowCommunityInvites: map['aci'] as bool? ?? true,
      communitySlowModeSeconds: communitySlowModeSeconds,
      videoStreamingPreset: videoStreamingPreset,
      enable4kStreaming: map['e4k'] as bool? ?? true,
      videoHardwareAcceleration: map['vha'] as bool? ?? true,
      stunServer: map['stun'] as String? ?? 'stun:stun.l.google.com:19302',
      biometricsEnabled: map['bio'] as bool? ?? false,
      autoDownloadFiles: map['adf'] as bool? ?? false,
      readReceipts: map['rr'] as bool? ?? true,
      linkPreviews: map['lp'] as bool? ?? false,
      p2pDataSaver: map['pds'] as bool? ?? false,
      keepAliveIntervalSeconds: keepAliveIntervalSeconds,
      autoReconnectP2P: map['arp'] as bool? ?? true,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Setting.fromJson(String source) {
    try {
      return Setting.fromMap(jsonDecode(source) as Map<String, dynamic>);
    } catch (_) {
      return Setting.defaults;
    }
  }

  static const defaults = Setting();
}
