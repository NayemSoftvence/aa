import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/entities/android_params.dart';
import 'package:flutter_callkit_incoming/entities/ios_params.dart';
import 'package:livekit_calling_app/helpers/navigation_service.dart';
import '../constants/app_constants.dart';
import '../features/call/call_screen.dart';
import 'di.dart';

class NotificationService {
  NotificationService._();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static StreamSubscription? _ckSub;

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
    await FlutterCallkitIncoming.canUseFullScreenIntent();

    // Request full intent permission
    await FlutterCallkitIncoming.requestFullIntentPermission();
    //FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);
    // FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await handleRemoteMessage(message, inForeground: true);
      // getAllNotificationRx.fetchAllNotificationData();
      // if (message.notification != null && !Platform.isIOS) {
      //   showNotification(
      //     title: message.notification!.title ?? 'No Title',
      //     body: message.notification!.body ?? 'No Body',
      //   );
      // }
    });

    // Handle messages when the app is opened from a terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      await handleRemoteMessage(message, openedFromTray: true);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await handleRemoteMessage(initial, openedFromTray: true, coldStart: true);
    }
    // 6) Token handling
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
          await _acceptCall(id);
          break;
        case Event.actionCallDecline:
        case Event.actionCallEnded:
          await _declineOrEndCall(id);
          break;
        default:
          break;
      }
    });

    // Fetch FCM token
    await getToken();

    // Fetch APNS token (iOS specific)
  }

  static Future<void> handleRemoteMessage(
    RemoteMessage message, {
    bool inForeground = false,
    bool openedFromTray = false,
    bool coldStart = false,
  }) async {
    final data = message.data;
    final type = data['type'];
    log(
      'FCM message: type=$type, fg=$inForeground, opened=$openedFromTray, cold=$coldStart, data=$data',
    );

    if (type == 'incoming_call') {
      // Show native incoming call UI
      await _showIncomingCall(data);

      // Optionally also show a local notif for foreground Android (if you want)
      // if (inForeground && !Platform.isIOS && message.notification != null) {
      //   await _showLocal(
      //     title: message.notification!.title ?? 'Incoming call',
      //     body: message.notification!.body ?? 'Tap to answer',
      //   );
      // }
    } else if (type == 'call_ended') {
      // Optional: if you implement a "cancel ring" push
      await FlutterCallkitIncoming.endAllCalls();
    }
  }

  // Background handler entry (called from main)
  static Future<void> handleRemoteMessageBackground(
    RemoteMessage message,
  ) async {
    await handleRemoteMessage(message);
  }

  static Future<void> _showIncomingCall(Map<String, dynamic> data) async {
    final callId = data['callId'] as String;
    final callerId = data['callerId'] as String? ?? 'Unknown';
    final roomName = data['roomName'] as String? ?? '';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerId,
      appName: 'LiveCall',
      type: 1, // 0=audio, 1=video
      extra: {'callId': callId, 'roomName': roomName},
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: 'default', // Android will play the device’s ringtone
        backgroundColor: '#0A84FF',
        actionColor: '#4CAF50',
      ),
      ios: const IOSParams(
        //handleOnAccept: true,
        supportsVideo: true,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  static String? pendingCallId;

  static Future<void> _acceptCall(String callId) async {
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('accept update failed: $e');
    }

    // Navigate to CallScreen
    final nav = NavigationService.navigatorKey.currentState;
    if (nav != null) {
      // Replace with your actual import/path or routing
      nav.push(MaterialPageRoute(builder: (_) => CallScreen(callId: callId)));
    } else {
      log('Navigator not ready, setting pendingCallId = $callId');
      pendingCallId = callId;
    }
  }

  static Future<void> _declineOrEndCall(String callId) async {
    try {
      await FirebaseFirestore.instance.collection('calls').doc(callId).update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      log('decline update failed: $e');
    }
    await FlutterCallkitIncoming.endCall(callId);
  }

  static Future<void> _showLocal({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'main_channel',
      'Main Channel',
      importance: Importance.high,
      priority: Priority.high,
    );
    const ios = DarwinNotificationDetails();
    const details = NotificationDetails(android: android, iOS: ios);
    await _localNotificationsPlugin.show(0, title, body, details);
  }

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
      // Save token to your backend for sending notifications
    } catch (e) {
      log("Error fetching token: $e");
    }
  }
}
