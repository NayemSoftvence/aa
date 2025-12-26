import 'package:flutter/material.dart';

import 'call_action_button.dart';

class CallControlsBar extends StatelessWidget {
  final bool isMuted;
  final bool isSpeakerOn;
  final bool isCameraOn;
  final VoidCallback onMuteToggle;
  final VoidCallback onSpeakerToggle;
  final VoidCallback onCameraToggle;
  final VoidCallback onHangUp;
  final bool showCameraButton;

  const CallControlsBar({
    super.key,
    required this.isMuted,
    required this.isSpeakerOn,
    required this.isCameraOn,
    required this.onMuteToggle,
    required this.onSpeakerToggle,
    required this.onCameraToggle,
    required this.onHangUp,
    this.showCameraButton = false, // Hidden by default for audio-only
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mute button
            CallControlButton(
              icon: isMuted ? Icons.mic_off : Icons.mic,
              isActive: isMuted,
              activeColor: Colors.red.shade400,
              onTap: onMuteToggle,
            ),

            // Speaker button
            CallControlButton(
              icon: isSpeakerOn ? Icons.volume_up : Icons.hearing,
              isActive: isSpeakerOn,
              onTap: onSpeakerToggle,
            ),

            // Camera button (optional)
            if (showCameraButton)
              CallControlButton(
                icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
                isActive: isCameraOn,
                onTap: onCameraToggle,
              ),

            // Hang up button
            CallControlButton(
              icon: Icons.call_end,
              isActive: true,
              activeColor: Colors.red,
              onTap: onHangUp,
            ),
          ],
        ),
      ),
    );
  }
}
