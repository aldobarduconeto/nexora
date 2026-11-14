import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:nexora/src/services/conversation_connection_service.dart';
import 'package:nexora/src/services/local_data_service.dart';
import 'package:nexora/src/services/p2p_connection_service.dart';

/// Prompts the user to select a screen or window on Desktop, or returns `(proceed: true, source: null)`
/// when the platform/browser handles its own screen picker.
Future<({bool proceed, DesktopCapturerSource? source})> pickScreenShareSource(
  BuildContext context,
) async {
  final sources = await P2PMediaSession.getDesktopSources();
  if (sources.isEmpty) {
    return (proceed: true, source: null);
  }
  if (sources.length == 1) {
    return (proceed: true, source: sources.first);
  }
  if (!context.mounted) return (proceed: false, source: null);

  final selected = await showDialog<DesktopCapturerSource>(
    context: context,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;
      return AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.present_to_all_rounded, size: 22),
            SizedBox(width: 10),
            Expanded(child: Text('Escolher tela ou janela para transmitir')),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .6,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sources.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final src = sources[index];
                final isScreen = src.type == SourceType.Screen;
                final thumb = src.thumbnail;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 64,
                      height: 44,
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colors.outlineVariant),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: thumb != null && thumb.isNotEmpty
                          ? Image.memory(thumb, fit: BoxFit.cover)
                          : Icon(
                              isScreen
                                  ? Icons.desktop_windows_rounded
                                  : Icons.web_asset_rounded,
                              color: colors.primary,
                              size: 22,
                            ),
                    ),
                    title: Text(
                      src.name.isEmpty
                          ? (isScreen
                                ? 'Tela ${index + 1}'
                                : 'Janela ${index + 1}')
                          : src.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    subtitle: Text(
                      isScreen ? 'Tela inteira' : 'Janela de aplicativo',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.pop(dialogContext, src),
                  ),
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      );
    },
  );

  return (proceed: selected != null, source: selected);
}

/// Diálogo/Sheet moderno e clean para o usuário escolher em qual resolução transmitir (até 4K@60fps).
/// Pode ser acionado antes de iniciar videochamada ou compartilhamento de tela, ou durante a chamada.
Future<VideoStreamPreset?> pickVideoStreamPreset(
  BuildContext context, {
  VideoStreamPreset? current,
  bool forScreenShare = false,
  String? title,
}) async {
  final defaultPreset = current ?? VideoStreamPreset.ultra4k60;
  if (!context.mounted) return null;

  final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  Widget buildContent(
    BuildContext dialogContext,
    void Function(VideoStreamPreset) onSelect,
  ) {
    final colors = Theme.of(dialogContext).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.28),
                ),
              ),
              child: Icon(
                forScreenShare
                    ? Icons.present_to_all_rounded
                    : Icons.four_k_rounded,
                color: colors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ??
                        (forScreenShare
                            ? 'Qualidade de Transmissão de Tela'
                            : 'Qualidade de Câmera & Vídeo'),
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Selecione a resolução e taxa de quadros (P2P direto até 4K@60fps):',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: VideoStreamPreset.values.length,
            separatorBuilder: (_, _) => const SizedBox(height: 7),
            itemBuilder: (context, index) {
              final preset = VideoStreamPreset.values[index];
              final isSelected = preset == defaultPreset;
              final is4k = preset == VideoStreamPreset.ultra4k60 ||
                  preset == VideoStreamPreset.ultra4k30;
              final is60fps = preset.frameRate == 60;
              return Material(
                color: isSelected
                    ? colors.primary.withValues(alpha: 0.12)
                    : colors.surfaceContainerHighest.withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isSelected
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.5),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onSelect(preset),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? colors.primary.withValues(alpha: 0.22)
                                : colors.surfaceContainerHighest,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            is4k
                                ? Icons.diamond_rounded
                                : (is60fps
                                    ? Icons.bolt_rounded
                                    : Icons.hd_rounded),
                            color: isSelected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    preset.label,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  if (is4k) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.primary.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '4K MAX',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (is60fps && !is4k) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF62E0BD).withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        '60 FPS',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF62E0BD),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${preset.width}×${preset.height} px • ${preset.frameRate} fps • Até ${(preset.bitrateKbps / 1000).toStringAsFixed(0)} Mbps',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle_rounded,
                            color: colors.primary,
                            size: 22,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  if (isDesktop) {
    return showDialog<VideoStreamPreset>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        content: SizedBox(
          width: 500,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.75,
            ),
            child: buildContent(
              dialogContext,
              (p) => Navigator.pop(dialogContext, p),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  return showModalBottomSheet<VideoStreamPreset>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final colors = Theme.of(sheetContext).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.outlineVariant.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: buildContent(
                    sheetContext,
                    (p) => Navigator.pop(sheetContext, p),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class CallPanel extends StatefulWidget {
  const CallPanel({
    super.key,
    required this.connection,
    required this.peerName,
    required this.onError,
  });

  final ConversationConnectionService connection;
  final String peerName;
  final ValueChanged<Object> onError;

  @override
  State<CallPanel> createState() => _CallPanelState();
}

class _CallPanelState extends State<CallPanel> {
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  final _user = LocalDataService.instance;
  bool _renderersInitialized = false;
  bool _minimized = false;
  bool _fitContain = false;
  bool _busy = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.connection.addListener(_onConnectionChanged);
    unawaited(_initRenderers());
    _startTimerIfNeeded();
  }

  Future<void> _initRenderers() async {
    try {
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      if (!mounted) return;
      setState(() => _renderersInitialized = true);
      _syncStreams();
    } catch (_) {}
  }

  void _syncStreams() {
    if (!_renderersInitialized) return;
    if (_localRenderer.srcObject != widget.connection.localStream) {
      _localRenderer.srcObject = widget.connection.localStream;
    }
    if (_remoteRenderer.srcObject != widget.connection.remoteStream) {
      _remoteRenderer.srcObject = widget.connection.remoteStream;
    }
  }

  void _onConnectionChanged() {
    if (!mounted) return;
    _syncStreams();
    _startTimerIfNeeded();
    if (!widget.connection.isInCall) {
      _minimized = false;
      _fitContain = false;
    } else if (widget.connection.isRemoteScreenSharing) {
      _fitContain = true;
    }
    setState(() {});
  }

  void _startTimerIfNeeded() {
    if (widget.connection.callState == P2PCallState.active) {
      _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void didUpdateWidget(covariant CallPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.connection != widget.connection) {
      oldWidget.connection.removeListener(_onConnectionChanged);
      widget.connection.addListener(_onConnectionChanged);
      _syncStreams();
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.connection.removeListener(_onConnectionChanged);
    _localRenderer.srcObject = null;
    _remoteRenderer.srcObject = null;
    unawaited(_localRenderer.dispose());
    unawaited(_remoteRenderer.dispose());
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (error) {
      if (mounted) widget.onError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleToggleScreenShare() async {
    if (widget.connection.isScreenSharing) {
      await _runAction(widget.connection.stopScreenShare);
      return;
    }
    final picked = await pickScreenShareSource(context);
    if (!picked.proceed || !mounted) return;
    await _runAction(
      () => widget.connection.toggleScreenShare(source: picked.source),
    );
  }

  Future<void> _openFullscreenViewer() async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              InteractiveViewer(
                minScale: 1.0,
                maxScale: 4.0,
                child: Center(
                  child: RTCVideoView(
                    _remoteRenderer,
                    objectFit:
                        RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                  ),
                ),
              ),
              Positioned(
                top: 14,
                left: 16,
                right: 16,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            widget.connection.isRemoteScreenSharing
                                ? Icons.present_to_all_rounded
                                : Icons.videocam_rounded,
                            size: 15,
                            color: const Color(0xFF4EE0B8),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.peerName} • Use pinça ou scroll para ampliar',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.18),
                        foregroundColor: Colors.white,
                      ),
                      tooltip: 'Sair da tela cheia',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.fullscreen_exit_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showQualitySelector(BuildContext context) async {
    final picked = await pickVideoStreamPreset(
      context,
      current: widget.connection.currentVideoPreset,
      forScreenShare: widget.connection.isScreenSharing ||
          widget.connection.isRemoteScreenSharing,
      title: 'Ajustar Qualidade da Transmissão',
    );
    if (picked != null && mounted) {
      _runAction(() => widget.connection.setVideoQuality(picked));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Qualidade de vídeo ajustada para ${picked.label}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatDuration() {
    final connectedAt = widget.connection.callConnectedAt;
    if (connectedAt == null) return '00:00';
    final elapsed = DateTime.now().difference(connectedAt);
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.connection.callState;
    if (state == P2PCallState.idle) return const SizedBox.shrink();

    if (state == P2PCallState.incoming) {
      return _buildIncomingBanner(context);
    }
    if (_minimized) {
      return _buildMinimizedBar(context);
    }
    return _buildActiveCallStage(context);
  }

  Widget _buildIncomingBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isScreen = widget.connection.isRemoteScreenSharing;
    final isVideo = widget.connection.isVideoCall;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colors.surface,
              colors.primaryContainer.withValues(alpha: 0.35),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.45),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isScreen
                        ? Icons.present_to_all_rounded
                        : isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    color: colors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.lock_outline,
                            size: 13,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              isScreen
                                  ? 'Recebendo transmissão de tela P2P...'
                                  : isVideo
                                  ? 'Recebendo videochamada P2P direta...'
                                  : 'Recebendo chamada de voz P2P direta...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _runAction(widget.connection.rejectCall),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.errorContainer,
                    foregroundColor: colors.onErrorContainer,
                    minimumSize: const Size(100, 40),
                  ),
                  icon: const Icon(Icons.call_end_rounded, size: 17),
                  label: const Text('Recusar'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runAction(
                          () => widget.connection.acceptCall(
                            withAudio: false,
                            withVideo: false,
                          ),
                        ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(105, 40),
                  ),
                  icon: const Icon(Icons.mic_off_rounded, size: 17),
                  label: const Text('Entrar mudo'),
                ),
                if (isVideo && !isScreen)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _runAction(
                            () => widget.connection.acceptCall(
                              withAudio: true,
                              withVideo: false,
                            ),
                          ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 40),
                    ),
                    icon: const Icon(Icons.call_rounded, size: 17),
                    label: const Text('Só voz'),
                  ),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runAction(
                          () => widget.connection.acceptCall(
                            withAudio: true,
                            withVideo: isVideo && !isScreen,
                          ),
                        ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(115, 40),
                  ),
                  icon: Icon(
                    isScreen
                        ? Icons.present_to_all_rounded
                        : isVideo
                        ? Icons.videocam_rounded
                        : Icons.call_rounded,
                    size: 17,
                  ),
                  label: Text(isScreen ? 'Assistir' : 'Atender'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimizedBar(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = widget.connection.callState;
    final statusText = switch (state) {
      P2PCallState.outgoing => 'Chamando...',
      P2PCallState.connecting => 'Conectando mídia...',
      P2PCallState.active => _formatDuration(),
      _ => '',
    };
    final isSharing =
        widget.connection.isScreenSharing ||
        widget.connection.isRemoteScreenSharing;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.primary.withValues(alpha: 0.4)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => setState(() => _minimized = false),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  isSharing
                      ? Icons.present_to_all_rounded
                      : widget.connection.isVideoCall
                      ? Icons.videocam_rounded
                      : Icons.graphic_eq_rounded,
                  color: colors.primary,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          '${widget.peerName} • $statusText',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                      if (widget.connection.isVideoCall || isSharing) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.connection.currentVideoPreset.shortLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: widget.connection.isAudioMuted
                      ? 'Ativar microfone'
                      : 'Desligar microfone (permanecer na chamada)',
                  onPressed: () => _runAction(widget.connection.toggleMute),
                  icon: Icon(
                    widget.connection.isAudioMuted
                        ? Icons.mic_off_rounded
                        : Icons.mic_rounded,
                    size: 19,
                    color: widget.connection.isAudioMuted
                        ? colors.error
                        : colors.onSurface,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: widget.connection.isVideoEnabled
                      ? 'Desligar câmera (permanecer na chamada)'
                      : 'Ativar câmera',
                  onPressed: () => _runAction(widget.connection.toggleVideo),
                  icon: Icon(
                    widget.connection.isVideoEnabled
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    size: 19,
                    color: widget.connection.isVideoEnabled
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Expandir chamada',
                  onPressed: () => setState(() => _minimized = false),
                  icon: const Icon(Icons.open_in_full_rounded, size: 18),
                ),
                const SizedBox(width: 4),
                IconButton.filled(
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                  ),
                  tooltip: 'Desconectar da chamada',
                  onPressed: _busy
                      ? null
                      : () => _runAction(widget.connection.endCall),
                  icon: const Icon(Icons.call_end_rounded, size: 18),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveCallStage(BuildContext context) {
    final state = widget.connection.callState;
    final hasRemoteVideo =
        _renderersInitialized &&
        widget.connection.remoteStream != null &&
        widget.connection.isRemoteVideoEnabled &&
        widget.connection.remoteStream!.getVideoTracks().isNotEmpty;
    final hasLocalVideo =
        _renderersInitialized &&
        widget.connection.localStream != null &&
        widget.connection.isVideoEnabled &&
        widget.connection.localStream!.getVideoTracks().isNotEmpty;

    final statusLabel = switch (state) {
      P2PCallState.outgoing =>
        widget.connection.isScreenSharing
            ? 'Iniciando transmissão de tela...'
            : 'Chamando contato...',
      P2PCallState.connecting => 'Estabelecendo mídia P2P...',
      P2PCallState.active => _formatDuration(),
      _ => '',
    };

    final isScreenMode =
        widget.connection.isScreenSharing ||
        widget.connection.isRemoteScreenSharing;
    final activePeers = widget.connection.activeCallPeerKeys;
    final showGroupStrip =
        widget.connection.conversation.isGroup && activePeers.length > 1;

    final stageHeight = isScreenMode
        ? 340.0
        : (hasRemoteVideo || hasLocalVideo || widget.connection.isVideoCall)
        ? 300.0
        : 225.0;

    final useContain = _fitContain || widget.connection.isRemoteScreenSharing;
    final bothLocalMediaOff =
        widget.connection.isAudioMuted &&
        !widget.connection.isVideoEnabled &&
        !widget.connection.isScreenSharing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: stageHeight,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0A101D), Color(0xFF131F36)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Remote Video / Screen Stream or Voice Stage
              if (hasRemoteVideo)
                RTCVideoView(
                  _remoteRenderer,
                  objectFit: useContain
                      ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                      : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(
                            0xFF4F7DFF,
                          ).withValues(alpha: 0.22),
                          border: Border.all(
                            color: const Color(
                              0xFF62E0BD,
                            ).withValues(alpha: 0.55),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: widget.connection.isScreenSharing
                            ? const Icon(
                                Icons.present_to_all_rounded,
                                color: Color(0xFF62E0BD),
                                size: 30,
                              )
                            : Text(
                                widget.peerName.isEmpty
                                    ? '?'
                                    : widget.peerName
                                          .substring(0, 1)
                                          .toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        widget.connection.isScreenSharing
                            ? 'Você está transmitindo sua tela'
                            : widget.peerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.connection.isRemoteAudioMuted) ...[
                            const Icon(
                              Icons.mic_off_rounded,
                              size: 14,
                              color: Color(0xFFFF647C),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 13,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (bothLocalMediaOff) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Câmera e microfone desligados • Conectado na chamada',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Top Status Overlay Bar
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.56),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.14),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isScreenMode
                                    ? Icons.present_to_all_rounded
                                    : Icons.verified_user_outlined,
                                size: 13,
                                color: const Color(0xFF62E0BD),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.connection.isRemoteScreenSharing
                                    ? 'Tela compartilhada • $statusLabel'
                                    : widget.connection.isScreenSharing
                                    ? 'Transmitindo tela • $statusLabel'
                                    : hasRemoteVideo
                                    ? 'DTLS-SRTP P2P • $statusLabel'
                                    : 'Criptografia P2P Direta',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (state == P2PCallState.active &&
                            (widget.connection.isVideoCall ||
                                hasRemoteVideo ||
                                isScreenMode ||
                                hasLocalVideo)) ...[
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: () => _showQualitySelector(context),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: (widget.connection.currentVideoPreset ==
                                              VideoStreamPreset.ultra4k60 ||
                                          widget.connection.currentVideoPreset ==
                                              VideoStreamPreset.ultra4k30)
                                      ? const Color(0xFF62E0BD)
                                          .withValues(alpha: 0.22)
                                      : Colors.black.withValues(alpha: 0.56),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: (widget.connection.currentVideoPreset ==
                                                VideoStreamPreset.ultra4k60 ||
                                            widget.connection.currentVideoPreset ==
                                                VideoStreamPreset.ultra4k30)
                                        ? const Color(0xFF62E0BD)
                                        : Colors.white.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      (widget.connection.currentVideoPreset ==
                                                  VideoStreamPreset.ultra4k60 ||
                                              widget.connection.currentVideoPreset ==
                                                  VideoStreamPreset.ultra4k30)
                                          ? Icons.diamond_rounded
                                          : Icons.four_k_rounded,
                                      size: 13,
                                      color: const Color(0xFF62E0BD),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      widget.connection.currentVideoPreset.badge,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (hasRemoteVideo) ...[
                          Material(
                            color: Colors.black.withValues(alpha: 0.48),
                            shape: const CircleBorder(),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: _fitContain
                                  ? 'Preencher quadro'
                                  : 'Ajustar imagem inteira',
                              onPressed: () =>
                                  setState(() => _fitContain = !_fitContain),
                              icon: const Icon(
                                Icons.aspect_ratio_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Material(
                            color: Colors.black.withValues(alpha: 0.48),
                            shape: const CircleBorder(),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: 'Expandir em tela cheia (com zoom)',
                              onPressed: _openFullscreenViewer,
                              icon: const Icon(
                                Icons.fullscreen_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Material(
                          color: Colors.black.withValues(alpha: 0.48),
                          shape: const CircleBorder(),
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Minimizar painel para conversar',
                            onPressed: () => setState(() => _minimized = true),
                            icon: const Icon(
                              Icons.keyboard_arrow_up_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showGroupStrip) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 30,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: activePeers.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (context, index) {
                            final key = activePeers[index];
                            final peer = widget.connection.peerService(key);
                            final selected =
                                key == widget.connection.callPeerKey;
                            return ChoiceChip(
                              selected: selected,
                              visualDensity: VisualDensity.compact,
                              onSelected: (_) {
                                widget.connection.selectCallPeer(key);
                                _syncStreams();
                              },
                              avatar: Icon(
                                peer.isRemoteScreenSharing
                                    ? Icons.present_to_all_rounded
                                    : peer.isRemoteVideoEnabled
                                    ? Icons.videocam_rounded
                                    : peer.isRemoteAudioMuted
                                    ? Icons.mic_off_rounded
                                    : Icons.mic_rounded,
                                size: 14,
                              ),
                              label: Text(
                                _user.contactName(key),
                                style: const TextStyle(fontSize: 11.5),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Local PiP Preview (Camera or Screen Share Thumbnail)
              if (hasLocalVideo)
                Positioned(
                  right: 12,
                  bottom: 72,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: widget.connection.isScreenSharing ? 124 : 94,
                      height: widget.connection.isScreenSharing ? 76 : 124,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.connection.isScreenSharing
                              ? const Color(0xFF62E0BD)
                              : Colors.white.withValues(alpha: 0.28),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: RTCVideoView(
                        _localRenderer,
                        mirror: !widget.connection.isScreenSharing,
                        objectFit: widget.connection.isScreenSharing
                            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                            : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // Bottom Call Control Bar
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Wrap(
                      spacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _CallControlButton(
                          icon: widget.connection.isAudioMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          tooltip: widget.connection.isAudioMuted
                              ? 'Ligar microfone'
                              : 'Desligar microfone (sem desconectar)',
                          active: !widget.connection.isAudioMuted,
                          alert: widget.connection.isAudioMuted,
                          onPressed: () =>
                              _runAction(widget.connection.toggleMute),
                        ),
                        _CallControlButton(
                          icon:
                              widget.connection.isVideoEnabled &&
                                  !widget.connection.isScreenSharing
                              ? Icons.videocam_rounded
                              : Icons.videocam_off_rounded,
                          tooltip:
                              widget.connection.isVideoEnabled &&
                                  !widget.connection.isScreenSharing
                              ? 'Desligar câmera (sem desconectar)'
                              : 'Ligar câmera',
                          active:
                              widget.connection.isVideoEnabled &&
                              !widget.connection.isScreenSharing,
                          alert:
                              !widget.connection.isVideoEnabled &&
                              !widget.connection.isScreenSharing,
                          onPressed: () =>
                              _runAction(widget.connection.toggleVideo),
                        ),
                        if (state == P2PCallState.active)
                          _CallControlButton(
                            icon: widget.connection.isScreenSharing
                                ? Icons.stop_screen_share_rounded
                                : Icons.screen_share_rounded,
                            tooltip: widget.connection.isScreenSharing
                                ? 'Parar compartilhamento de tela (sem desconectar)'
                                : 'Compartilhar tela P2P',
                            active: widget.connection.isScreenSharing,
                            highlight: widget.connection.isScreenSharing,
                            onPressed: _busy ? null : _handleToggleScreenShare,
                          ),
                        if (state == P2PCallState.active &&
                            (widget.connection.isVideoCall ||
                                widget.connection.isVideoEnabled ||
                                widget.connection.isScreenSharing ||
                                hasRemoteVideo))
                          _CallControlButton(
                            icon: Icons.four_k_rounded,
                            tooltip:
                                'Qualidade de vídeo e streaming (${widget.connection.currentVideoPreset.shortLabel})',
                            active: widget.connection.currentVideoPreset ==
                                    VideoStreamPreset.ultra4k60 ||
                                widget.connection.currentVideoPreset ==
                                    VideoStreamPreset.ultra4k30,
                            highlight: widget.connection.currentVideoPreset ==
                                    VideoStreamPreset.ultra4k60 ||
                                widget.connection.currentVideoPreset ==
                                    VideoStreamPreset.ultra4k30,
                            onPressed: _busy
                                ? null
                                : () => _showQualitySelector(context),
                          ),
                        if (hasLocalVideo &&
                            !widget.connection.isScreenSharing)
                          _CallControlButton(
                            icon: Icons.cameraswitch_rounded,
                            tooltip: 'Alternar câmera',
                            active: false,
                            onPressed: () =>
                                _runAction(widget.connection.switchCamera),
                          ),
                        if (defaultTargetPlatform == TargetPlatform.android ||
                            defaultTargetPlatform == TargetPlatform.iOS)
                          _CallControlButton(
                            icon: widget.connection.isSpeakerphoneOn
                                ? Icons.volume_up_rounded
                                : Icons.hearing_rounded,
                            tooltip: widget.connection.isSpeakerphoneOn
                                ? 'Viva-voz ativado'
                                : 'Viva-voz desativado',
                            active: widget.connection.isSpeakerphoneOn,
                            onPressed: () => _runAction(
                              widget.connection.toggleSpeakerphone,
                            ),
                          ),
                        _CallControlButton(
                          icon: Icons.call_end_rounded,
                          tooltip: 'Desconectar da chamada',
                          active: false,
                          destructive: true,
                          onPressed: _busy
                              ? null
                              : () => _runAction(widget.connection.endCall),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
    this.alert = false,
    this.highlight = false,
    this.destructive = false,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final bool alert;
  final bool highlight;
  final bool destructive;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = destructive
        ? const Color(0xFFE53935)
        : highlight
        ? const Color(0xFF4EE0B8).withValues(alpha: 0.25)
        : alert
        ? const Color(0xFFFF647C).withValues(alpha: 0.22)
        : active
        ? Colors.white.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.1);
    final fgColor = destructive
        ? Colors.white
        : highlight
        ? const Color(0xFF4EE0B8)
        : alert
        ? const Color(0xFFFF647C)
        : Colors.white;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: bgColor,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, color: fgColor, size: 20),
          ),
        ),
      ),
    );
  }
}
