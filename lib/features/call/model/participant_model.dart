class ParticipantModel {
  final String userId;
  final String name;
  final String? photoUrl;
  final bool isMuted;
  final bool isCameraOn;
  final bool isSpeaking;
  final bool isLocal;
  final bool isConnected;

  const ParticipantModel({
    required this.userId,
    required this.name,
    this.photoUrl,
    this.isMuted = false,
    this.isCameraOn = false,
    this.isSpeaking = false,
    this.isLocal = false,
    this.isConnected = true,
  });

  /// Create a local participant
  factory ParticipantModel.local({
    required String userId,
    required String name,
    String? photoUrl,
  }) {
    return ParticipantModel(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      isLocal: true,
    );
  }

  /// Create a remote participant
  factory ParticipantModel.remote({
    required String userId,
    required String name,
    String? photoUrl,
  }) {
    return ParticipantModel(
      userId: userId,
      name: name,
      photoUrl: photoUrl,
      isLocal: false,
    );
  }

  String get displayName => isLocal ? 'You' : name;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  ParticipantModel copyWith({
    String? oderId,
    String? name,
    String? photoUrl,
    bool? isMuted,
    bool? isCameraOn,
    bool? isSpeaking,
    bool? isLocal,
    bool? isConnected,
  }) {
    return ParticipantModel(
      userId: userId ?? userId,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      isMuted: isMuted ?? this.isMuted,
      isCameraOn: isCameraOn ?? this.isCameraOn,
      isSpeaking: isSpeaking ?? this.isSpeaking,
      isLocal: isLocal ?? this.isLocal,
      isConnected: isConnected ?? this.isConnected,
    );
  }

  @override
  String toString() {
    return 'ParticipantModel(userId: $userId, name: $name, isLocal: $isLocal)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParticipantModel && other.userId == userId;
  }

  @override
  int get hashCode => userId.hashCode;
}
