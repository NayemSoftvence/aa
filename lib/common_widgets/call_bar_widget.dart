import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: _getBackgroundColor(callProvider.state),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4.r,
                  offset: Offset(0, 2.h),
                ),
              ],
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  // Call indicator icon
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getIcon(callProvider.state),
                      color: Colors.white,
                      size: 18.r,
                    ),
                  ),
                  SizedBox(width: 12.w),

                  // Call info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          callProvider.displayName,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.sp,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          children: [
                            if (callProvider.isInCall) ...[
                              CallTimerWidget(
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              ConnectionQualityIndicator(
                                quality: callProvider.connectionQuality,
                                barWidth: 3.w,
                                maxHeight: 12.h,
                              ),
                            ] else
                              Text(
                                callProvider.stateDescription,
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12.sp,
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
                      padding: EdgeInsets.all(6.w),
                      margin: EdgeInsets.only(right: 8.w),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mic_off,
                        color: Colors.white,
                        size: 16.r,
                      ),
                    ),

                  // End call button
                  IconButton(
                    onPressed: () => CallManager.instance.endCall(),
                    icon: const Icon(Icons.call_end, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: EdgeInsets.all(8.w),
                    ),
                    iconSize: 20.r,
                  ),

                  // Expand button
                  IconButton(
                    onPressed: () => callProvider.maximize(),
                    icon: Icon(
                      Icons.open_in_full,
                      color: Colors.white,
                      size: 20.r,
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
