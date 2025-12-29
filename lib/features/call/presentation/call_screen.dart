import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import '../../../constants/call_constants.dart';
import '../../../helpers/call_manager.dart';
import '../../../providers/call_state_provider.dart';
import '../widgets/call_controls_bar.dart';
import '../widgets/connection_quality_indicator.dart';
import '../widgets/participant_avatar.dart';

class CallScreen extends StatefulWidget {
  final String callId;

  const CallScreen({super.key, required this.callId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  CallManager get _callManager => CallManager.instance;

  @override
  void initState() {
    super.initState();

    // Notify provider to maximize
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callProvider = context.read<CallStateProvider>();
      // Don't auto-start call here - let call manager handle connection
      // Just ensure UI is maximized
      if (callProvider.isMinimized) {
        callProvider.maximize();
      }
    });
  }

  @override
  void dispose() {
    log('[CallScreen] Disposing');
    super.dispose();
  }

  Future<void> _handleHangUp() async {
    await _callManager.endCall();
  }

  void _handleMinimize() {
    context.read<CallStateProvider>().minimize();
  }

  Future<void> _handleAcceptCall() async {
    final callProvider = context.read<CallStateProvider>();
    final callId = callProvider.callId;

    if (callId == null) {
      log('[CallScreen] No call ID to accept');
      return;
    }

    // PROBLEM 2 FIX: Use CallManager to accept the call (which also joins room)
    final success = await _callManager.acceptCall();
    log('[CallScreen] Accept result: $success');

    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to accept call')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        final room = _callManager.room;
        final isConnected = callProvider.isInCall;
        final isReconnecting = callProvider.state == CallState.reconnecting;
        final isIncomingRinging =
            callProvider.state == CallState.incomingRinging;

        return Container(
          height: MediaQuery.of(context).size.height,
          decoration: const BoxDecoration(color: Colors.black),
          child: PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (!didPop) {
                _handleMinimize();
              }
            },
            child: Scaffold(
              backgroundColor: Colors.black, // Opaque black
              body: SafeArea(
                child: Column(
                  children: [
                    // Top App Bar - Fixed part of column
                    if (!isIncomingRinging) _buildOverlayAppBar(callProvider),

                    // Main Content
                    Expanded(
                      child: Column(
                        children: [
                          // Error message
                          if (callProvider.errorMessage != null)
                            _buildErrorBanner(callProvider.errorMessage!),

                          // Reconnecting indicator
                          if (isReconnecting) _buildReconnectingBanner(),

                          // The Views
                          Expanded(
                            child: isIncomingRinging
                                ? _buildIncomingRingingView(callProvider)
                                : (room == null || !isConnected
                                    ? _buildConnectingView()
                                    : _buildCallView(room, callProvider)),
                          ),
                        ],
                      ),
                    ),

                    // Controls (Bottom)
                    if (isIncomingRinging)
                      _buildIncomingCallActions()
                    else
                      CallControlsBar(
                        isMuted: callProvider.isMuted,
                        isSpeakerOn: callProvider.isSpeakerOn,
                        isCameraOn: callProvider.isCameraOn,
                        onMuteToggle: _callManager.toggleMute,
                        onSpeakerToggle: _callManager.toggleSpeaker,
                        onCameraToggle: _callManager.toggleCamera,
                        onHangUp: _handleHangUp,
                        showCameraButton: true,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOverlayAppBar(CallStateProvider callProvider) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.keyboard_arrow_down,
                color: Colors.white, size: 28.r),
            onPressed: _handleMinimize,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callProvider.displayName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  callProvider.stateDescription,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          ConnectionQualityIndicator(quality: callProvider.connectionQuality),
          SizedBox(width: 16.w),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.red.shade800,
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReconnectingBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade800,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'Reconnecting...',
            style: TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Connecting...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildCallView(Room room, CallStateProvider callProvider) {
    if (room.localParticipant == null && room.remoteParticipants.isEmpty) {
      return _buildConnectingView();
    }

    final remoteP = room.remoteParticipants.values.isNotEmpty
        ? room.remoteParticipants.values.first
        : null;
    final localP = room.localParticipant;

    return Column(
      children: [
        // Remote Participant (Top Half)
        if (remoteP != null)
          Expanded(
            child: _buildSingleParticipantView(
              remoteP,
              isLocal: false,
              fit: VideoViewFit.cover,
            ),
          ),

        // Divider (Optional, or just straight cut)
        if (remoteP != null && localP != null) SizedBox(height: 2.h),

        // Local Participant (Bottom Half or Full if alone)
        if (localP != null)
          Expanded(
            child: _buildSingleParticipantView(
              localP,
              isLocal: true,
              fit: VideoViewFit.cover,
            ),
          ),
      ],
    );
  }

  Widget _buildSingleParticipantView(
    Participant p, {
    required bool isLocal,
    VideoViewFit fit = VideoViewFit.cover,
    bool isPip = false,
  }) {
    // Get first available video track
    VideoTrack? videoTrack;
    for (final pub in p.videoTrackPublications) {
      if (pub.track is VideoTrack) {
        videoTrack = pub.track as VideoTrack;
        break;
      }
    }

    if (videoTrack != null) {
      return VideoTrackRenderer(
        videoTrack,
        fit: fit,
      );
    } else {
      final safeName = _getSafeName(p.name, p.identity);

      return Container(
        color: Colors.grey[900],
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ParticipantAvatar(
                name: isLocal ? 'You' : safeName,
                isLocal: isLocal,
                isMuted: !p.isMicrophoneEnabled(),
                isSpeaking: p.isSpeaking,
                size: isPip ? 40.r : 80.r,
                showName:
                    false, // Fix: Disable internal name to prevent double rendering
              ),
              if (!isPip) ...[
                SizedBox(height: 16.h),
                Text(
                  isLocal ? 'You' : safeName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ]
            ],
          ),
        ),
      );
    }
  }

  String _getSafeName(String? name, String? identity) {
    if (name == null || name.isEmpty) return 'Guest';
    // If name matches identity (often means no name set) or looks like an ID
    if (name == identity || (name.length > 15 && !name.contains(' '))) {
      return 'Guest';
    }
    return name;
  }

  Widget _buildIncomingRingingView(CallStateProvider callProvider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey[700],
            child: const Icon(
              Icons.person,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            callProvider.displayName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Incoming call...',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingCallActions() {
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
            // Decline button
            FloatingActionButton(
              onPressed: _handleHangUp,
              backgroundColor: Colors.red,
              child: const Icon(Icons.call_end, color: Colors.white),
            ),
            // Accept button
            FloatingActionButton(
              onPressed: _handleAcceptCall,
              backgroundColor: Colors.green,
              child: const Icon(Icons.call, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
