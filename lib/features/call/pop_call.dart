import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../providers/call_state_provider.dart';
import '../home/data/livekit_netlify_api.dart'; // adjust import path

class PopCall extends StatefulWidget {
  final String callId;
  const PopCall({super.key, required this.callId});

  @override
  State<PopCall> createState() => _PopCallState();
}

class _PopCallState extends State<PopCall> {
  final _db = FirebaseFirestore.instance;

  Room? _room;
  EventsListener<RoomEvent>? _roomEvents;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _callSub;

  LocalVideoTrack? _localVideo;
  bool _micOn = true;
  bool _camOn = true;
  bool _speakerOn = true;
  bool _frontCam = true;

  @override
  void initState() {
    super.initState();

    // Mark call as active + maximize in provider
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
    _callSub?.cancel();
    _roomEvents?.dispose();
    _room?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  // Listen to Firestore doc and close when call is ended/declined
  void _observeCallStatus() {
    final ref = _db.collection('calls').doc(widget.callId);
    _callSub = ref.snapshots().listen((snap) async {
      if (!mounted) return;
      final data = snap.data();
      if (data == null) return;

      final status = data['status'] as String?;
      if (status == 'ended' || status == 'declined') {
        try {
          await _room?.disconnect();
        } catch (_) {}
        await FlutterCallkitIncoming.endCall(widget.callId);

        if (!mounted) return;
        context.read<CallStateProvider>().endCall();
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(); // close sheet
        }
      }
    });
  }

  // Join LiveKit room
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
        context.read<CallStateProvider>().endCall();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
        return;
      }

      // 2) Get LiveKit token from Netlify
      final cred = await LivekitNetlifyApi.instance.createToken(widget.callId);
      final url = cred['url'] as String;
      final token = cred['token'] as String;

      // 3) Connect
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

      // 5) Keep screen awake + speaker on
      await WakelockPlus.enable();
      await Hardware.instance.setSpeakerphoneOn(true);
      _speakerOn = true;

      // 6) Room events
      _roomEvents?.on<ParticipantConnectedEvent>((_) {
        _updateParticipants();
        setState(() {});
      });
      _roomEvents?.on<ParticipantDisconnectedEvent>((_) {
        _updateParticipants();
        setState(() {});
      });
      _roomEvents?.on<TrackSubscribedEvent>((_) => setState(() {}));
      _roomEvents?.on<TrackUnsubscribedEvent>((_) => setState(() {}));
      _roomEvents?.on<LocalTrackPublishedEvent>((_) => setState(() {}));
      _roomEvents?.on<RoomDisconnectedEvent>((_) {
        if (mounted) {
          context.read<CallStateProvider>().endCall();
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      });

      _updateParticipants();
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Join failed: $e')));
      context.read<CallStateProvider>().endCall();
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }
  }

  void _updateParticipants() {
    if (!mounted || _room == null) return;
    final participants = <Participant>[
      if (_room!.localParticipant != null) _room!.localParticipant!,
      ..._room!.remoteParticipants.values,
    ];
    context.read<CallStateProvider>().updateParticipants(participants);
  }

  Future<void> _hangUp() async {
    try {
      await _room?.disconnect();
    } finally {
      await _db.collection('calls').doc(widget.callId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Notify other participant (your existing Netlify API)
      await LivekitNetlifyApi.instance.notifyCallEnded(widget.callId);
      await FlutterCallkitIncoming.endCall(widget.callId);

      if (mounted) {
        context.read<CallStateProvider>().endCall();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      }
    }
  }

  VideoTrack? _firstVideoTrack(Participant p) {
    for (final pub in p.videoTrackPublications) {
      final track = pub.track;
      if (track is VideoTrack) return track;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final call = context.watch<CallStateProvider>();

    return WillPopScope(
      onWillPop: () async {
        // Back button -> just minimize call (sheet closes)
        context.read<CallStateProvider>().minimize();
        return true;
      },
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82, // ~80% height
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            _header(call),
            const Divider(height: 1, color: Colors.white12),
            Expanded(
              child:
                  room == null
                      ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                      : _videoArea(room),
            ),
            _controlsBar(),
          ],
        ),
      ),
    );
  }

  // Top area: handle + name + timer + minimize button
  Widget _header(CallStateProvider call) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          children: [
            // Small drag handle visual
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        call.callerId ?? 'In call',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        call.formattedDuration,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    context.read<CallStateProvider>().minimize();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Middle: main video + local preview
  Widget _videoArea(Room room) {
    final participants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (participants.isEmpty) {
      return const Center(
        child: Text('Connecting…', style: TextStyle(color: Colors.white70)),
      );
    }

    final remoteParticipants = participants
        .where((p) => p != room.localParticipant)
        .toList(growable: false);

    final mainParticipant =
        remoteParticipants.isNotEmpty
            ? remoteParticipants.first
            : participants.first;

    final mainTrack = _firstVideoTrack(mainParticipant);
    final selfTrack =
        room.localParticipant != null
            ? _firstVideoTrack(room.localParticipant!)
            : null;

    return Stack(
      children: [
        Positioned.fill(
          child:
              mainTrack != null
                  ? VideoTrackRenderer(mainTrack, fit: VideoViewFit.cover)
                  : Container(
                    color: Colors.grey.shade900,
                    child: const Center(
                      child: Icon(
                        Icons.videocam_off,
                        color: Colors.white54,
                        size: 40,
                      ),
                    ),
                  ),
        ),
        if (selfTrack != null)
          Positioned(
            right: 12,
            bottom: 12,
            width: 110,
            height: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black54,
                child: VideoTrackRenderer(selfTrack, fit: VideoViewFit.cover),
              ),
            ),
          ),
      ],
    );
  }

  // Bottom: control buttons
  Widget _controlsBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _roundBtn(
              icon: _micOn ? Icons.mic : Icons.mic_off,
              onTap: () async {
                _micOn = !_micOn;
                await _room?.localParticipant?.setMicrophoneEnabled(_micOn);
                context.read<CallStateProvider>().setMuted(!_micOn);
                setState(() {});
              },
            ),
            _roundBtn(
              icon: _camOn ? Icons.videocam : Icons.videocam_off,
              onTap: () async {
                _camOn = !_camOn;
                await _room?.localParticipant?.setCameraEnabled(_camOn);
                context.read<CallStateProvider>().setCameraOn(_camOn);
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
                } catch (_) {}
                setState(() {});
              },
            ),
            _roundBtn(
              icon: _speakerOn ? Icons.volume_up : Icons.hearing,
              onTap: () async {
                _speakerOn = !_speakerOn;
                await Hardware.instance.setSpeakerphoneOn(_speakerOn);
                context.read<CallStateProvider>().setSpeakerOn(_speakerOn);
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
