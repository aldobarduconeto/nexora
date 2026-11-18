import 'package:flutter/material.dart';

class AdaptiveWorkspace extends StatelessWidget {
  const AdaptiveWorkspace({
    super.key,
    required this.home,
    required this.detail,
    required this.detailOpen,
    required this.splitView,
  });

  final Widget home;
  final Widget detail;
  final bool detailOpen;
  final bool splitView;

  static bool useSideNavigation(double width, String preference) =>
      switch (preference) {
        'side' => width >= 540,
        'bottom' => false,
        _ => width >= 680,
      };

  static bool supportsSplitView(double width) => width >= 1080;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final split = splitView && detailOpen;
      final showHome = !detailOpen || split;
      final width = constraints.maxWidth;
      final listWidth = split
          ? (width * .32).clamp(320.0, 430.0).toDouble()
          : width;
      return Stack(
        fit: StackFit.expand,
        children: [
          PositionedDirectional(
            start: 0,
            width: listWidth,
            top: 0,
            bottom: 0,
            child: _pane(visible: showHome, child: home),
          ),
          PositionedDirectional(
            start: split ? listWidth + 1 : 0,
            end: 0,
            top: 0,
            bottom: 0,
            child: _pane(visible: detailOpen, child: detail),
          ),
          if (split)
            PositionedDirectional(
              start: listWidth,
              width: 1,
              top: 0,
              bottom: 0,
              child: ColoredBox(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      );
    },
  );

  Widget _pane({required bool visible, required Widget child}) => Offstage(
    offstage: !visible,
    child: ExcludeFocus(
      excluding: !visible,
      child: TickerMode(enabled: visible, child: child),
    ),
  );
}
