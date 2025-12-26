import 'dart:async';
import 'dart:developer';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../constants/call_constants.dart';
import '../features/call/data/call_repository.dart';
import '../features/call/data/rx_livekit_notify/rx.dart';
import '../features/call/data/rx_livekit_token/rx.dart';
import '../features/call/model/call_model.dart';
import '../features/call/model/participant_model.dart';
import '../providers/call_state_provider.dart';
import 'di.dart';

class CallManager {
  static CallManager? _instance;
  static CallManager get instance => _instance ??= CallManager._();
  CallManager._();

  CallRepository get _callRepository => locate<CallRepository>();
  LivekitTokenRx get _tokenRx => locate<LivekitTokenRx>();
  LivekitNotifyRx get _notifyRx => locate<LivekitNotifyRx>();

  CallStateProvider? _callProvider;
  Room? _room;
  EventsListener<RoomEvent>? _roomEvents;
  StreamSubscription? _callDocSubscription;
  Timer? _ringTimeout;

  bool _isCallInProgress = false;
  bool _isAccepting = false; // Single accept lock

  bool get isReady => _callProvider != null;
  String? get currentCallId => _callProvider?.callId;
  CallState? get currentState => _callProvider?.state;
  Room? get room => _room;
  bool get isInRoom => _room?.connectionState == ConnectionState.connected;

  void registerProvider(CallStateProvider p) {
    _callProvider = p;
    _log('Provider registered');
  }

  CallStateProvider get _provider {
    if (_callProvider == null) throw StateError('Provider not registered');
    return _callProvider!;
  }

  void _log(String msg, {Object? error, StackTrace? stackTrace}) {
    final m = '[${DateTime.now().toIso8601String()}][CallManager] $msg';
    log(m, error: error, stackTrace: stackTrace);
    print(m);
  }

  // ==================== OUTGOING ====================

  Future<bool> startCall({
    required String calleeId,
    required String calleeName,
    String? calleePhoto,
    CallType type = CallType.audio,
  }) async {
    if (_isCallInProgress) return false;
    _isCallInProgress = true;

    try {
      if (_provider.hasActiveCall) {
        _provider.setError('Already in a call');
        return false;
      }
      if (!await _checkPermissions(type)) return false;
      if (await _callRepository.isUserBusy(calleeId)) {
        _provider.setError('$calleeName is busy');
        return false;
      }

      final call = await _callRepository.createCall(
        calleeId: calleeId,
        calleeName: calleeName,
        calleePhoto: calleePhoto,
        type: type,
      );

      _provider.startOutgoingCall(call);
      _startRingTimeout(call.id);
      _watchCallStatus(call.id);
      unawaited(_notifyRx.notifyIncoming(call.id).catchError((_) {}));

      _log('Outgoing: ${call.id}');
      return true;
    } catch (e, st) {
      _log('Start failed', error: e, stackTrace: st);
      _provider.setError('Failed to start');
      _cleanup();
      return false;
    } finally {
      _isCallInProgress = false;
    }
  }

  // ==================== INCOMING ====================

  Future<void> handleIncomingCall(CallModel call) async {
    _log(
        'handleIncoming: ${call.id}, current: $currentCallId, state: $currentState');

    // Already handling this exact call
    if (currentCallId == call.id) {
      _log('Already handling');
      _watchCallStatus(call.id);
      return;
    }

    // In a different call
    if (_provider.hasActiveCall) {
      _log('Busy, marking');
      await _callRepository.markBusy(call.id);
      await FlutterCallkitIncoming.endCall(call.id);
      return;
    }

    _provider.handleIncomingCall(call);
    _watchCallStatus(call.id);
    _log('Set up: ${call.id}, state: ${_provider.state}');
  }

  Future<bool> acceptCall() async {
    final callId = _provider.callId;
    final state = _provider.state;

    _log('acceptCall: $callId, state=$state, isAccepting=$_isAccepting');

    if (callId == null) {
      _log('No call');
      return false;
    }

    // CRITICAL: Prevent duplicate accepts
    if (_isAccepting) {
      _log('Already accepting');
      return false;
    }

    // Already fully connected
    if (state == CallState.inCall && isInRoom) {
      _log('Already connected');
      return true;
    }

    // Already connecting
    if (state == CallState.connecting) {
      _log('Already connecting');
      return false;
    }

    // Must be in ringing state
    if (state != CallState.incomingRinging) {
      _log('Cannot accept from: $state');
      return false;
    }

    _isAccepting = true;
    _ringTimeout?.cancel();

    try {
      final type = _provider.currentCall?.type ?? CallType.audio;
      if (!await _checkPermissions(type)) {
        await declineCall();
        return false;
      }

      // Update Firestore
      try {
        await _callRepository.acceptCall(callId);
        _log('Firestore updated');
      } catch (e) {
        _log('Firestore error: $e');
      }

      // Move to connecting state
      _provider.acceptCall();
      _log('State: ${_provider.state}');

      unawaited(_notifyRx.notifyAccepted(callId).catchError((_) {}));

      // Join room
      _log('Joining room...');
      final success = await _joinRoom(callId);
      _log('Join result: $success');

      if (success) {
        _provider.startCall(); // Only works from connecting state
        await FlutterCallkitIncoming.setCallConnected(callId);
        _log('Connected!');
        return true;
      } else {
        _provider.setError('Failed to connect');
        await endCall();
        return false;
      }
    } catch (e, st) {
      _log('Accept error', error: e, stackTrace: st);
      _provider.setError('Accept failed');
      return false;
    } finally {
      _isAccepting = false;
    }
  }

  // ==================== END ====================

  Future<void> declineCall() async {
    final callId = _provider.callId;
    if (callId == null) return;

    _log('Declining: $callId');
    try {
      await _callRepository.declineCall(callId);
      unawaited(_notifyRx.notifyDeclined(callId).catchError((_) {}));
      await FlutterCallkitIncoming.endCall(callId);
    } catch (e) {
      _log('Decline error: $e');
    }
    _cleanup();
    _provider.endCall();
  }

  Future<void> endCall() async {
    final callId = _provider.callId;
    if (callId == null || _provider.state == CallState.idle) return;

    _log('Ending: $callId');
    _provider.endCall();
    await _leaveRoom();

    try {
      await _callRepository.endCall(callId);
    } catch (e) {
      _log('Firestore error: $e');
    }

    unawaited(_notifyRx.notifyEnded(callId).catchError((_) {}));
    await FlutterCallkitIncoming.endCall(callId);
    _cleanup();
  }

  // ==================== ROOM ====================

  Future<bool> _joinRoom(String callId) async {
    _log('Join: $callId');

    try {
      // Token
      var ok = false;
      for (var i = 1; i <= 3; i++) {
        try {
          ok = await _tokenRx
              .fetchToken(callId)
              .timeout(const Duration(seconds: 10));
          if (ok) break;
        } catch (e) {
          _log('Token $i: $e');
        }
        if (i < 3) await Future.delayed(Duration(milliseconds: 300 * i));
      }
      if (!ok) {
        _log('Token failed');
        return false;
      }

      final creds = _tokenRx.credentials;
      if (creds == null || !creds.isValid) {
        _log('Invalid creds');
        return false;
      }

      _log('Connecting: ${creds.url}');

      _room = Room(
          roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioPublishOptions:
            AudioPublishOptions(audioBitrate: AudioPreset.speech),
      ));
      _roomEvents = _room!.createListener();

      var connected = false;
      for (var i = 1; i <= 2; i++) {
        try {
          await _room!
              .connect(creds.url!, creds.token!,
                  connectOptions: const ConnectOptions(autoSubscribe: true))
              .timeout(const Duration(seconds: 15));
          connected = true;
          _log('Connected attempt $i');
          break;
        } catch (e) {
          _log('Connect $i: $e');
          if (i < 2) await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (!connected) {
        _room?.dispose();
        _room = null;
        return false;
      }

      _log(
          'Room: ${_room?.name}, Participants: ${_room?.remoteParticipants.length}');

      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        _log('Mic on');
      } catch (e) {
        _log('Mic error: $e');
      }

      _setupRoomEvents();
      await WakelockPlus.enable();
      if (_provider.currentCall?.type != CallType.video) {
        await Hardware.instance.setSpeakerphoneOn(false);
      }

      return true;
    } catch (e, st) {
      _log('Join error', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> _leaveRoom() async {
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(false);
      await _room?.disconnect();
      _roomEvents?.dispose();
      _roomEvents = null;
      _room?.dispose();
      _room = null;
      await WakelockPlus.disable();
    } catch (e) {
      _log('Leave error: $e');
    }
  }

  void _setupRoomEvents() {
    _roomEvents
        ?.on<RoomDisconnectedEvent>((e) => _log('Disconnected: ${e.reason}'));
    _roomEvents?.on<RoomReconnectingEvent>((_) => _provider.setReconnecting());
    _roomEvents?.on<RoomReconnectedEvent>((_) => _provider.setReconnected());
    _roomEvents?.on<ParticipantConnectedEvent>((e) {
      _log('Participant: ${e.participant.identity}');
      _updateParticipants();
    });
    _roomEvents?.on<ParticipantDisconnectedEvent>((e) {
      _log('Left: ${e.participant.identity}');
      if (e.participant.identity != _room?.localParticipant?.identity &&
          _provider.hasActiveCall) endCall();
      _updateParticipants();
    });
    _roomEvents?.on<TrackSubscribedEvent>((_) => _updateParticipants());
    _roomEvents?.on<TrackUnsubscribedEvent>((_) => _updateParticipants());
    _roomEvents?.on<LocalTrackPublishedEvent>((_) => _updateParticipants());
  }

  void _updateParticipants() {
    if (_room == null) return;
    final list = <ParticipantModel>[];

    final local = _room!.localParticipant;
    if (local != null) {
      list.add(ParticipantModel(
        userId: local.identity,
        name: local.name ?? 'You',
        isLocal: true,
        isMuted: !local.isMicrophoneEnabled(),
        isCameraOn: local.isCameraEnabled(),
      ));
    }

    for (final r in _room!.remoteParticipants.values) {
      list.add(ParticipantModel(
        userId: r.identity,
        name: r.name ?? 'Caller',
        isLocal: false,
        isMuted: !r.audioTrackPublications.any((t) => !t.muted),
        isCameraOn: r.videoTrackPublications.isNotEmpty,
      ));
    }

    _provider.updateParticipants(list);
  }

  // ==================== CONTROLS ====================

  Future<void> toggleMute() async {
    try {
      final v = !_provider.isMuted;
      await _room?.localParticipant?.setMicrophoneEnabled(!v);
      _provider.setMuted(v);
    } catch (e) {
      _log('Mute error: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    try {
      final v = !_provider.isSpeakerOn;
      await Hardware.instance.setSpeakerphoneOn(v);
      _provider.setSpeakerOn(v);
    } catch (e) {
      _log('Speaker error: $e');
    }
  }

  Future<void> toggleCamera() async {
    try {
      final v = !_provider.isCameraOn;
      await _room?.localParticipant?.setCameraEnabled(v);
      _provider.setCameraOn(v);
    } catch (e) {
      _log('Camera error: $e');
    }
  }

  // ==================== HELPERS ====================

  void _watchCallStatus(String callId) {
    _callDocSubscription?.cancel();
    _callDocSubscription = _callRepository.watchCall(callId).listen((call) {
      if (call == null) return;
      _log('Status: ${call.status}, state: ${_provider.state}');

      switch (call.status) {
        case CallStatus.accepted:
          _ringTimeout?.cancel();
          if (_provider.state == CallState.outgoingRinging) {
            _joinRoomAfterAccept(callId);
          }
          break;
        case CallStatus.declined:
        case CallStatus.noAnswer:
        case CallStatus.busy:
        case CallStatus.failed:
        case CallStatus.ended:
          if (_provider.hasActiveCall) endCall();
          break;
        case CallStatus.ringing:
          break;
      }
    });
  }

  Future<void> _joinRoomAfterAccept(String callId) async {
    _log('Callee accepted, joining...');
    _provider.acceptCall();
    if (await _joinRoom(callId)) {
      _provider.startCall();
      await FlutterCallkitIncoming.setCallConnected(callId);
    } else {
      _provider.setError('Connect failed');
      endCall();
    }
  }

  void _startRingTimeout(String callId) {
    _ringTimeout?.cancel();
    _ringTimeout = Timer(Duration(seconds: CallTimeouts.ringTimeout), () async {
      if (_provider.state == CallState.outgoingRinging) {
        await _callRepository.markNoAnswer(callId);
        _provider.setError('No answer');
        endCall();
      }
    });
  }

  Future<bool> _checkPermissions(CallType type) async {
    var mic = await Permission.microphone.status;
    if (!mic.isGranted) mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _provider.setError('Mic required');
      return false;
    }
    if (type == CallType.video) {
      var cam = await Permission.camera.status;
      if (!cam.isGranted) await Permission.camera.request();
    }
    return true;
  }

  void _cleanup() {
    _callDocSubscription?.cancel();
    _callDocSubscription = null;
    _ringTimeout?.cancel();
    _ringTimeout = null;
    _tokenRx.clear();
    _isCallInProgress = false;
    _isAccepting = false;
  }

  Future<void> restoreActiveCall() async {
    try {
      _log('Restoring...');
      final call = await _callRepository.getActiveCall();
      if (call != null && call.status == CallStatus.accepted) {
        _log('Found: ${call.id}');
        _provider.restoreCall(call);
        if (await _joinRoom(call.id)) {
          _provider.startCall();
          _watchCallStatus(call.id);
          await FlutterCallkitIncoming.setCallConnected(call.id);
          _log('Restored');
        } else {
          _provider.endCall();
        }
      }
    } catch (e) {
      _log('Restore error: $e');
    }
  }
}
