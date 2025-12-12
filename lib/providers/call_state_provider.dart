import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';

enum CallState { idle, ringing, accepted, inCall, ended }

class CallStateProvider extends ChangeNotifier {
  CallState _state = CallState.idle;
  String? _callId;
  String? _callerId;
  String? _roomName;

  // Enhanced state management
  final List<Participant> _participants = [];
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isCameraOn = true;
  bool _isMinimized = false;
  bool _isIncoming = false; // Add this track direction

  // Getters - existing (backward compatible)
  CallState get state => _state;
  String? get callId => _callId;
  String? get callerId => _callerId;
  String? get roomName => _roomName;
  bool get hasPendingCall => _state == CallState.accepted && _callId != null;
  bool get isInCall => _state == CallState.inCall;

  // Getters - new
  List<Participant> get participants => List.unmodifiable(_participants);
  int get callDurationSeconds => _callDurationSeconds;
  String get formattedDuration {
    final hours = _callDurationSeconds ~/ 3600;
    final minutes = (_callDurationSeconds % 3600) ~/ 60;
    final seconds = _callDurationSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCameraOn => _isCameraOn;
  bool get isMinimized => _isMinimized;
  bool get isIncoming => _isIncoming;

  // Show call bar when active (ringing, accepted, or inCall) AND minimized
  bool get shouldShowCallBar =>
      (_state == CallState.inCall ||
          _state == CallState.accepted ||
          _state == CallState.ringing) &&
      _isMinimized;

  /// Called when an incoming call notification is received
  void handleIncomingCall({
    required String callId,
    String? callerId,
    String? roomName,
    bool isIncoming = true, // Default to true typically, but allow override
  }) {
    _state = CallState.ringing;
    _callId = callId;
    _callerId = callerId;
    _roomName = roomName;
    _isIncoming = isIncoming;
    notifyListeners();
    log('[CallStateProvider] Incoming call: $callId from $callerId');
  }

  /// Called when the user accepts the call
  void acceptCall() {
    if (_state == CallState.ringing) {
      _state = CallState.accepted;
      notifyListeners();
      log('[CallStateProvider] Call accepted: $_callId');
    }
  }

  /// Called when navigating to CallScreen
  void startCall() {
    if (_state == CallState.accepted || _state == CallState.ringing) {
      _state = CallState.inCall;
      _startDurationTimer();
      notifyListeners();
      log('[CallStateProvider] Call started: $_callId');
    }
  }

  /// Called when the call ends
  void endCall() {
    log('[CallStateProvider] Ending call: $_callId');
    _stopDurationTimer();
    _state = CallState.idle;
    _callId = null;
    _callerId = null;
    _roomName = null;
    _participants.clear();
    _callDurationSeconds = 0;
    _isMuted = false;
    _isSpeakerOn = true;
    _isCameraOn = true;
    _isMinimized = false;
    _isIncoming = false;
    notifyListeners();
  }

  /// Reset to initial state
  void reset() {
    _stopDurationTimer();
    _state = CallState.idle;
    _callId = null;
    _callerId = null;
    _roomName = null;
    _participants.clear();
    _callDurationSeconds = 0;
    _isMuted = false;
    _isSpeakerOn = true;
    _isCameraOn = true;
    _isMinimized = false;
    notifyListeners();
  }

  // Duration tracking methods
  void _startDurationTimer() {
    _stopDurationTimer(); // Ensure no duplicate timers
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _callDurationSeconds++;
      notifyListeners();
    });
    log('[CallStateProvider] Duration timer started');
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    log('[CallStateProvider] Duration timer stopped');
  }

  // Participants management
  void updateParticipants(List<Participant> participants) {
    _participants.clear();
    _participants.addAll(participants);
    notifyListeners();
    log('[CallStateProvider] Participants updated: ${participants.length}');
  }

  void addParticipant(Participant participant) {
    if (!_participants.contains(participant)) {
      _participants.add(participant);
      notifyListeners();
      log('[CallStateProvider] Participant added: ${participant.identity}');
    }
  }

  void removeParticipant(Participant participant) {
    if (_participants.remove(participant)) {
      notifyListeners();
      log('[CallStateProvider] Participant removed: ${participant.identity}');
    }
  }

  // Audio/Video state management
  void setMuted(bool muted) {
    _isMuted = muted;
    notifyListeners();
    log('[CallStateProvider] Muted: $muted');
  }

  void setSpeakerOn(bool speakerOn) {
    _isSpeakerOn = speakerOn;
    notifyListeners();
    log('[CallStateProvider] Speaker: $speakerOn');
  }

  void setCameraOn(bool cameraOn) {
    _isCameraOn = cameraOn;
    notifyListeners();
    log('[CallStateProvider] Camera: $cameraOn');
  }

  // Minimize/Maximize handling
  void minimize() {
    _isMinimized = true;
    notifyListeners();
    log('[CallStateProvider] Call minimized');
  }

  void maximize() {
    _isMinimized = false;
    notifyListeners();
    log('[CallStateProvider] Call maximized');
  }

  @override
  void dispose() {
    _stopDurationTimer();
    super.dispose();
  }
}
