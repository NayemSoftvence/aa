// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import '../../providers/call_state_provider.dart';
import '../home/data/livekit_netlify_api.dart' show LivekitNetlifyApi;

class CallScreen extends StatefulWidget {
  final String callId;
  const CallScreen({super.key, required this.callId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _db = FirebaseFirestore.instance;

  Room? _room;
  EventsListener<RoomEvent>? _roomEvents;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;

  LocalVideoTrack? _localVideo; // keep ref to flip camera
  bool _micOn = true;
  bool _camOn = false; // Default: audio-only
  bool _speakerOn = false; // Default: not on speaker
  bool _frontCam = true;

  @override
  void initState() {
    super.initState();

    // Notify provider that call is starting and maximize (full screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final callProvider = context.read<CallStateProvider>();
      callProvider.startCall();
      callProvider.maximize();
    });

    _observeCallStatus();
    _join();
  }

  @override
  void dispose() {
    // Don't access context in dispose - widget is already deactivated
    _callSub?.cancel();
    _roomEvents?.dispose();
    _room?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _observeCallStatus() {
    final ref = _db.collection('calls').doc(widget.callId);
    _callSub = ref.snapshots().listen((snap) async {
      // Early return if widget is disposed - CHECK FIRST!
      if (!mounted) {
        print('[CallScreen] Widget disposed, ignoring status update');
        return;
      }

      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String?;
      if (status == 'ended' || status == 'declined') {
        try {
          await _room?.disconnect();
        } catch (_) {}
        // End CallKit notification
        await FlutterCallkitIncoming.endCall(widget.callId);

        // Double-check mounted before any context operations
        if (!mounted) {
          print('[CallScreen] Widget disposed during disconnect');
          return;
        }

        // Update provider before navigation
        try {
          final callProvider = context.read<CallStateProvider>();
          callProvider.endCall();
          // Overlay will hide automatically
        } catch (e) {
          print('[CallScreen] Error updating provider: $e');
        }
      }
    });
  }

  Future<void> _join() async {
    try {
      // 1) Request microphone (mandatory for audio call)
      final micStatus = await Permission.microphone.request();
      if (micStatus != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission required for call'),
          ),
        );
        if (mounted) context.read<CallStateProvider>().endCall();
        return;
      }
      
      // 2) Request camera (optional for audio-only calls)
      await Permission.camera.request();

      // 3) Get LiveKit token from Netlify (Dio inside)
      final cred = await LivekitNetlifyApi.instance.createToken(widget.callId);
      final url = cred['url'] as String;
      final token = cred['token'] as String;

      // 4) Connect to LiveKit
      final room = Room();
      _room = room;
      _roomEvents = room.createListener();

      await room.connect(
        url,
        token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      // 5) Publish audio track (always)
      final audio = await LocalAudioTrack.create();
      await room.localParticipant?.publishAudioTrack(audio);
      _micOn = true;

      // 6) Publish video only if user enables it later (optional)
      // _camOn is false by default, so no video track is published initially

      // 7) Keep screen on, use earpiece by default (not speaker)
      await WakelockPlus.enable();
      await Hardware.instance.setSpeakerphoneOn(false);
      _speakerOn = false;

      // 6) Room events: rerender when participants/tracks change, auto-close on disconnect
      _roomEvents?.on<RoomDisconnectedEvent>((_) {
        // Overlay handles hiding, no need to pop
      });
      _roomEvents?.on<ParticipantConnectedEvent>((event) {
        _updateParticipants();
        setState(() {});
      });
      _roomEvents?.on<ParticipantDisconnectedEvent>((event) {
        _updateParticipants();
        setState(() {});
      });
      _roomEvents?.on<TrackSubscribedEvent>((_) => setState(() {}));
      _roomEvents?.on<TrackUnsubscribedEvent>((_) => setState(() {}));
      _roomEvents?.on<LocalTrackPublishedEvent>((_) => setState(() {}));

      setState(() {});
      _updateParticipants();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Join failed: $e')));
      // Navigator.pop(context);
      if (mounted) context.read<CallStateProvider>().endCall();
    }
  }

  void _updateParticipants() {
    if (_room != null && mounted) {
      final participants = <Participant>[
        if (_room!.localParticipant != null) _room!.localParticipant!,
        ..._room!.remoteParticipants.values,
      ];
      final callProvider = context.read<CallStateProvider>();
      callProvider.updateParticipants(participants);
    }
  }

  Future<void> _hangUp() async {
    try {
      // 1) Immediately set provider state to prevent re-rendering
      if (mounted) {
        final callProvider = context.read<CallStateProvider>();
        callProvider.endCall();
      }
      
      // 2) Disconnect LiveKit room
      await _room?.disconnect();
      
      // 3) Update Firestore
      try {
        await _db.collection('calls').doc(widget.callId).update({
          'status': 'ended',
          'endedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        // Log but don't fail if Firestore update fails
        print('[CallScreen] Firestore update failed: $e');
      }

      // 4) Notify other participant and clean up CallKit
      try {
        await LivekitNetlifyApi.instance.notifyCallEnded(widget.callId);
        await FlutterCallkitIncoming.endCall(widget.callId);
      } catch (e) {
        print('[CallScreen] Cleanup failed: $e');
      }
    } catch (e) {
      print('[CallScreen] Hang-up error: $e');
      // Still try to end call via provider
      if (mounted) {
        context.read<CallStateProvider>().endCall();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;

    return Container(
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: WillPopScope(
        onWillPop: () async {
          // On back press, just minimize - overlay handles hiding
          final callProvider = context.read<CallStateProvider>();
          callProvider.minimize();
          return false; // Prevent default back behavior
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('In Call'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: () {
                // Minimize call (overlay will hide automatically)
                final callProvider = context.read<CallStateProvider>();
                callProvider.minimize();
              },
            ),
            actions: [
              // Add minimize action button for clarity
              TextButton.icon(
                onPressed: () {
                  final callProvider = context.read<CallStateProvider>();
                  callProvider.minimize();
                },
                icon: const Icon(Icons.minimize, color: Colors.white),
                label: const Text(
                  'Minimize',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: room == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(child: _videoGrid(room)),
                    _controlsBar(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _videoGrid(Room room) {
    // For audio-only calls, show a simple UI with participant info
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return const Center(
        child: Text('Connecting…', style: TextStyle(color: Colors.white70)),
      );
    }

    // Audio-only layout: show participant info in a simple list
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: participants.map((p) {
          final isLocal = p == room.localParticipant;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade700,
                  child: Icon(
                    isLocal ? Icons.person : Icons.person_outline,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  isLocal ? 'You' : 'Caller',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _controlsBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundBtn(
              icon: _micOn ? Icons.mic : Icons.mic_off,
              onTap: () async {
                _micOn = !_micOn;
                await _room?.localParticipant?.setMicrophoneEnabled(_micOn);
                // Update provider
                final callProvider = context.read<CallStateProvider>();
                callProvider.setMuted(!_micOn);
                setState(() {});
              },
            ),
            _roundBtn(
              icon: _camOn ? Icons.videocam : Icons.videocam_off,
              onTap: () async {
                // TODO: Video on/off toggling can be implemented later if needed
                // For now, audio-only calls are the default
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Video call coming soon')),
                );
              },
            ),
            _roundBtn(
              icon: _speakerOn ? Icons.volume_up : Icons.hearing,
              onTap: () async {
                _speakerOn = !_speakerOn;
                try {
                  await Hardware.instance.setSpeakerphoneOn(_speakerOn);
                  final callProvider = context.read<CallStateProvider>();
                  callProvider.setSpeakerOn(_speakerOn);
                  setState(() {});
                } catch (e) {
                  print('[CallScreen] Speaker toggle failed: $e');
                }
              },
            ),
            _roundBtn(icon: Icons.call_end, bg: Colors.red, onTap: _hangUp),
          ],
        ),
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color bg = const Color(0x33FFFFFF),
  }) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
