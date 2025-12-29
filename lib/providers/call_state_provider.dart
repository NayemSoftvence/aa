import 'dart:async';
import 'dart:developer';
import 'package:flutter/foundation.dart';

import '../constants/call_constants.dart';
import '../features/call/model/call_model.dart';
import '../features/call/model/participant_model.dart';

class CallStateProvider extends ChangeNotifier {
  // ==================== CORE STATE ====================

  CallState _state = CallState.idle;
  CallModel? _currentCall;
  String? _errorMessage;

  // ==================== CONNECTION STATE ====================

  ConnectionQuality _connectionQuality = ConnectionQuality.good;
  int _reconnectAttempts = 0;

  // ==================== PARTICIPANTS ====================

  final List<ParticipantModel> _participants = [];

  // ==================== CALL CONTROLS ====================

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isCameraOn = false;

  // ==================== UI STATE ====================

  bool _isMinimized = false;

  // ==================== DURATION ====================

  Timer? _durationTimer;
  int _callDurationSeconds = 0;

  // ==================== GETTERS - CORE ====================

  CallState get state => _state;
  CallModel? get currentCall => _currentCall;
  String? get callId => _currentCall?.id;
  String? get roomName => _currentCall?.roomName;
  String? get errorMessage => _errorMessage;

  // ==================== GETTERS - CONNECTION ====================

  ConnectionQuality get connectionQuality => _connectionQuality;
  int get reconnectAttempts => _reconnectAttempts;

  // ==================== GETTERS - PARTICIPANTS ====================

  List<ParticipantModel> get participants => List.unmodifiable(_participants);
  int get participantCount => _participants.length;

  // ==================== GETTERS - CONTROLS ====================

  bool get isMuted => _isMuted;
  bool get isSpeakerOn => _isSpeakerOn;
  bool get isCameraOn => _isCameraOn;
  bool get isMinimized => _isMinimized;

  // ==================== GETTERS - DURATION ====================

  int get callDurationSeconds => _callDurationSeconds;

  String get formattedDuration {
    final hours = _callDurationSeconds ~/ 3600;
    final minutes = (_callDurationSeconds % 3600) ~/ 60;
    final seconds = _callDurationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ==================== GETTERS - COMPUTED STATE ====================

  /// Check if there's an active call (not idle, not ended)
  bool get hasActiveCall =>
      _state != CallState.idle && _state != CallState.ended;

  /// Check if currently in an active connected call
  bool get isInCall => _state == CallState.inCall;

  /// Check if in a connecting state
  bool get isConnecting =>
      _state == CallState.connecting || _state == CallState.reconnecting;

  /// Check if ringing (incoming or outgoing)
  bool get isRinging =>
      _state == CallState.incomingRinging ||
      _state == CallState.outgoingRinging;

  /// Check if this is an incoming call
  bool get isIncoming => _state == CallState.incomingRinging;

  /// Check if this is an outgoing call
  bool get isOutgoing => _state == CallState.outgoingRinging;

  // ==================== GETTERS - UI STATE ====================

  /// Should show the call bar (minimized in-call indicator)
  bool get shouldShowCallBar =>
      _state == CallState.inCall ||
      _state == CallState.connecting ||
      _state == CallState.reconnecting;

  /// Should show full-screen call UI
  bool get shouldShowFullScreen => hasActiveCall && !_isMinimized;

  /// Should show incoming call UI
  bool get shouldShowIncomingUI => _state == CallState.incomingRinging;

  /// Get display name for the other party
  String get displayName {
    if (_currentCall == null) return 'Unknown';
    String name = _currentCall!.calleeName.isNotEmpty
        ? _currentCall!.calleeName
        : _currentCall!.callerName;

    // Safety check: if name looks like an ID (long, no spaces), show generic
    if (name.length > 15 && !name.contains(' ')) {
      return 'Guest';
    }
    return name;
  }

  /// Get display photo for the other party
  String? get displayPhoto =>
      _currentCall?.calleePhoto ?? _currentCall?.callerPhoto;

  /// Get state description for UI
  String get stateDescription {
    switch (_state) {
      case CallState.idle:
        return '';
      case CallState.outgoingRinging:
        return 'Calling...';
      case CallState.incomingRinging:
        return 'Incoming call';
      case CallState.connecting:
        return 'Connecting...';
      case CallState.inCall:
        return formattedDuration;
      case CallState.reconnecting:
        return 'Reconnecting...';
      case CallState.ended:
        return 'Call ended';
    }
  }

  // ==================== STATE TRANSITIONS ====================

  /// Start an outgoing call
  void startOutgoingCall(CallModel call) {
    if (_state != CallState.idle) {
      log('[CallStateProvider] Cannot start outgoing from: $_state');
      return;
    }

    _state = CallState.outgoingRinging;
    _currentCall = call;
    _resetCallState();
    notifyListeners();
    log('[CallStateProvider] Outgoing call started: ${call.id}');
  }

  /// Handle incoming call notification
  void handleIncomingCall(CallModel call) {
    if (_state != CallState.idle) {
      log('[CallStateProvider] Cannot handle incoming from: $_state');
      return;
    }

    _state = CallState.incomingRinging;
    _currentCall = call;
    _resetCallState();
    // NO timer start here - only when connected
    notifyListeners();
    log('[CallStateProvider] Incoming call: ${call.id} from ${call.callerName}');
  }

  /// Accept the current call (user pressed accept)
  void acceptCall() {
    if (_state != CallState.incomingRinging &&
        _state != CallState.outgoingRinging) {
      log('[CallStateProvider] Cannot accept from: $_state');
      return;
    }

    _state = CallState.connecting;
    notifyListeners();
    log('[CallStateProvider] Call accepted, connecting: ${_currentCall?.id}');
  }

  /// Mark call as connected and in progress
  /// Timer starts here - when both parties are connected
  void startCall() {
    if (_state != CallState.connecting) {
      log('[CallStateProvider] Cannot start call from: $_state');
      return;
    }

    _state = CallState.inCall;
    _startDurationTimer();
    notifyListeners();
    log('[CallStateProvider] Call in progress: ${_currentCall?.id}');
  }

  /// Handle reconnection started
  void setReconnecting() {
    if (_state != CallState.inCall) return;

    _state = CallState.reconnecting;
    _reconnectAttempts++;
    notifyListeners();
    log('[CallStateProvider] Reconnecting (attempt $_reconnectAttempts)');
  }

  /// Reconnection successful
  void setReconnected() {
    if (_state != CallState.reconnecting) return;

    _state = CallState.inCall;
    _reconnectAttempts = 0;
    _connectionQuality = ConnectionQuality.good;
    notifyListeners();
    log('[CallStateProvider] Reconnected');
  }

  /// End the call
  void endCall() {
    log('[CallStateProvider] Ending call: ${_currentCall?.id}');
    _cleanup();
    _state = CallState.idle;
    notifyListeners();
  }

  /// Restore an active call (app restart scenario)
  /// Sets state to connecting - will move to inCall after room join
  void restoreCall(CallModel call) {
    log('[CallStateProvider] Restoring call: ${call.id}');
    _state = CallState.connecting;
    _currentCall = call;
    _resetCallState();
    notifyListeners();
  }

  /// Reset to initial state
  void reset() => endCall();

  // ==================== CALL CONTROLS ====================

  void setMuted(bool muted) {
    if (_isMuted != muted) {
      _isMuted = muted;
      notifyListeners();
      log('[CallStateProvider] Muted: $muted');
    }
  }

  void toggleMute() => setMuted(!_isMuted);

  void setSpeakerOn(bool speakerOn) {
    if (_isSpeakerOn != speakerOn) {
      _isSpeakerOn = speakerOn;
      notifyListeners();
      log('[CallStateProvider] Speaker: $speakerOn');
    }
  }

  void toggleSpeaker() => setSpeakerOn(!_isSpeakerOn);

  void setCameraOn(bool cameraOn) {
    if (_isCameraOn != cameraOn) {
      _isCameraOn = cameraOn;
      notifyListeners();
      log('[CallStateProvider] Camera: $cameraOn');
    }
  }

  void toggleCamera() => setCameraOn(!_isCameraOn);

  // ==================== UI STATE ====================

  void minimize() {
    if (!_isMinimized && hasActiveCall) {
      _isMinimized = true;
      notifyListeners();
      log('[CallStateProvider] Minimized');
    }
  }

  void maximize() {
    if (_isMinimized) {
      _isMinimized = false;
      notifyListeners();
      log('[CallStateProvider] Maximized');
    }
  }

  void toggleMinimize() => _isMinimized ? maximize() : minimize();

  // ==================== CONNECTION QUALITY ====================

  void updateConnectionQuality(ConnectionQuality quality) {
    if (_connectionQuality != quality) {
      _connectionQuality = quality;
      notifyListeners();
      log('[CallStateProvider] Connection quality: ${quality.name}');
    }
  }

  // ==================== PARTICIPANTS ====================

  void updateParticipants(List<ParticipantModel> participants) {
    _participants
      ..clear()
      ..addAll(participants);
    notifyListeners();
  }

  void addParticipant(ParticipantModel participant) {
    if (!_participants.any((p) => p.userId == participant.userId)) {
      _participants.add(participant);
      notifyListeners();
      log('[CallStateProvider] Participant added: ${participant.name}');
    }
  }

  void removeParticipant(String userId) {
    final removed = _participants.where((p) => p.userId == userId).toList();
    for (final p in removed) {
      _participants.remove(p);
    }
    if (removed.isNotEmpty) {
      notifyListeners();
      log('[CallStateProvider] Participant removed: $userId');
    }
  }

  void updateParticipant(ParticipantModel updated) {
    final index = _participants.indexWhere((p) => p.userId == updated.userId);
    if (index >= 0) {
      _participants[index] = updated;
      notifyListeners();
    }
  }

  void clearParticipants() {
    if (_participants.isNotEmpty) {
      _participants.clear();
      notifyListeners();
    }
  }

  // ==================== ERROR HANDLING ====================

  void setError(String message) {
    _errorMessage = message;
    notifyListeners();
    log('[CallStateProvider] Error: $message');

    // Auto-clear after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_errorMessage == message) {
        clearError();
      }
    });
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ==================== PRIVATE METHODS ====================

  void _startDurationTimer() {
    _stopDurationTimer();
    _callDurationSeconds = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _callDurationSeconds++;
      notifyListeners();
    });
    log('[CallStateProvider] Duration timer started');
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _resetCallState() {
    _isMuted = false;
    _isSpeakerOn = false;
    _isCameraOn = false;
    _isMinimized = false;
    _callDurationSeconds = 0;
    _reconnectAttempts = 0;
    _connectionQuality = ConnectionQuality.good;
    _errorMessage = null;
    _participants.clear();
    _stopDurationTimer();
  }

  void _cleanup() {
    _stopDurationTimer();
    _currentCall = null;
    _resetCallState();
  }

  @override
  void dispose() {
    _stopDurationTimer();
    super.dispose();
  }
}
