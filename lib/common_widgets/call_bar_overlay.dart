import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_state_provider.dart';
import 'call_bar_widget.dart';

/// Wrapper widget that adds the call bar overlay below app bar
/// This wraps individual screens, not the entire app
class CallBarOverlay extends StatelessWidget {
  final Widget child;
  final bool hasAppBar;

  const CallBarOverlay({super.key, required this.child, this.hasAppBar = true});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        // If no call bar needed, just return child
        if (!callProvider.shouldShowCallBar) {
          return child;
        }

        // If we have an app bar, show call bar below it using Column
        if (hasAppBar) {
          return Column(
            children: [const CallBarWidget(), Expanded(child: child)],
          );
        }

        // Otherwise, just overlay on top
        return Stack(
          children: [
            child,
            const Positioned(top: 0, left: 0, right: 0, child: CallBarWidget()),
          ],
        );
      },
    );
  }
}
