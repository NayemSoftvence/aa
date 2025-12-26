import 'package:flutter/material.dart';

class CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final double size;

  const CallActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          elevation: 4,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.45,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

/// Smaller control button for call controls bar
class CallControlButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? activeColor;
  final Color? inactiveColor;
  final double size;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = isActive
        ? (activeColor ?? Colors.white)
        : (inactiveColor ?? const Color(0x33FFFFFF));
    final iconColor = isActive ? Colors.black : Colors.white;

    return InkResponse(
      onTap: onTap,
      radius: size / 2,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}
