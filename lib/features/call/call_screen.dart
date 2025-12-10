import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:livekit_calling_app/features/home/presentation/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;

// TODO: change to your actual path
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
    _observeCallStatus();
    _join();
  }

  @override
  void dispose() {
    _callSub?.cancel();
    _roomEvents?.dispose();
    _room?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _observeCallStatus() {
    final ref = _db.collection('calls').doc(widget.callId);
    _callSub = ref.snapshots().listen((snap) async {
      final data = snap.data();
      if (data == null) return;
      final status = data['status'] as String?;
      if (status == 'ended' || status == 'declined') {
        try {
          await _room?.disconnect();
        } catch (_) {}
        if (mounted) Navigator.maybePop(context);
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
        Navigator.pop(context);
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
        if (mounted) Navigator.maybePop(context);
      });
      _roomEvents?.on<ParticipantConnectedEvent>((_) => setState(() {}));
      _roomEvents?.on<ParticipantDisconnectedEvent>((_) => setState(() {}));
      _roomEvents?.on<TrackSubscribedEvent>((_) => setState(() {}));
      _roomEvents?.on<TrackUnsubscribedEvent>((_) => setState(() {}));
      //   _roomEvents?.on<TrackMutedUpdatedEvent>((_) => setState(() {}));
      _roomEvents?.on<LocalTrackPublishedEvent>((_) => setState(() {}));

      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Join failed: $e')));
      Navigator.pop(context);
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
      if (mounted) Get.offAll(() => const HomeScreen());
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;

    return WillPopScope(
      onWillPop: () async {
        await _hangUp();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('In Call'),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          actions: [
            // IconButton(
            //   tooltip: 'End call',
            //   onPressed: _hangUp,
            //   icon: const Icon(Icons.call_end, color: Colors.redAccent),
            // ),
          ],
        ),
        body:
            room == null
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [Expanded(child: _videoGrid(room)), _controlsBar()],
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
                setState(() {});
              },
            ),
            _roundBtn(
              icon: _camOn ? Icons.videocam : Icons.videocam_off,
              onTap: () async {
                _camOn = !_camOn;
                await _room?.localParticipant?.setCameraEnabled(_camOn);
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
