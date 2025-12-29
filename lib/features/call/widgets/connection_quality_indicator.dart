import 'package:flutter/material.dart';

import '../../../constants/call_constants.dart';

class ConnectionQualityIndicator extends StatelessWidget {
  final ConnectionQuality quality;
  final double barWidth;
  final double maxHeight;

  const ConnectionQualityIndicator({
    super.key,
    required this.quality,
    this.barWidth = 4,
    this.maxHeight = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (index) {
        final isActive = _getActiveBarCount() > index;
        final height = (maxHeight / 4) * (index + 1);

        return Container(
          width: barWidth,
          height: height,
          margin: EdgeInsets.symmetric(horizontal: barWidth / 4),
          decoration: BoxDecoration(
            color: isActive ? _getColor() : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(barWidth / 2),
          ),
        );
      }),
    );
  }

  int _getActiveBarCount() {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 4;
      case ConnectionQuality.good:
        return 3;
      case ConnectionQuality.poor:
        return 2;
      case ConnectionQuality.disconnected:
        return 0;
    }
  }

  Color _getColor() {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.green;
      case ConnectionQuality.poor:
        return Colors.orange;
      case ConnectionQuality.disconnected:
        return Colors.red;
    }
  }
}

/// Text-based connection quality display
class ConnectionQualityText extends StatelessWidget {
  final ConnectionQuality quality;
  final TextStyle? style;

  const ConnectionQualityText({
    super.key,
    required this.quality,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _getColor(),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          _getText(),
          style: style ?? TextStyle(color: _getColor(), fontSize: 12),
        ),
      ],
    );
  }

  String _getText() {
    switch (quality) {
      case ConnectionQuality.excellent:
        return 'Excellent';
      case ConnectionQuality.good:
        return 'Good';
      case ConnectionQuality.poor:
        return 'Poor';
      case ConnectionQuality.disconnected:
        return 'Disconnected';
    }
  }

  Color _getColor() {
    switch (quality) {
      case ConnectionQuality.excellent:
        return Colors.green;
      case ConnectionQuality.good:
        return Colors.green;
      case ConnectionQuality.poor:
        return Colors.orange;
      case ConnectionQuality.disconnected:
        return Colors.red;
    }
  }
}
