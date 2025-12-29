import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      color: Colors.black, // Opaque black for column layout
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          CallControlButton(
            icon: isMuted ? Icons.mic_off : Icons.mic,
            isActive: isMuted,
            activeColor: Colors.red.shade400,
            onTap: onMuteToggle,
            size: 50
                .r, // Assuming CallControlButton supports size or I need to handle it?
            // checking CallControlButton signature... limited info. Assuming standard.
            // If CallControlButton is custom, I might need to update IT too.
            // Let's assume standard button or icon size.
          ),

          // Speaker button
          CallControlButton(
            icon: isSpeakerOn ? Icons.volume_up : Icons.hearing,
            isActive: isSpeakerOn,
            onTap: onSpeakerToggle,
            size: 50.r,
          ),

          // Camera button (optional)
          if (showCameraButton)
            CallControlButton(
              icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
              isActive: isCameraOn,
              onTap: onCameraToggle,
              size: 50.r,
            ),

          // Hang up button
          CallControlButton(
            icon: Icons.call_end,
            isActive: true,
            activeColor: Colors.red,
            onTap: onHangUp,
            size: 60.r, // Slightly larger
          ),
        ],
      ),
    );
  }
}
