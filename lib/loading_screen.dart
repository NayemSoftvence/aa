import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_calling_app/features/auth/login.dart';
import 'package:livekit_calling_app/features/home/presentation/home.dart';
import 'package:provider/provider.dart';
import 'constants/app_constants.dart';
import 'helpers/di.dart';
import 'helpers/helper_methods.dart';
import 'helpers/post_login.dart';
import 'networks/dio/dio.dart';
import 'welcome_screen.dart';
import 'helpers/notification_service.dart';
import 'features/call/call_screen.dart';
import 'providers/call_state_provider.dart';
import 'package:get/get.dart';

final class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    loadInitialData();

    super.initState();
    _timer = Timer(const Duration(seconds: 35), () {
      if (_isLoading) {
        // Only log out if internet is connected but loading is taking too long
        _handleLogout();
      }
    });
  }

  loadInitialData() async {
    print('[LoadingScreen] loadInitialData started');
    // await SocialAuthHelper.initGoogleSignIn(
    //   // clientId: 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com', // optional
    // );

    //AutoAppUpdateUtil.instance.checkAppUpdate();
    await setInitValue();
    print('[LoadingScreen] setInitValue completed');

    if (appData.read(kKeyIsLoggedIn)) {
      String token = appData.read(kKeyAccessToken);
      DioSingleton.instance.update(token);
      await performPostLoginActions();
    } else {
      //  NotificationService().cancelAllNotifications();
    }

    // Register the provider with NotificationService
    final callProvider = Provider.of<CallStateProvider>(context, listen: false);
    NotificationService.setCallStateProvider(callProvider);

    // Check if there's a pending call from the old system (fallback)
    final pendingCallId = NotificationService.pendingCallId;
    if (pendingCallId != null) {
      print('[LoadingScreen] Found pending call from fallback: $pendingCallId');
      callProvider.handleIncomingCall(callId: pendingCallId);
      callProvider.acceptCall();
      NotificationService.pendingCallId = null;
    }

    print('[LoadingScreen] setState completed, _isLoading=false');

    // Check for pending call AFTER the first frame is rendered
    // This ensures HomeScreen is built and Navigator is ready, but happens immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('[LoadingScreen] First frame rendered, checking pending call');
      if (mounted) {
        _checkPendingCall();
      }
    });

    setState(() {
      _timer!.cancel();
      _isLoading = false;
    });
  }

  void _checkPendingCall() {
    final callProvider = Provider.of<CallStateProvider>(context, listen: false);
    final callId = callProvider.callId;

    print(
      '[LoadingScreen] Checking pending call from provider: callId=$callId, state=${callProvider.state}, mounted=$mounted, isLoggedIn=${appData.read(kKeyIsLoggedIn)}',
    );

    if (callProvider.hasPendingCall &&
        mounted &&
        appData.read(kKeyIsLoggedIn)) {
      print('[LoadingScreen] Navigating to CallScreen with callId: $callId');
      callProvider.startCall();
      Get.to(() => CallScreen(callId: callId!));
    }
  }

  void _handleLogout() {
    appData.write(kKeyIsLoggedIn, false);

    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (context) => LogInScreen()),
    // );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const WelcomeScreen();
    } else {
      // Listen to provider for call state changes
      return Consumer<CallStateProvider>(
        builder: (context, callProvider, child) {
          // If there's a pending call after loading, navigate
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (callProvider.hasPendingCall &&
                mounted &&
                appData.read(kKeyIsLoggedIn) &&
                !_isLoading) {
              print(
                '[LoadingScreen] Provider detected pending call, navigating...',
              );
              callProvider.startCall();
              Get.to(() => CallScreen(callId: callProvider.callId!));
            }
          });

          return appData.read(kKeyIsLoggedIn)
              ? const HomeScreen()
              : appData.read(kKeyfirstTime)
              ? const LoginScreen()
              : const LoginScreen();
        },
      );
    }
  }
}
