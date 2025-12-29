import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../constants/call_constants.dart';
import '../model/call_model.dart';

class CallRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  CallRepository({
    FirebaseFirestore? db,
    FirebaseAuth? auth,
  })  : _db = db ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // ==================== HELPERS ====================

  String get currentUserId => _auth.currentUser?.uid ?? '';
  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _callsRef =>
      _db.collection(CallCollections.calls);

  // ==================== CREATE OPERATIONS ====================

  /// Create a new outgoing call
  Future<CallModel> createCall({
    required String calleeId,
    required String calleeName,
    String? calleePhoto,
    CallType type = CallType.audio,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    final callRef = _callsRef.doc();
    final roomName = 'room_${callRef.id}';

    final call = CallModel(
      id: callRef.id,
      callerId: user.uid,
      calleeId: calleeId,
      callerName: user.displayName ?? 'Unknown',
      calleeName: calleeName,
      callerPhoto: user.photoURL,
      calleePhoto: calleePhoto,
      roomName: roomName,
      status: CallStatus.ringing,
      type: type,
      participants: [user.uid, calleeId],
      createdAt: DateTime.now(),
    );

    await callRef.set(call.toFirestore());

    log('[CallRepository] Call created: ${call.id}');
    return call;
  }

  // ==================== UPDATE OPERATIONS ====================

  /// Accept an incoming call
  Future<void> acceptCall(String callId) async {
    await _callsRef.doc(callId).update({
      CallFields.status: CallStatus.accepted.name,
      CallFields.acceptedAt: FieldValue.serverTimestamp(),
    });
    log('[CallRepository] Call accepted: $callId');
  }

  /// Decline an incoming call
  Future<void> declineCall(String callId) async {
    await _callsRef.doc(callId).update({
      CallFields.status: CallStatus.declined.name,
      CallFields.endedAt: FieldValue.serverTimestamp(),
    });
    log('[CallRepository] Call declined: $callId');
  }

  /// End an active call
  Future<void> endCall(String callId) async {
    await _callsRef.doc(callId).update({
      CallFields.status: CallStatus.ended.name,
      CallFields.endedAt: FieldValue.serverTimestamp(),
    });
    log('[CallRepository] Call ended: $callId');
  }

  /// Mark call as no answer (timeout)
  Future<void> markNoAnswer(String callId) async {
    await _callsRef.doc(callId).update({
      CallFields.status: CallStatus.noAnswer.name,
      CallFields.endedAt: FieldValue.serverTimestamp(),
    });
    log('[CallRepository] Call marked no-answer: $callId');
  }

  /// Mark callee as busy
  Future<void> markBusy(String callId) async {
    await _callsRef.doc(callId).update({
      CallFields.status: CallStatus.busy.name,
      CallFields.endedAt: FieldValue.serverTimestamp(),
    });
    log('[CallRepository] Call marked busy: $callId');
  }

  /// Mark call as failed
  Future<void> markFailed(String callId) async {
    await _callsRef.doc(callId).update({
      CallFields.status: CallStatus.failed.name,
      CallFields.endedAt: FieldValue.serverTimestamp(),
    });
    log('[CallRepository] Call marked failed: $callId');
  }

  // ==================== READ OPERATIONS ====================

  /// Get a single call by ID
  Future<CallModel?> getCall(String callId) async {
    try {
      final doc = await _callsRef.doc(callId).get();
      if (!doc.exists) return null;
      return CallModel.fromFirestore(doc);
    } catch (e) {
      log('[CallRepository] getCall error: $e');
      return null;
    }
  }

  /// Watch a call for real-time updates
  Stream<CallModel?> watchCall(String callId) {
    return _callsRef.doc(callId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return CallModel.fromFirestore(doc);
    }).handleError((e) {
      log('[CallRepository] watchCall error: $e');
      return null;
    });
  }

  /// Check if current user is busy (in an active call)
  ///
  /// Uses separate queries to avoid Firestore security rule issues with whereIn
  Future<bool> isUserBusy(String userId) async {
    // We can only reliably check if the CURRENT user is busy
    // For other users, we skip the check and let the call proceed
    if (userId != currentUserId) {
      log('[CallRepository] Skipping busy check for other user: $userId');
      return false;
    }

    return isCurrentUserBusy;
  }

  /// Check if current user is in an active call
  ///
  /// Runs two separate queries to avoid whereIn issues with security rules
  Future<bool> get isCurrentUserBusy async {
    if (currentUserId.isEmpty) return false;

    try {
      // Query 1: Check for ringing calls where user is caller
      final ringingAsCaller = await _callsRef
          .where(CallFields.callerId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.ringing.name)
          .limit(1)
          .get();

      if (ringingAsCaller.docs.isNotEmpty) {
        log('[CallRepository] User is busy: has ringing call as caller');
        return true;
      }

      // Query 2: Check for ringing calls where user is callee
      final ringingAsCallee = await _callsRef
          .where(CallFields.calleeId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.ringing.name)
          .limit(1)
          .get();

      if (ringingAsCallee.docs.isNotEmpty) {
        log('[CallRepository] User is busy: has ringing call as callee');
        return true;
      }

      // Query 3: Check for accepted calls where user is caller
      final acceptedAsCaller = await _callsRef
          .where(CallFields.callerId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.accepted.name)
          .limit(1)
          .get();

      if (acceptedAsCaller.docs.isNotEmpty) {
        log('[CallRepository] User is busy: has accepted call as caller');
        return true;
      }

      // Query 4: Check for accepted calls where user is callee
      final acceptedAsCallee = await _callsRef
          .where(CallFields.calleeId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.accepted.name)
          .limit(1)
          .get();

      if (acceptedAsCallee.docs.isNotEmpty) {
        log('[CallRepository] User is busy: has accepted call as callee');
        return true;
      }

      log('[CallRepository] User is not busy');
      return false;
    } catch (e) {
      log('[CallRepository] isCurrentUserBusy error: $e');
      // On error, assume not busy to allow call to proceed
      return false;
    }
  }

  /// Get active call for current user (for restoration on app restart)
  Future<CallModel?> getActiveCall() async {
    if (currentUserId.isEmpty) return null;

    try {
      // Check as caller first
      var snap = await _callsRef
          .where(CallFields.callerId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.accepted.name)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        // Check as callee
        snap = await _callsRef
            .where(CallFields.calleeId, isEqualTo: currentUserId)
            .where(CallFields.status, isEqualTo: CallStatus.accepted.name)
            .limit(1)
            .get();
      }

      if (snap.docs.isEmpty) return null;

      final call = CallModel.fromFirestore(snap.docs.first);

      // Ignore expired calls
      if (call.isExpired) {
        log('[CallRepository] Found expired call, ignoring: ${call.id}');
        return null;
      }

      log('[CallRepository] Found active call: ${call.id}');
      return call;
    } catch (e) {
      log('[CallRepository] getActiveCall error: $e');
      return null;
    }
  }

  /// Get any pending ringing call for current user (incoming)
  Future<CallModel?> getPendingIncomingCall() async {
    if (currentUserId.isEmpty) return null;

    try {
      final snap = await _callsRef
          .where(CallFields.calleeId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.ringing.name)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;

      final call = CallModel.fromFirestore(snap.docs.first);

      // Check if call is too old (missed during ring timeout)
      if (call.createdAt != null) {
        final age = DateTime.now().difference(call.createdAt!).inSeconds;
        if (age > CallTimeouts.ringTimeout + 5) {
          log('[CallRepository] Found stale ringing call, ignoring: ${call.id}');
          return null;
        }
      }

      return call;
    } catch (e) {
      log('[CallRepository] getPendingIncomingCall error: $e');
      return null;
    }
  }

  /// Watch for incoming calls (ringing state, addressed to current user)
  Stream<CallModel?> watchIncomingCalls() {
    if (currentUserId.isEmpty) {
      return Stream.value(null);
    }

    return _callsRef
        .where(CallFields.calleeId, isEqualTo: currentUserId)
        .where(CallFields.status, isEqualTo: CallStatus.ringing.name)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      return CallModel.fromFirestore(snap.docs.first);
    }).handleError((e) {
      log('[CallRepository] watchIncomingCalls error: $e');
      return null;
    });
  }

  // ==================== CALL HISTORY ====================

  /// Watch call history for current user (real-time)
  /// Uses callerId/calleeId instead of participants array for better security rule compatibility
  Stream<List<CallModel>> watchCallHistory({int limit = 50}) {
    if (currentUserId.isEmpty) {
      return Stream.value([]);
    }

    // We need to merge two streams: calls where user is caller and calls where user is callee
    final callerStream = _callsRef
        .where(CallFields.callerId, isEqualTo: currentUserId)
        .orderBy(CallFields.createdAt, descending: true)
        .limit(limit)
        .snapshots();

    final calleeStream = _callsRef
        .where(CallFields.calleeId, isEqualTo: currentUserId)
        .orderBy(CallFields.createdAt, descending: true)
        .limit(limit)
        .snapshots();

    // Combine both streams
    return callerStream.asyncMap((callerSnap) async {
      try {
        final calleeSnap = await _callsRef
            .where(CallFields.calleeId, isEqualTo: currentUserId)
            .orderBy(CallFields.createdAt, descending: true)
            .limit(limit)
            .get();

        final callerCalls =
            callerSnap.docs.map(CallModel.fromFirestore).toList();
        final calleeCalls =
            calleeSnap.docs.map(CallModel.fromFirestore).toList();

        // Merge and deduplicate
        final allCalls = <String, CallModel>{};
        for (final call in [...callerCalls, ...calleeCalls]) {
          allCalls[call.id] = call;
        }

        // Sort by createdAt descending
        final sortedCalls = allCalls.values.toList()
          ..sort((a, b) {
            final aTime = a.createdAt ?? DateTime(1970);
            final bTime = b.createdAt ?? DateTime(1970);
            return bTime.compareTo(aTime);
          });

        return sortedCalls.take(limit).toList();
      } catch (e) {
        log('[CallRepository] watchCallHistory merge error: $e');
        return callerSnap.docs.map(CallModel.fromFirestore).toList();
      }
    }).handleError((e) {
      log('[CallRepository] watchCallHistory error: $e');
      return <CallModel>[];
    });
  }

  /// Get call history (one-time fetch)
  Future<List<CallModel>> getCallHistory({int limit = 50}) async {
    if (currentUserId.isEmpty) return [];

    try {
      // Get calls where user is caller
      final callerSnap = await _callsRef
          .where(CallFields.callerId, isEqualTo: currentUserId)
          .orderBy(CallFields.createdAt, descending: true)
          .limit(limit)
          .get();

      // Get calls where user is callee
      final calleeSnap = await _callsRef
          .where(CallFields.calleeId, isEqualTo: currentUserId)
          .orderBy(CallFields.createdAt, descending: true)
          .limit(limit)
          .get();

      // Merge and deduplicate
      final allCalls = <String, CallModel>{};
      for (final doc in callerSnap.docs) {
        final call = CallModel.fromFirestore(doc);
        allCalls[call.id] = call;
      }
      for (final doc in calleeSnap.docs) {
        final call = CallModel.fromFirestore(doc);
        allCalls[call.id] = call;
      }

      // Sort by createdAt descending
      final sortedCalls = allCalls.values.toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime(1970);
          final bTime = b.createdAt ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

      return sortedCalls.take(limit).toList();
    } catch (e) {
      log('[CallRepository] getCallHistory error: $e');
      return [];
    }
  }

  /// Get missed calls count
  Future<int> getMissedCallsCount() async {
    if (currentUserId.isEmpty) return 0;

    try {
      final snap = await _callsRef
          .where(CallFields.calleeId, isEqualTo: currentUserId)
          .where(CallFields.status, isEqualTo: CallStatus.noAnswer.name)
          .get();

      return snap.docs.length;
    } catch (e) {
      log('[CallRepository] getMissedCallsCount error: $e');
      return 0;
    }
  }

  // ==================== USER STATUS ====================

  /// Update current user's call status
  Future<void> updateUserCallStatus(bool inCall) async {
    if (currentUserId.isEmpty) return;

    try {
      await _db.collection(CallCollections.users).doc(currentUserId).update({
        'inCall': inCall,
        'lastCallAt': inCall ? FieldValue.serverTimestamp() : null,
      });
      log('[CallRepository] User call status updated: inCall=$inCall');
    } catch (e) {
      log('[CallRepository] updateUserCallStatus error: $e');
    }
  }
}
