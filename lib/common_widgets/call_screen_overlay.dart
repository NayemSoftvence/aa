import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/call/presentation/call_screen.dart';
import '../providers/call_state_provider.dart';

/// Standalone overlay widget for showing call screen
/// Use this if you need more control over the overlay
class CallScreenOverlay extends StatelessWidget {
  final Widget child;

  const CallScreenOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        return Stack(
          children: [
            child,
            if (callProvider.shouldShowFullScreen &&
                callProvider.callId != null)
              Positioned.fill(
                child: Material(
                  color: Colors.black,
                  child: CallScreen(callId: callProvider.callId!),
                ),
              ),
          ],
        );
      },
    );
  }
}
