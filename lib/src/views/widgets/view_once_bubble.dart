import 'dart:async';
import 'package:flutter/material.dart';

class ViewOnceBubble extends StatefulWidget {
  const ViewOnceBubble({
    super.key,
    required this.content,
    required this.isLocal,
    required this.viewedAt,
    required this.onOpen,
  });

  final String content;
  final bool isLocal;
  final DateTime? viewedAt;
  final VoidCallback onOpen;

  @override
  State<ViewOnceBubble> createState() => _ViewOnceBubbleState();
}

class _ViewOnceBubbleState extends State<ViewOnceBubble> {
  bool _revealed = false;
  int _secondsRemaining = 15;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    if (widget.viewedAt != null) {
      final elapsed = DateTime.now().difference(widget.viewedAt!).inSeconds;
      if (elapsed < 15) {
        _revealed = true;
        _secondsRemaining = 15 - elapsed;
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
          _revealed = false;
        });
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _reveal() {
    widget.onOpen();
    setState(() {
      _revealed = true;
      _secondsRemaining = 15;
    });
    _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDestroyed = widget.viewedAt != null && _secondsRemaining <= 0;

    if (widget.isLocal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.primary.withValues(alpha: .2),
            ),
            child: Icon(
              Icons.local_fire_department_rounded,
              size: 16,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mensagem autodestrutiva enviada',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: colors.onPrimaryContainer,
                  ),
                ),
                Text(
                  widget.viewedAt != null
                      ? 'Aberta e destruída pelo destinatário'
                      : 'Visualização única • Destrói ao abrir',
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.onPrimaryContainer.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (isDestroyed) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_clock_outlined,
            size: 16,
            color: colors.onSurfaceVariant.withValues(alpha: .6),
          ),
          const SizedBox(width: 8),
          Text(
            'Mensagem visualizada e destruída',
            style: TextStyle(
              fontSize: 12.5,
              fontStyle: FontStyle.italic,
              color: colors.onSurfaceVariant.withValues(alpha: .6),
            ),
          ),
        ],
      );
    }

    if (_revealed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  value: _secondsRemaining / 15,
                  strokeWidth: 2,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Autodestruição em ${_secondsRemaining}s',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            widget.content,
            style: TextStyle(
              color: colors.onSurface,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      );
    }

    // Locked / Unopened
    return InkWell(
      onTap: _reveal,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.primary.withValues(alpha: .3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.primary,
              ),
              child: const Icon(
                Icons.local_fire_department_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Visualização única',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Toque para abrir (some após 15s)',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
