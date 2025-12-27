import 'dart:developer';

import 'package:flutter/material.dart';
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

    // Notify provider that call is starting and maximize (full screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callProvider = context.read<CallStateProvider>();
      if (callProvider.state != CallState.inCall) {
        callProvider.startCall();
      }
      callProvider.maximize();
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
    callProvider.acceptCall();
    callProvider.startCall();
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
              backgroundColor: Colors.transparent,
              appBar: _buildAppBar(callProvider),
              body: Column(
                children: [
                  // Error message
                  if (callProvider.errorMessage != null)
                    _buildErrorBanner(callProvider.errorMessage!),

                  // Reconnecting indicator
                  if (isReconnecting) _buildReconnectingBanner(),

                  // Main content
                  Expanded(
                    child: isIncomingRinging
                        ? _buildIncomingRingingView(callProvider)
                        : (room == null || !isConnected
                            ? _buildConnectingView()
                            : _buildCallView(room, callProvider)),
                  ),

                  // Controls - show call controls or accept/decline buttons
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
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(CallStateProvider callProvider) {
    return AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: _handleMinimize,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            callProvider.displayName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          Text(
            callProvider.stateDescription,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
          ),
        ],
      ),
      actions: [
        ConnectionQualityIndicator(quality: callProvider.connectionQuality),
        const SizedBox(width: 16),
      ],
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
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for others...',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    // Video layout: show video tracks with fallback to avatars
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 9 / 16,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        final isLocal = p == room.localParticipant;

        // Get first available video track
        VideoTrack? videoTrack;
        for (final pub in p.videoTrackPublications) {
          if (pub.track is VideoTrack) {
            videoTrack = pub.track as VideoTrack;
            break;
          }
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: videoTrack != null
                ? Stack(
                    children: [
                      VideoTrackRenderer(
                        videoTrack,
                        fit: VideoViewFit.contain,
                      ),
                      // Show name overlay at bottom
                      Positioned(
                        bottom: 8,
                        left: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isLocal
                                ? 'You'
                                : (p.name.isNotEmpty ? p.name : 'Guest'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.videocam_off,
                          color: Colors.white54,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        ParticipantAvatar(
                          name: isLocal
                              ? 'You'
                              : (p.name.isNotEmpty ? p.name : 'Guest'),
                          isLocal: isLocal,
                          isMuted: !p.isMicrophoneEnabled(),
                          isSpeaking: p.isSpeaking,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
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
