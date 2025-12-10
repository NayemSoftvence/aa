import 'package:flutter/foundation.dart';

enum CallState { idle, ringing, accepted, inCall, ended }

class CallStateProvider extends ChangeNotifier {
  CallState _state = CallState.idle;
  String? _callId;
  String? _callerId;
  String? _roomName;

  CallState get state => _state;
  String? get callId => _callId;
  String? get callerId => _callerId;
  String? get roomName => _roomName;

  bool get hasPendingCall => _state == CallState.accepted && _callId != null;
  bool get isInCall => _state == CallState.inCall;

  /// Called when an incoming call notification is received
  void handleIncomingCall({
    required String callId,
    String? callerId,
    String? roomName,
  }) {
    _state = CallState.ringing;
    _callId = callId;
    _callerId = callerId;
    _roomName = roomName;
    notifyListeners();
    print('[CallStateProvider] Incoming call: $callId from $callerId');
  }

  /// Called when the user accepts the call
  void acceptCall() {
    if (_state == CallState.ringing) {
      _state = CallState.accepted;
      notifyListeners();
      print('[CallStateProvider] Call accepted: $_callId');
    }
  }

  /// Called when navigating to CallScreen
  void startCall() {
    if (_state == CallState.accepted) {
      _state = CallState.inCall;
      notifyListeners();
      print('[CallStateProvider] Call started: $_callId');
    }
  }

  /// Called when the call ends
  void endCall() {
    print('[CallStateProvider] Ending call: $_callId');
    _state = CallState.idle;
    _callId = null;
    _callerId = null;
    _roomName = null;
    notifyListeners();
  }

  /// Reset to initial state
  void reset() {
    _state = CallState.idle;
    _callId = null;
    _callerId = null;
    _roomName = null;
    notifyListeners();
  }
}
