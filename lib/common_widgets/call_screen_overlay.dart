import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/call_constants.dart';
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
        // PROBLEM 3 FIX: Show CallScreen for all active call states (not just maximized)
        // This ensures CallScreen shows when accepting from background/killed state
        final shouldShowCallScreen =
            (callProvider.state == CallState.incomingRinging ||
                    callProvider.state == CallState.outgoingRinging ||
                    callProvider.state == CallState.connecting ||
                    callProvider.state == CallState.inCall) &&
                callProvider.callId != null &&
                !callProvider.isMinimized;

        return Stack(
          children: [
            child,
            if (shouldShowCallScreen)
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
