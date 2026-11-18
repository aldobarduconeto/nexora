import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nexora/src/models/protected_content.dart';
import 'package:nexora/src/services/file_transfer_service.dart';
import 'package:nexora/src/views/widgets/stealth_blur.dart';

class ProtectedContentBubble extends StatelessWidget {
  const ProtectedContentBubble({
    super.key,
    required this.transfer,
    required this.stealthMode,
    required this.onDecision,
  });

  final ProtectedTransfer transfer;
  final bool stealthMode;
  final ValueChanged<bool> onDecision;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = transfer.kind == ProtectedContentKind.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${transfer.warning.label} · ${transfer.kind.label}',
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        if (transfer.state == ProtectedTransferState.pending &&
            !transfer.outgoing) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    height: 72,
                    width: 230,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colors.primaryContainer,
                          colors.tertiaryContainer,
                        ],
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.visibility_off_outlined),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              FilledButton.tonal(
                onPressed: () => onDecision(true),
                child: Text(text ? 'Ver texto' : 'Baixar conteúdo'),
              ),
              TextButton(
                onPressed: () => onDecision(false),
                child: const Text('Recusar'),
              ),
            ],
          ),
        ] else if (transfer.result case final result?)
          _revealed(context, result)
        else
          Text(switch (transfer.state) {
            ProtectedTransferState.pending => 'Aguardando aceitação',
            ProtectedTransferState.receiving =>
              transfer.outgoing ? 'Enviando…' : 'Recebendo…',
            ProtectedTransferState.completed => 'Conteúdo enviado',
            ProtectedTransferState.declined => 'Conteúdo recusado',
            ProtectedTransferState.unavailable =>
              transfer.outgoing
                  ? 'Envio não concluído'
                  : 'Conteúdo indisponível',
          }),
      ],
    );
  }

  Widget _revealed(BuildContext context, String result) {
    if (transfer.kind == ProtectedContentKind.text) {
      return StealthBlur(enabled: stealthMode, child: SelectableText(result));
    }
    final file = File(result);
    final kind = transfer.kind;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (kind == ProtectedContentKind.photo)
          StealthBlur(
            enabled: stealthMode,
            child: Image.file(
              file,
              cacheWidth: 900,
              width: 300,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Text('Prévia indisponível'),
            ),
          )
        else if (kind == ProtectedContentKind.video ||
            kind == ProtectedContentKind.audio)
          FilledButton.tonalIcon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ProtectedPlayback(
                file: file,
                video: kind == ProtectedContentKind.video,
              ),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(
              kind == ProtectedContentKind.video
                  ? 'Assistir vídeo'
                  : 'Reproduzir áudio',
            ),
          )
        else ...[
          const Text('Salvo na pasta escolhida'),
          SelectableText(file.uri.pathSegments.last),
          TextButton.icon(
            onPressed: () => Clipboard.setData(ClipboardData(text: result)),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copiar caminho do arquivo'),
          ),
        ],
      ],
    );
  }
}

class _ProtectedPlayback extends StatefulWidget {
  const _ProtectedPlayback({required this.file, required this.video});

  final File file;
  final bool video;

  @override
  State<_ProtectedPlayback> createState() => _ProtectedPlaybackState();
}

class _ProtectedPlaybackState extends State<_ProtectedPlayback> {
  Player? _player;
  VideoController? _videoController;
  StreamSubscription<String>? _errors;
  bool _failed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      MediaKit.ensureInitialized();
      final player = _player = Player(
        configuration: const PlayerConfiguration(protocolWhitelist: ['file']),
      );
      _errors = player.stream.error.listen((_) => _reportFailure());
      if (widget.video) _videoController = VideoController(player);
      final native = player.platform;
      if (native is NativePlayer) {
        await native.setProperty('access-references', 'no');
      }
      if (!mounted) return;
      await player.open(Media(widget.file.uri.toString()));
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      _reportFailure();
    }
  }

  void _reportFailure() {
    if (mounted) setState(() => _failed = true);
  }

  @override
  void dispose() {
    unawaited(_errors?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.video ? 'Vídeo protegido' : 'Áudio protegido'),
    content: _failed
        ? const Text('Não foi possível reproduzir este arquivo.')
        : _videoController != null
        ? SizedBox(
            width: 620,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Video(controller: _videoController!),
            ),
          )
        : _loading
        ? const Center(
            widthFactor: 1,
            heightFactor: 1,
            child: CircularProgressIndicator(),
          )
        : StreamBuilder<bool>(
            stream: _player!.stream.playing,
            initialData: _player!.state.playing,
            builder: (context, snapshot) {
              final playing = snapshot.data ?? false;
              return FilledButton.tonalIcon(
                onPressed: _player!.playOrPause,
                icon: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(playing ? 'Pausar' : 'Reproduzir'),
              );
            },
          ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Fechar'),
      ),
    ],
  );
}
