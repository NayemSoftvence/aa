import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/call/presentation/call_screen.dart';
import '../features/call/presentation/incoming_call_screen.dart';
import '../providers/call_state_provider.dart';
import 'call_bar_widget.dart';

/// Wraps content and shows call UI overlays based on call state
class CallBarOverlay extends StatelessWidget {
  final Widget child;

  const CallBarOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        return Stack(
          children: [
            // Main content with optional call bar padding
            Column(
              children: [
                // Call bar when minimized
                if (callProvider.shouldShowCallBar && callProvider.isMinimized)
                  const CallBarWidget(),

                // Main content
                Expanded(child: child),
              ],
            ),

            // Full-screen incoming call UI
            if (callProvider.shouldShowIncomingUI)
              const Positioned.fill(
                child: IncomingCallScreen(),
              ),

            // Full-screen active call UI
            if (callProvider.shouldShowFullScreen &&
                !callProvider.shouldShowIncomingUI &&
                callProvider.callId != null)
              Positioned.fill(
                child: CallScreen(callId: callProvider.callId!),
              ),
          ],
        );
      },
    );
  }
}
