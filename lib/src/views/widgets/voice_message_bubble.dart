import 'dart:async';
import 'package:flutter/material.dart';

/// Bolha de exibição de nota de áudio/voz com reprodução simulada e visualizador de ondas sonoras.
class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.durationSeconds,
    this.waveform,
    required this.isLocal,
  });

  final int durationSeconds;
  final List<double>? waveform;
  final bool isLocal;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  bool _isPlaying = false;
  double _progress = 0.0;
  Timer? _playbackTimer;

  late final List<double> _bars;

  @override
  void initState() {
    super.initState();
    if (widget.waveform != null && widget.waveform!.isNotEmpty) {
      _bars = widget.waveform!;
    } else {
      // Gera alturas de onda sonoras determinísticas
      _bars = [
        0.3, 0.6, 0.9, 0.4, 0.7, 1.0, 0.5, 0.8,
        0.3, 0.6, 0.9, 0.5, 0.8, 0.4, 0.7, 0.9,
        0.6, 0.3, 0.5, 0.8, 0.4, 0.6, 0.3, 0.2,
      ];
    }
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      final totalSeconds = widget.durationSeconds > 0 ? widget.durationSeconds : 10;
      final stepDuration = Duration(milliseconds: 100);
      final totalSteps = (totalSeconds * 10).toDouble();

      _playbackTimer?.cancel();
      _playbackTimer = Timer.periodic(stepDuration, (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _progress += 1.0 / totalSteps;
          if (_progress >= 1.0) {
            _progress = 0.0;
            _isPlaying = false;
            timer.cancel();
          }
        });
      });
    } else {
      _playbackTimer?.cancel();
    }
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final totalDuration = widget.durationSeconds > 0 ? widget.durationSeconds : 12;
    final currentDuration = (_progress * totalDuration).round();
    final primaryColor = widget.isLocal ? colors.onPrimaryContainer : colors.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Botão Play/Pause
          InkWell(
            onTap: _togglePlay,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: widget.isLocal
                    ? colors.onPrimaryContainer.withValues(alpha: 0.15)
                    : colors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: primaryColor,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Ondas sonoras (Waveform)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (int i = 0; i < _bars.length; i++) ...[
                    Container(
                      width: 2.8,
                      height: 18 * _bars[i].clamp(0.2, 1.0),
                      decoration: BoxDecoration(
                        color: (i / _bars.length) <= _progress
                            ? primaryColor
                            : primaryColor.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    if (i < _bars.length - 1) const SizedBox(width: 2.2),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isPlaying
                        ? _formatDuration(currentDuration)
                        : _formatDuration(totalDuration),
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'monospace',
                      color: primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.graphic_eq_rounded,
                    size: 11,
                    color: primaryColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Voz P2P E2EE',
                    style: TextStyle(
                      fontSize: 10,
                      color: primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
