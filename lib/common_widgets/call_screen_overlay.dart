import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_state_provider.dart';
import '../features/call/call_screen.dart';
import '../helpers/notification_service.dart';
import '../features/home/data/livekit_netlify_api.dart'; // import added

/// Global overlay that shows CallScreen when a call is active and not minimized
/// This wraps the entire app and listens to CallStateProvider
class CallScreenOverlay extends StatelessWidget {
  final Widget child;

  const CallScreenOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content
        child,

        // Call screen overlay - shows when call is active and not minimized
        Consumer<CallStateProvider>(
          builder: (context, callProvider, _) {
            // Show full-screen call popup when:
            // 1. Call is in progress (inCall state)
            // 2. Not minimized
            // 3. Have a callId
            // NEW: Also show overlay if "Ringing" (outgoing call)
            // This allows the caller to see "Calling..." screen and hang up
            // BUT ONLY if we are the caller (!isIncoming)
            final isRinging = callProvider.state == CallState.ringing;
            final isOutgoingRinging = isRinging && !callProvider.isIncoming;

            final shouldShow = (callProvider.isInCall || isOutgoingRinging) &&
                !callProvider.isMinimized &&
                callProvider.callId != null;

            // Debug logging
            // print('[CallScreenOverlay] State check:');
            // print('  - state: ${callProvider.state}');
            // print('  - shouldShow: $shouldShow');

            if (shouldShow) {
              // If ringing, show a "Calling..." UI with End Call button
              if (isOutgoingRinging) {
                return Positioned.fill(
                  child: Scaffold(
                    backgroundColor: Colors.black,
                    body: SafeArea(
                      child: SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Spacer(),
                            const CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey,
                              child: Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Calling ${callProvider.callerId ?? "..."}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Waiting for response...',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                              ),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 48.0),
                              child: FloatingActionButton(
                                onPressed: () {
                                  final callId = callProvider.callId;
                                  callProvider.endCall();

                                  if (callId != null) {
                                    // Use the existing static method to clean up
                                    NotificationService.declineOrEndCall(
                                      callId,
                                    );
                                    // CRITICAL: Force remote cleanup (stop ringing)
                                    LivekitNetlifyApi.instance.notifyCallEnded(
                                      callId,
                                    );
                                  }
                                },
                                backgroundColor: Colors.red,
                                child: const Icon(Icons.call_end),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              // If In Call, show the full CallScreen
              return Positioned.fill(
                child: CallScreen(callId: callProvider.callId!),
              );
            }

            print('[CallScreenOverlay] Not showing overlay');
            // Otherwise, don't show anything
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}
