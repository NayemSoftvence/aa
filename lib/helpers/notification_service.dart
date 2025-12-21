import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import '../constants/app_constants.dart';
import '../providers/call_state_provider.dart';
import 'di.dart';

class NotificationService {
  NotificationService._();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription? _ckSub;
  static CallStateProvider? _callProvider;

  /// Register CallStateProvider for state synchronization
  static void registerCallProvider(CallStateProvider provider) {
    _callProvider = provider;
    log('[NotificationService] CallStateProvider registered successfully');
    log('[NotificationService] Provider current state: ${provider.state}');
  }

  static Future<void> syncFcmToken() async {
    await _syncTokenToStorageAndFirestore();
  }

  static Future<void> initialize() async {
    // Request permission for iOS

    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      log("User granted permission");
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      log("User granted provisional permission");
    } else {
      log("User denied permission");
    }

    // Initialize local notifications
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        log("Notification clicked: ${response.payload}");
      },
    );
    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestFullScreenIntentPermission();

    final canFullScreen = await FlutterCallkitIncoming.canUseFullScreenIntent();
    if (canFullScreen == false) {
      await FlutterCallkitIncoming.requestFullIntentPermission();
    }
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await handleRemoteMessage(message, inForeground: true);
    });

    // Handle messages when the app is opened from a terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await handleRemoteMessage(message, openedFromTray: true);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await handleRemoteMessage(initial, openedFromTray: true, coldStart: true);
    }

    await _syncTokenToStorageAndFirestore();
    _messaging.onTokenRefresh.listen((t) async {
      await _syncTokenToStorageAndFirestore(tokenOverride: t);
    });

    _ckSub?.cancel();
    _ckSub = FlutterCallkitIncoming.onEvent.listen((event) async {
      if (event == null) return;
      final action = event.event;
      final body = event.body ?? {};
      final id = (body['id'] ?? body['extra']?['callId'] ?? '') as String;

      switch (action) {
        case Event.actionCallAccept:
          await _acceptCall(id, body: body);
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
          await declineOrEndCall(id);
          break;
        case Event.actionCallTimeout:
          // Missed call (caller gave up or timed out)
          await declineOrEndCall(id);
          log('[NotificationService] Call missed/timed out: $id');
          break;
        case Event.actionCallToggleMute:
          final isMuted = body['isMuted'] as bool? ?? false;
          _callProvider?.setMuted(isMuted);
          break;
        case Event.actionCallToggleHold:
          // LiveKit generic handling or custom
          final isOnHold = body['isOnHold'] as bool? ?? false;
          // You could add a setHold method to provider if needed
          log('[NotificationService] Call toggled hold: $isOnHold');
          break;
        default:
          break;
      }
    });

    await getToken();
  }

  static Future<void> handleRemoteMessage(
    RemoteMessage message, {
    bool inForeground = false,
    bool openedFromTray = false,
    bool coldStart = false,
  }) async {
    final data = message.data;
    final type = data['type'];
    print(
      '[NotificationService] REMOTE MSG: $type | fg:$inForeground | bg:$openedFromTray',
    );
    log(
      'FCM message: type=$type, fg=$inForeground, opened=$openedFromTray, cold=$coldStart, data=$data',
    );

    // Always use CallKit for incoming calls (no foreground popup)
    if (type == 'incoming_call') {
      await _showIncomingCall(data);
    } else if (type == 'call_ended' || type == 'call_declined') {
      log(
        '[NotificationService] Processing call termination: $type, data: $data',
      );

      final cid = (data['callId'] ?? data['extra']?['callId']) as String?;

      print(
        '[NotificationService] Termination signal received. Killing all calls...',
      );
      try {
        if (cid != null) {
          await FlutterCallkitIncoming.endCall(cid);
          await Future.delayed(const Duration(milliseconds: 300));
        }

        // Paranoid Check: Get all active calls and kill 'em individually
        final calls = await FlutterCallkitIncoming.activeCalls();
        if (calls is List) {
          for (var c in calls) {
            final id = c['id'] as String?;
            if (id != null) {
              print('[NotificationService] Force killing lingering call: $id');
              await FlutterCallkitIncoming.endCall(id);
            }
          }
        }

        // Force kill multiple times for stubborn devices (Android background)
        await FlutterCallkitIncoming.endAllCalls();
        await Future.delayed(const Duration(milliseconds: 200));
        await FlutterCallkitIncoming.endAllCalls();

        _callProvider?.endCall();
      } catch (e) {
        print('[NotificationService] Error in termination logic: $e');
      }
    } else if (type == 'call_accepted') {
      log(
        '[NotificationService] Call accepted by receiver. Triggering CallScreen...',
      );

      final callId = data['callId'] as String?;
      final roomName = data['roomName'] as String?;

      if (callId != null && _callProvider != null) {
        // We are the caller, so we need to set the callId and start the call
        // 1. Manually set incoming call info (even though it's outgoing, we need the ID)
        _callProvider!.handleIncomingCall(
          callId: callId,
          callerId:
              data['calleeId'] as String?, // Can be useful to show who accepted
          roomName: roomName,
          isIncoming:
              false, // Wait, if call accepted, we are the CALLER. So isIncoming=false. This logic was for updating provider if we started call.
        );

        // 2. Immediately accept and start to transition to inCall state
        _callProvider!.acceptCall();
        _callProvider!.startCall();

        log(
          '[NotificationService] CallStateProvider updated to inCall for accepted call $callId',
        );
      } else {
        log(
          '[NotificationService] WARNING: Cannot handle call_accepted - callId: $callId, provider: $_callProvider',
        );
      }
    }
  }

  static Future<void> handleRemoteMessageBackground(
    RemoteMessage message,
  ) async {
    await handleRemoteMessage(message);
  }

  static Future<void> _showIncomingCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String;
    final callerId = data['callerId'] as String? ?? 'Unknown';
    final roomName = data['roomName'] as String? ?? '';
    kKeycallId = callId;

    // Fetch caller's display name from Firestore calls doc (preferred) or users collection
    String callerName = 'Unknown';
    try {
      // First try to get from calls document (has callerName stored)
      final callDoc = await FirebaseFirestore.instance.collection('calls').doc(callId).get();
      if (callDoc.exists) {
        callerName = callDoc.data()?['callerName'] as String? ?? 'Unknown';
      }
      // Fallback: fetch from users collection
      if (callerName == 'Unknown') {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(callerId).get();
        if (userDoc.exists) {
          callerName = userDoc.data()?['displayName'] as String? ?? userDoc.data()?['name'] as String? ?? 'Unknown';
        }
      }
    } catch (e) {
      log('[NotificationService] Failed to fetch caller name: $e');
    }

    log('[NotificationService] Showing incoming call: $callId from $callerId ($callerName)');

    await FlutterCallkitIncoming.endAllCalls();

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'LiveCall',
      type: 0, // 0=audio, 1=video - default to audio
      extra: {'callId': callId, 'roomName': roomName, 'callerId': callerId},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'default',
        backgroundColor: '#0A84FF',
        actionColor: '#4CAF50',
        isShowCallID: false,
        incomingCallNotificationChannelName: 'Incoming Call',
        missedCallNotificationChannelName: 'Missed Call',
      ),
      ios: const IOSParams(
        supportsVideo: false,
        audioSessionMode: 'voiceChat',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
      ),
    );

    try {
      await FlutterCallkitIncoming.showCallkitIncoming(params);
      log('[NotificationService] CallKit notification shown successfully');
    } catch (e) {
      log('[NotificationService] Error showing CallKit: $e');
    }

    // Update provider if available (use the fetched callerName)
    _callProvider?.handleIncomingCall(
      callId: callId,
      callerId: callerName,
      roomName: roomName,
      isIncoming: true,
    );

    log('[NotificationService] Provider updated with incoming call');
  }

  static Future<void> _acceptCall(
    String callId, {
    Map<String, dynamic>? body,
  }) async {
    log('[NotificationService] _acceptCall called with callId: $callId');
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      log('[NotificationService] Firestore updated with accepted status');
    } catch (e) {
      log('[NotificationService] Firestore accept update failed: $e');
    }

    // Update provider - call accepted and starting
    if (_callProvider == null) {
      log(
        '[NotificationService] WARNING: CallStateProvider is null! Overlay will not show.',
      );
      // Try to recover if provider is null (conceptually shouldn't happen if properly registered)
    } else {
      log('[NotificationService] CallStateProvider found, updating state...');

      // Hydrate if needed
      if (_callProvider!.state == CallState.idle ||
          _callProvider!.callId != callId) {
        String? callerId;
        String? roomName;

        if (body != null) {
          final extra = body['extra'] as Map<dynamic, dynamic>?;
          callerId =
              body['nameCaller'] as String? ?? extra?['nameCaller'] as String?;
          roomName = extra?['roomName'] as String?;
        }

        _callProvider!.handleIncomingCall(
          callId: callId,
          callerId: callerId ?? 'Unknown',
          roomName: roomName,
          isIncoming: true,
        );
      }

      _callProvider!.acceptCall();
      _callProvider!.startCall();
    }

    // REMOVED: notifyCallAccepted API call.
    // relying on Firestore listener on the caller side.
  }

  static Future<void> declineOrEndCall(String callId) async {
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status':
            'declined', // or 'ended' depending on context, but declined is safe generic
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('decline update failed: $e');
    }

    // REMOVED: notifyCallDeclined API call.
    // relying on Firestore listener on the caller side.

    // Update provider
    _callProvider?.endCall();

    await FlutterCallkitIncoming.endCall(callId);
  }

  // static Future<void> _showLocal({
  //   required String title,
  //   required String body,
  // }) async {
  //   const android = AndroidNotificationDetails(
  //     'main_channel',
  //     'Main Channel',
  //     importance: Importance.high,
  //     priority: Priority.high,
  //   );
  //   const ios = DarwinNotificationDetails();
  //   const details = NotificationDetails(android: android, iOS: ios);
  //   await _localNotificationsPlugin.show(0, title, body, details);
  // }

  static Future<void> _syncTokenToStorageAndFirestore({
    String? tokenOverride,
  }) async {
    try {
      final token = tokenOverride ?? await _messaging.getToken();
      log('FCM token: $token');
      appData.write(kKeyFCMToken, token);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null && token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'fcmTokens': {token: true},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      log('token sync error: $e');
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'main_channel', // Channel ID
          'Main Channel', // Channel name
          importance: Importance.high,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      0, // Notification ID
      title,
      body,
      platformDetails,
    );
  }

  static Future<void> getToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        log("APNS Token: $apnsToken");
      }
      String? token = await _messaging.getToken();
      log("Firebase Messaging Token: $token");
      appData.write(kKeyFCMToken, token);
    } catch (e) {
      log("Error fetching token: $e");
    }
  }
}
