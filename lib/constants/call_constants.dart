/// Call-related constants and enums
library;

/// Call status values for Firestore
enum CallStatus {
  ringing,
  accepted,
  declined,
  ended,
  busy,
  noAnswer,
  failed;

  static CallStatus fromString(String? value) {
    return CallStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CallStatus.ended,
    );
  }

  bool get isActive => this == ringing || this == accepted;
  bool get isTerminal =>
      this == declined ||
      this == ended ||
      this == busy ||
      this == noAnswer ||
      this == failed;
}

/// Call type
enum CallType {
  audio,
  video;

  static CallType fromString(String? value) {
    return CallType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => CallType.audio,
    );
  }
}

/// Call direction relative to current user
enum CallDirection { incoming, outgoing }

/// Connection quality levels
enum ConnectionQuality {
  excellent,
  good,
  poor,
  disconnected;

  bool get isGood => this == excellent || this == good;
}

/// Call state for UI
enum CallState {
  idle,
  outgoingRinging, // We're calling someone
  incomingRinging, // Someone's calling us
  connecting, // Call accepted, connecting to LiveKit
  inCall, // Active call
  reconnecting, // Lost connection, trying to reconnect
  ended; // Call ended (transitional state)

  bool get isActive => this != idle && this != ended;
  bool get isRinging => this == outgoingRinging || this == incomingRinging;
  bool get isConnected => this == inCall || this == reconnecting;
}

/// Timeouts and limits
abstract class CallTimeouts {
  /// Ring duration before marking as no-answer (seconds)
  static const int ringTimeout = 30;

  /// Max reconnection attempts before giving up
  static const int maxReconnectAttempts = 5;

  /// Ignore calls older than this for restoration (hours)
  static const int callExpirationHours = 6;

  /// Minimum call duration to consider valid (seconds)
  static const int minValidDuration = 3;

  /// Debounce duration for call button (milliseconds)
  static const int callButtonDebounce = 1000;
}

/// Firestore collection names
abstract class CallCollections {
  static const String calls = 'calls';
  static const String users = 'users';
}

/// Firestore field names
abstract class CallFields {
  static const String callerId = 'callerId';
  static const String calleeId = 'calleeId';
  static const String callerName = 'callerName';
  static const String calleeName = 'calleeName';
  static const String callerPhoto = 'callerPhoto';
  static const String calleePhoto = 'calleePhoto';
  static const String roomName = 'roomName';
  static const String status = 'status';
  static const String type = 'type';
  static const String participants = 'participants';
  static const String createdAt = 'createdAt';
  static const String acceptedAt = 'acceptedAt';
  static const String endedAt = 'endedAt';
}
