import 'package:flutter/material.dart';

/// Keep the live page subtree when changing focus mode, but show its main
/// readout from the top instead of leaving it at an old diagnostics offset.
class ModeScroll extends StatefulWidget {
  const ModeScroll({
    super.key,
    required this.storageId,
    required this.minimal,
    required this.padding,
    required this.child,
  });
  final String storageId;
  final bool minimal;
  final EdgeInsets padding;
  final Widget child;
  @override
  State<ModeScroll> createState() => _ModeScrollState();
}

class _ModeScrollState extends State<ModeScroll> {
  final controller = ScrollController();
  @override
  void didUpdateWidget(ModeScroll old) {
    super.didUpdateWidget(old);
    if (old.minimal != widget.minimal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && controller.hasClients) controller.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListView(
    key: PageStorageKey(widget.storageId),
    controller: controller,
    padding: widget.padding,
    children: [widget.child],
  );
}
