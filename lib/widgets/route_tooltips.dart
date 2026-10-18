import 'package:flutter/material.dart';

/// Flutter 3.47 offstage tooltip portals can retain stale overlay geometry
/// (flutter/flutter#192030). Tear down only the covered route's floating hints;
/// restore normal hints immediately on return. No error/animation suppression.
class RouteTooltipsTransitions extends PageTransitionsBuilder {
  const RouteTooltipsTransitions(this.delegate);
  final PageTransitionsBuilder delegate;
  @override
  bool operator ==(Object other) =>
      other is RouteTooltipsTransitions && other.delegate == delegate;
  @override
  int get hashCode => delegate.hashCode;
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      delegate.delegatedTransition;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => delegate.buildTransitions(
    route,
    context,
    animation,
    secondaryAnimation,
    Builder(
      builder: (context) => TooltipVisibility(
        visible: ModalRoute.isCurrentOf(context) ?? true,
        child: child,
      ),
    ),
  );
}
