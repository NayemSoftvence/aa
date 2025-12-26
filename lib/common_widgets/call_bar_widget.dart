import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/call_constants.dart';
import '../features/call/widgets/call_timer_widget.dart';
import '../features/call/widgets/connection_quality_indicator.dart';
import '../helpers/call_manager.dart';
import '../providers/call_state_provider.dart';

class CallBarWidget extends StatelessWidget {
  const CallBarWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        if (!callProvider.shouldShowCallBar) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: () => callProvider.maximize(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _getBackgroundColor(callProvider.state),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  // Call indicator icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(callProvider.state),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Call info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          callProvider.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            if (callProvider.isInCall) ...[
                              const CallTimerWidget(
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConnectionQualityIndicator(
                                quality: callProvider.connectionQuality,
                                barWidth: 3,
                                maxHeight: 12,
                              ),
                            ] else
                              Text(
                                callProvider.stateDescription,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Mute indicator
                  if (callProvider.isMuted)
                    Container(
                      padding: const EdgeInsets.all(6),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mic_off,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),

                  // End call button
                  IconButton(
                    onPressed: () => CallManager.instance.endCall(),
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(8),
                    ),
                    iconSize: 20,
                  ),

                  // Expand button
                  IconButton(
                    onPressed: () => callProvider.maximize(),
                    icon: const Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Color _getBackgroundColor(CallState state) {
    switch (state) {
      case CallState.inCall:
        return Colors.green.shade600;
      case CallState.connecting:
      case CallState.reconnecting:
        return Colors.orange.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  IconData _getIcon(CallState state) {
    switch (state) {
      case CallState.inCall:
        return Icons.call;
      case CallState.connecting:
      case CallState.reconnecting:
        return Icons.sync;
      default:
        return Icons.phone_in_talk;
    }
  }
}
