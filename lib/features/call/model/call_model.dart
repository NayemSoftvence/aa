import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants/call_constants.dart';

class CallModel {
  final String id;
  final String callerId;
  final String calleeId;
  final String callerName;
  final String calleeName;
  final String? callerPhoto;
  final String? calleePhoto;
  final String roomName;
  final CallStatus status;
  final CallType type;
  final List<String> participants;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? endedAt;

  const CallModel({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callerName,
    required this.calleeName,
    this.callerPhoto,
    this.calleePhoto,
    required this.roomName,
    required this.status,
    required this.type,
    required this.participants,
    this.createdAt,
    this.acceptedAt,
    this.endedAt,
  });

  /// Create an empty/placeholder model
  factory CallModel.empty() {
    return const CallModel(
      id: '',
      callerId: '',
      calleeId: '',
      callerName: '',
      calleeName: '',
      roomName: '',
      status: CallStatus.ended,
      type: CallType.audio,
      participants: [],
    );
  }

  /// Create from Firestore document
  factory CallModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CallModel.fromMap(data, doc.id);
  }

  /// Create from Map with ID
  factory CallModel.fromMap(Map<String, dynamic> map, String id) {
    return CallModel(
      id: id,
      callerId: map[CallFields.callerId] as String? ?? '',
      calleeId: map[CallFields.calleeId] as String? ?? '',
      callerName: map[CallFields.callerName] as String? ?? 'Unknown',
      calleeName: map[CallFields.calleeName] as String? ?? 'Unknown',
      callerPhoto: map[CallFields.callerPhoto] as String?,
      calleePhoto: map[CallFields.calleePhoto] as String?,
      roomName: map[CallFields.roomName] as String? ?? '',
      status: CallStatus.fromString(map[CallFields.status] as String?),
      type: CallType.fromString(map[CallFields.type] as String?),
      participants: List<String>.from(map[CallFields.participants] ?? []),
      createdAt: _parseTimestamp(map[CallFields.createdAt]),
      acceptedAt: _parseTimestamp(map[CallFields.acceptedAt]),
      endedAt: _parseTimestamp(map[CallFields.endedAt]),
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  /// Convert to Firestore map (for creating new calls)
  Map<String, dynamic> toFirestore() {
    return {
      CallFields.callerId: callerId,
      CallFields.calleeId: calleeId,
      CallFields.callerName: callerName,
      CallFields.calleeName: calleeName,
      CallFields.callerPhoto: callerPhoto,
      CallFields.calleePhoto: calleePhoto,
      CallFields.roomName: roomName,
      CallFields.status: status.name,
      CallFields.type: type.name,
      CallFields.participants: participants,
      CallFields.createdAt: FieldValue.serverTimestamp(),
    };
  }

  // ==================== COMPUTED PROPERTIES ====================

  /// Check if current user is the caller (outgoing call)
  bool isOutgoing(String currentUserId) => callerId == currentUserId;

  /// Check if current user is the callee (incoming call)
  bool isIncoming(String currentUserId) => calleeId == currentUserId;

  /// Check if this is a missed call
  bool get isMissed =>
      status == CallStatus.noAnswer ||
      (status == CallStatus.ended && acceptedAt == null);

  /// Check if call was declined
  bool get wasDeclined => status == CallStatus.declined;

  /// Check if call was answered
  bool get wasAnswered => acceptedAt != null;

  /// Check if this is a valid (not empty) call
  bool get isValid => id.isNotEmpty && callerId.isNotEmpty;

  /// Get call duration in seconds (null if not completed)
  int? get durationSeconds {
    if (acceptedAt == null) return null;
    final end = endedAt ?? DateTime.now();
    return end.difference(acceptedAt!).inSeconds;
  }

  /// Get formatted duration string (MM:SS or HH:MM:SS)
  String get formattedDuration {
    final duration = durationSeconds;
    if (duration == null) return '--:--';

    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get display name based on perspective
  String displayName(String currentUserId) {
    return isOutgoing(currentUserId) ? calleeName : callerName;
  }

  /// Get display photo based on perspective
  String? displayPhoto(String currentUserId) {
    return isOutgoing(currentUserId) ? calleePhoto : callerPhoto;
  }

  /// Get the other participant's ID
  String otherParticipantId(String currentUserId) {
    return isOutgoing(currentUserId) ? calleeId : callerId;
  }

  /// Check if call is expired (for restoration logic)
  bool get isExpired {
    if (createdAt == null) return true;
    return DateTime.now().difference(createdAt!).inHours >
        CallTimeouts.callExpirationHours;
  }

  // ==================== COPY WITH ====================

  CallModel copyWith({
    String? id,
    String? callerId,
    String? calleeId,
    String? callerName,
    String? calleeName,
    String? callerPhoto,
    String? calleePhoto,
    String? roomName,
    CallStatus? status,
    CallType? type,
    List<String>? participants,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? endedAt,
  }) {
    return CallModel(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      calleeId: calleeId ?? this.calleeId,
      callerName: callerName ?? this.callerName,
      calleeName: calleeName ?? this.calleeName,
      callerPhoto: callerPhoto ?? this.callerPhoto,
      calleePhoto: calleePhoto ?? this.calleePhoto,
      roomName: roomName ?? this.roomName,
      status: status ?? this.status,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }

  @override
  String toString() {
    return 'CallModel(id: $id, status: $status, '
        'caller: $callerName -> callee: $calleeName)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CallModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
