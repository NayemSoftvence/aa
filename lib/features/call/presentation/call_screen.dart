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

  @override
  Widget build(BuildContext context) {
    return Consumer<CallStateProvider>(
      builder: (context, callProvider, _) {
        final room = _callManager.room;
        final isConnected = callProvider.isInCall;
        final isReconnecting = callProvider.state == CallState.reconnecting;

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
                    child: room == null || !isConnected
                        ? _buildConnectingView()
                        : _buildCallView(room, callProvider),
                  ),

                  // Controls
                  CallControlsBar(
                    isMuted: callProvider.isMuted,
                    isSpeakerOn: callProvider.isSpeakerOn,
                    isCameraOn: callProvider.isCameraOn,
                    onMuteToggle: _callManager.toggleMute,
                    onSpeakerToggle: _callManager.toggleSpeaker,
                    onCameraToggle: _callManager.toggleCamera,
                    onHangUp: _handleHangUp,
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

    // Audio-only layout: show participant avatars
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: participants.map((p) {
          final isLocal = p == room.localParticipant;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ParticipantAvatar(
              name: isLocal ? 'You' : (p.name ?? 'Caller'),
              isLocal: isLocal,
              isMuted: !p.isMicrophoneEnabled(),
              isSpeaking: p.isSpeaking,
            ),
          );
        }).toList(),
      ),
    );
  }
}
