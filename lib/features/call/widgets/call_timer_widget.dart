import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

import '../../../providers/call_state_provider.dart';

class CallTimerWidget extends StatelessWidget {
  final TextStyle? style;

  const CallTimerWidget({super.key, this.style});

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, provider, _) {
        return Text(
          provider.formattedDuration,
          style: style ??
              TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
        );
      },
    );
  }
}

/// Animated call timer with blinking recording indicator
class AnimatedCallTimer extends StatefulWidget {
  final TextStyle? style;
  final bool showRecordingIndicator;

  const AnimatedCallTimer({
    super.key,
    this.style,
    this.showRecordingIndicator = false,
  });

  @override
  State<AnimatedCallTimer> createState() => _AnimatedCallTimerState();
}

class _AnimatedCallTimerState extends State<AnimatedCallTimer>
    with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.showRecordingIndicator)
              AnimatedBuilder(
                animation: _blinkController,
                builder: (context, _) {
                  return Container(
                    width: 8.w,
                    height: 8.h,
                    margin: EdgeInsets.only(right: 8.w),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(_blinkController.value),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
            Text(
              provider.formattedDuration,
              style: widget.style ??
                  TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        );
      },
    );
  }
}
