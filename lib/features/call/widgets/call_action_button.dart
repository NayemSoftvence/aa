import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CallActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final double? size;

  const CallActionButton({
    super.key,
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.size, // Default handled in build
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 72.r;
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
              width: s,
              height: s,
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: Colors.white,
                size: s * 0.45,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14.sp,
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
  final double? size;

  const CallControlButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.activeColor,
    this.inactiveColor,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final s = size ?? 56.r;
    final bgColor = isActive
        ? (activeColor ?? Colors.white)
        : (inactiveColor ?? const Color(0x33FFFFFF));
    final iconColor = isActive ? Colors.black : Colors.white;

    return InkResponse(
      onTap: onTap,
      radius: s / 2,
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: s * 0.5),
      ),
    );
  }
}
