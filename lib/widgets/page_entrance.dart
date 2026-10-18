import 'package:flutter/material.dart';

/// Animates only the current page. The outgoing subtree is removed immediately,
/// so audio ownership/disposal never waits for a visual transition.
class PageEntrance extends StatefulWidget {
  const PageEntrance({super.key, required this.page, required this.child});
  final int page;
  final Widget child;
  @override
  State<PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<PageEntrance>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 120),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _controller.value = 1;
  }

  @override
  void didUpdateWidget(PageEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.page != widget.page) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final value = Curves.easeOut.transform(_controller.value);
      return IgnorePointer(
        key: const ValueKey('page-pointer-gate'),
        ignoring: _controller.value < 1,
        child: Opacity(
          key: const ValueKey('page-opacity'),
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 4 * (1 - value)),
            child: child,
          ),
        ),
      );
    },
  );
}
