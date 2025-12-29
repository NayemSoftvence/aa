import 'package:flutter/material.dart';

class ParticipantAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final bool isLocal;
  final bool isMuted;
  final bool isSpeaking;
  final double size;
  final bool showName;
  final bool showMuteIndicator;

  const ParticipantAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.isLocal = false,
    this.isMuted = false,
    this.isSpeaking = false,
    this.size = 80,
    this.showName = true,
    this.showMuteIndicator = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar with speaking indicator
        Container(
          width: size + 8,
          height: size + 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSpeaking ? Colors.green : Colors.transparent,
              width: 3,
            ),
          ),
          child: Stack(
            children: [
              // Avatar
              Center(
                child: CircleAvatar(
                  radius: size / 2,
                  backgroundColor: Colors.grey.shade700,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl!) : null,
                  child: photoUrl == null
                      ? Text(
                          _getInitials(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: size / 3,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),

              // Mute indicator
              if (showMuteIndicator && isMuted)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Icon(
                      Icons.mic_off,
                      color: Colors.white,
                      size: size / 5,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Name
        if (showName) ...[
          const SizedBox(height: 12),
          Text(
            isLocal ? 'You' : name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  String _getInitials() {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
