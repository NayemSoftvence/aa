import 'dart:async';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';

import '../constants/call_constants.dart';
import '../features/call/data/call_repository.dart';
import '../features/call/model/call_model.dart';
import '../providers/call_state_provider.dart';
import 'call_manager.dart';
import 'di.dart';

class NotificationService {
  static CallStateProvider? _callProvider;
  static bool _isInitialized = false;
  static StreamSubscription? _callkitSubscription;

  // Deduplication - very important!
  static final Set<String> _processedMessageIds = {};
  static final Set<String> _acceptingCallIds =
      {}; // Track which calls are being accepted
  static String? _lastIncomingCallId;

  static void _log(String msg) {
    final ts = DateTime.now().toIso8601String();
    log('[$ts][NotificationService] $msg');
    print('[$ts][NotificationService] $msg');
  }

  static void registerCallProvider(CallStateProvider provider) {
    _callProvider = provider;
    _log('Provider registered');
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;
    _log('Initializing...');

    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final token = await FirebaseMessaging.instance.getToken();
    _log('FCM Token: $token');

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
        (m) => handleRemoteMessage(m, openedFromTray: true, coldStart: false));

    final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMsg != null)
      handleRemoteMessage(initialMsg, openedFromTray: true, coldStart: true);

    _setupCallKitListeners();
    await FlutterCallkitIncoming.requestFullIntentPermission();

    _isInitialized = true;
    _log('Initialized');
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final msgId = message.messageId ??
        '${message.data['callId']}_${DateTime.now().millisecondsSinceEpoch ~/ 1000}';

    // Strict deduplication
    if (_processedMessageIds.contains(msgId)) {
      _log('Duplicate FCM ignored: $msgId');
      return;
    }
    _processedMessageIds.add(msgId);
    if (_processedMessageIds.length > 20)
      _processedMessageIds.remove(_processedMessageIds.first);

    _log('FCM: $msgId');
    handleRemoteMessage(message, openedFromTray: false, coldStart: false);
  }

  static Future<void> handleRemoteMessage(
    RemoteMessage message, {
    required bool openedFromTray,
    required bool coldStart,
  }) async {
    final data = message.data;
    final type = data['type'] as String?;

    switch (type) {
      case 'incoming_call':
        await _handleIncomingCallNotification(data);
        break;
      case 'call_ended':
        await _handleCallEndedNotification(data);
        break;
      case 'call_accepted':
        _log('Call accepted notification (Firestore handles)');
        break;
      case 'call_declined':
        await _handleCallDeclinedNotification(data);
        break;
    }
  }

  static Future<void> _handleIncomingCallNotification(
      Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    if (callId == null) return;

    // Prevent duplicate incoming call setup
    if (_lastIncomingCallId == callId) {
      _log('Duplicate incoming call ignored: $callId');
      return;
    }
    _lastIncomingCallId = callId;

    final callerName = data['callerName'] as String? ?? 'Unknown';
    final callerPhoto = data['callerPhoto'] as String?;
    final callerId = data['callerId'] as String?;
    final roomName = data['roomName'] as String?;
    final callType = data['callType'] as String? ?? 'audio';

    _log('Incoming: $callId from $callerName');

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'LiveCall',
      avatar: callerPhoto,
      handle: callerName,
      type: callType == 'video' ? 1 : 0,
      textAccept: 'Accept',
      textDecline: 'Decline',
      duration: CallTimeouts.ringTimeout * 1000,
      extra: {
        'callId': callId,
        'callerId': callerId,
        'roomName': roomName,
        'callerName': callerName
      },
      android: const AndroidParams(
        isCustomNotification: true,
        ringtonePath: 'system_ringtone_default',
        backgroundColor: '#0955fa',
        actionColor: '#4CAF50',
        textColor: '#ffffff',
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
      ios: const IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        ringtonePath: 'system_ringtone_default',
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
    _log('CallKit shown');

    if (CallManager.instance.isReady) {
      final call = CallModel(
        id: callId,
        callerId: callerId ?? '',
        calleeId: '',
        callerName: callerName,
        calleeName: '',
        callerPhoto: callerPhoto,
        roomName: roomName ?? '',
        status: CallStatus.ringing,
        type: callType == 'video' ? CallType.video : CallType.audio,
        participants: [],
      );
      await CallManager.instance.handleIncomingCall(call);
    }
  }

  static Future<void> _handleCallEndedNotification(
      Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    if (callId == null) return;
    _log('Call ended: $callId');
    _acceptingCallIds.remove(callId);
    if (callId == _lastIncomingCallId) _lastIncomingCallId = null;
    await FlutterCallkitIncoming.endCall(callId);
    if (_callProvider?.callId == callId) _callProvider?.endCall();
  }

  static Future<void> _handleCallDeclinedNotification(
      Map<String, dynamic> data) async {
    final callId = data['callId'] as String?;
    if (callId == null) return;
    _log('Call declined: $callId');
    _acceptingCallIds.remove(callId);
    if (callId == _lastIncomingCallId) _lastIncomingCallId = null;
    await FlutterCallkitIncoming.endCall(callId);
    if (_callProvider?.callId == callId) _callProvider?.endCall();
  }

  static void _setupCallKitListeners() {
    _log('Setting up CallKit listeners');
    _callkitSubscription?.cancel();
    _callkitSubscription = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;

      final data = event.body as Map<dynamic, dynamic>?;
      final callId = data?['id'] as String?;
      final extra = data?['extra'] as Map<dynamic, dynamic>?;

      _log('CallKit: ${event.event} for $callId');

      switch (event.event) {
        case Event.actionCallIncoming:
          break;

        case Event.actionCallAccept:
          if (callId != null) await _onCallAccepted(callId, data, extra);
          break;

        case Event.actionCallDecline:
          if (callId != null) {
            _acceptingCallIds.remove(callId);
            await _onCallDeclined(callId);
          }
          break;

        case Event.actionCallEnded:
          if (callId != null) {
            _acceptingCallIds.remove(callId);
            await _onCallEnded(callId);
          }
          break;

        case Event.actionCallTimeout:
          if (callId != null) {
            _acceptingCallIds.remove(callId);
            await _onCallTimeout(callId);
          }
          break;

        case Event.actionCallToggleMute:
          await CallManager.instance.toggleMute();
          break;

        default:
          break;
      }
    });
  }

  static Future<void> _onCallAccepted(String callId,
      Map<dynamic, dynamic>? data, Map<dynamic, dynamic>? extra) async {
    // CRITICAL: Prevent duplicate accept processing
    if (_acceptingCallIds.contains(callId)) {
      _log('Already accepting $callId, ignoring duplicate');
      return;
    }
    _acceptingCallIds.add(callId);

    try {
      _log('>>> ACCEPTING: $callId <<<');
      _log(
          'Provider state: ${_callProvider?.state}, callId: ${_callProvider?.callId}');
      _log('CallManager callId: ${CallManager.instance.currentCallId}');

      // If already in this call and connected, return success
      if (CallManager.instance.currentCallId == callId &&
          _callProvider?.state == CallState.inCall) {
        _log('Already connected to this call');
        return;
      }

      // If CallManager has this call, accept it
      if (CallManager.instance.currentCallId == callId) {
        _log('Call in manager, accepting...');
        final result = await CallManager.instance.acceptCall();
        _log('Accept result: $result');
        return;
      }

      // Need to fetch and set up
      _log('Fetching from Firestore...');
      final repo = locate<CallRepository>();
      final call = await repo.getCall(callId);

      if (call != null) {
        _log('Got call, status: ${call.status}');
        await CallManager.instance.handleIncomingCall(call);
        final result = await CallManager.instance.acceptCall();
        _log('Accept result: $result');
      } else {
        _log('Call not found, using notification data');
        final callerName = extra?['callerName'] as String? ??
            data?['nameCaller'] as String? ??
            'Unknown';
        final roomName = extra?['roomName'] as String?;
        final callerId = extra?['callerId'] as String?;

        final fallbackCall = CallModel(
          id: callId,
          callerId: callerId ?? '',
          calleeId: '',
          callerName: callerName,
          calleeName: '',
          roomName: roomName ?? '',
          status: CallStatus.ringing,
          type: CallType.audio,
          participants: [],
        );
        await CallManager.instance.handleIncomingCall(fallbackCall);
        final result = await CallManager.instance.acceptCall();
        _log('Accept result: $result');
      }
    } catch (e, st) {
      _log('Accept error: $e');
      log('Stack:', stackTrace: st);
      _acceptingCallIds.remove(callId);
      await FlutterCallkitIncoming.endCall(callId);
    }
  }

  static Future<void> _onCallDeclined(String callId) async {
    _log('Declining: $callId');
    if (CallManager.instance.currentCallId == callId) {
      await CallManager.instance.declineCall();
    } else {
      await locate<CallRepository>().declineCall(callId);
      await FlutterCallkitIncoming.endCall(callId);
    }
  }

  static Future<void> _onCallEnded(String callId) async {
    _log('Ending: $callId');
    if (CallManager.instance.currentCallId == callId ||
        _callProvider?.callId == callId) {
      await CallManager.instance.endCall();
    }
  }

  static Future<void> _onCallTimeout(String callId) async {
    _log('Timeout: $callId');
    await locate<CallRepository>().markNoAnswer(callId);
    if (_callProvider?.callId == callId) _callProvider?.endCall();
  }

  static Future<String?> getToken() => FirebaseMessaging.instance.getToken();

  static Future<void> syncTokenToStorageAndFirestore(
      {String? tokenOverride}) async {
    try {
      final token = tokenOverride ?? await getToken();
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmTokens': {token: true},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      _log('Token sync error: $e');
    }
  }

  static void dispose() => _callkitSubscription?.cancel();
}
