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
  bool _camOn = true;
  bool _speakerOn = true;
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
      // 1) Permissions
      final statuses =
          await [Permission.microphone, Permission.camera].request();
      if (statuses[Permission.microphone] != PermissionStatus.granted ||
          statuses[Permission.camera] != PermissionStatus.granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera/Microphone permission required'),
          ),
        );
        // Navigator.pop(context); // Don't pop, overlay will stay or should be manually minimized/closed via provider logic if we want to force close
        // Better: trigger endCall on provider
        if (mounted) context.read<CallStateProvider>().endCall();
        return;
      }

      // 2) Get LiveKit token from Netlify (Dio inside)
      final cred = await LivekitNetlifyApi.instance.createToken(widget.callId);
      final url = cred['url'] as String;
      final token = cred['token'] as String;

      // 3) Connect to LiveKit
      final room = Room();
      _room = room;
      _roomEvents = room.createListener();

      await room.connect(
        url,
        token,
        connectOptions: const ConnectOptions(autoSubscribe: true),
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );

      // 4) Publish local tracks
      final video = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(cameraPosition: CameraPosition.front),
      );
      final audio = await LocalAudioTrack.create();

      _localVideo = video;
      _frontCam = true;

      await room.localParticipant?.publishVideoTrack(video);
      await room.localParticipant?.publishAudioTrack(audio);

      // 5) Keep screen on, route to speaker
      await WakelockPlus.enable();
      await Hardware.instance.setSpeakerphoneOn(true);
      _speakerOn = true;

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
      await _room?.disconnect();
    } finally {
      await _db.collection('calls').doc(widget.callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // CRITICAL: Notify other participant to stop ringing if they are in background key
      await LivekitNetlifyApi.instance.notifyCallEnded(widget.callId);
      await FlutterCallkitIncoming.endCall(widget.callId);

      // Update provider
      if (mounted) {
        final callProvider = context.read<CallStateProvider>();
        callProvider.endCall();
      }

      if (mounted) {
        // Just rely on provider state change to hide the overlay.
        // No need to pop navigator as we are in an overlay now.
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
          body:
              room == null
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

  // Find first available video track for a participant
  VideoTrack? _firstVideoTrack(Participant p) {
    // publications is an Iterable of VideoTrackPublication
    for (final pub in p.videoTrackPublications) {
      final track = pub.track;
      if (track is VideoTrack) return track;
    }
    return null;
  }

  Widget _videoGrid(Room room) {
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return const Center(
        child: Text('Connecting…', style: TextStyle(color: Colors.white70)),
      );
    }

    return GridView.builder(
      itemCount: participants.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 9 / 16,
      ),
      itemBuilder: (context, index) {
        final p = participants[index];
        final track = _firstVideoTrack(p);

        return Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child:
                track != null
                    ? VideoTrackRenderer(track, fit: VideoViewFit.contain)
                    : const Center(
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                        size: 32,
                      ),
                    ),
          ),
        );
      },
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
                _camOn = !_camOn;
                await _room?.localParticipant?.setCameraEnabled(_camOn);
                // Update provider
                final callProvider = context.read<CallStateProvider>();
                callProvider.setCameraOn(_camOn);
                setState(() {});
              },
            ),
            _roundBtn(
              icon: Icons.cameraswitch,
              onTap: () async {
                if (_localVideo == null) return;
                _frontCam = !_frontCam;
                try {
                  await _localVideo!.setCameraPosition(
                    _frontCam ? CameraPosition.front : CameraPosition.back,
                  );
                } catch (_) {
                  // best-effort; ignore if device doesn't support it
                }
                setState(() {});
              },
            ),
            _roundBtn(
              icon: _speakerOn ? Icons.volume_up : Icons.hearing,
              onTap: () async {
                _speakerOn = !_speakerOn;
                await Hardware.instance.setSpeakerphoneOn(_speakerOn);
                // Update provider
                final callProvider = context.read<CallStateProvider>();
                callProvider.setSpeakerOn(_speakerOn);
                setState(() {});
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
