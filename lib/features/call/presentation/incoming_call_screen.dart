import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../helpers/call_manager.dart';
import '../../../providers/call_state_provider.dart';
import '../widgets/call_action_button.dart';
import '../widgets/participant_avatar.dart';

class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({super.key});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  CallManager get _callManager => CallManager.instance;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    await _callManager.acceptCall();
  }

  Future<void> _declineCall() async {
    await _callManager.declineCall();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        final callerName = callProvider.currentCall?.callerName ?? 'Unknown';
        final callerPhoto = callProvider.currentCall?.callerPhoto;
        final callType = callProvider.currentCall?.type.name ?? 'audio';

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Caller Avatar with pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        // Pulse rings
                        ...List.generate(3, (index) {
                          final delay = index * 0.3;
                          final value =
                              (_pulseAnimation.value - delay).clamp(0.0, 1.0);
                          return Container(
                            width: 140 + (60 * value),
                            height: 140 + (60 * value),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.green.withOpacity(1 - value),
                                width: 2,
                              ),
                            ),
                          );
                        }),
                        // Avatar
                        child!,
                      ],
                    );
                  },
                  child: ParticipantAvatar(
                    name: callerName,
                    photoUrl: callerPhoto,
                    size: 120,
                    showName: false,
                  ),
                ),

                const SizedBox(height: 32),

                // Caller name
                Text(
                  callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                // Call type indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      callType == 'video' ? Icons.videocam : Icons.call,
                      color: Colors.white70,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Incoming $callType call...',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),

                const Spacer(flex: 3),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Decline button
                      CallActionButton(
                        icon: Icons.call_end,
                        color: Colors.red,
                        label: 'Decline',
                        onTap: _declineCall,
                      ),

                      // Accept button
                      CallActionButton(
                        icon: Icons.call,
                        color: Colors.green,
                        label: 'Accept',
                        onTap: _acceptCall,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        );
      },
    );
  }
}
