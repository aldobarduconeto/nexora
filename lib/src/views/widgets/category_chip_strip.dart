import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class CategoryChipStrip extends StatefulWidget {
  const CategoryChipStrip({super.key, required this.children});

  final List<Widget> children;

  @override
  State<CategoryChipStrip> createState() => _CategoryChipStripState();
}

class _CategoryChipStripState extends State<CategoryChipStrip> {
  final _controller = ScrollController();
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateButtons);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateButtons() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return;
    }
    final position = _controller.position;
    final back = position.extentBefore > 0.5;
    final forward = position.extentAfter > 0.5;
    if (back == _canGoBack && forward == _canGoForward) return;
    setState(() {
      _canGoBack = back;
      _canGoForward = forward;
    });
  }

  void _page(int direction) {
    final position = _controller.position;
    final target =
        (position.pixels + position.viewportDimension * .8 * direction)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    }
  }

  void _onWheel(PointerSignalEvent event) {
    // The horizontal scrollable already handles the trackpad's horizontal axis.
    if (event is! PointerScrollEvent ||
        event.scrollDelta.dx != 0 ||
        event.scrollDelta.dy == 0 ||
        !_controller.hasClients)
      return;
    final position = _controller.position;
    final delta = event.scrollDelta.dy;
    if ((delta < 0 && position.extentBefore <= 0) ||
        (delta > 0 && position.extentAfter <= 0))
      return;

    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (_controller.hasClients) _controller.position.pointerScroll(delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scrollBehavior = ScrollConfiguration.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      children: [
        IconButton(
          tooltip: 'Categorias anteriores',
          onPressed: _canGoBack ? () => _page(-1) : null,
          icon: Icon(
            rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded,
          ),
        ),
        Expanded(
          child: Listener(
            onPointerSignal: _onWheel,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: (_) {
                _updateButtons();
                return false;
              },
              child: ScrollConfiguration(
                behavior: scrollBehavior.copyWith(
                  dragDevices: {
                    ...scrollBehavior.dragDevices,
                    PointerDeviceKind.mouse,
                  },
                ),
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  child: Row(children: widget.children),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Próximas categorias',
          onPressed: _canGoForward ? () => _page(1) : null,
          icon: Icon(
            rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
          ),
        ),
      ],
    );
  }
}
