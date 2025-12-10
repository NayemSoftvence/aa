import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_calling_app/features/auth/login.dart';
import 'package:livekit_calling_app/features/home/presentation/home.dart';
import 'constants/app_constants.dart';
import 'helpers/di.dart';
import 'helpers/helper_methods.dart';
import 'helpers/post_login.dart';
import 'networks/dio/dio.dart';
import 'welcome_screen.dart';
import 'helpers/notification_service.dart';
import 'features/call/call_screen.dart';
import 'package:get/get.dart';

final class Loading extends StatefulWidget {
  const Loading({super.key});

  @override
  State<Loading> createState() => _LoadingState();
}

class _LoadingState extends State<Loading> {
  bool _isLoading = true;
  bool isFirstTime = true;
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
    // await SocialAuthHelper.initGoogleSignIn(
    //   // clientId: 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com', // optional
    // );

    //AutoAppUpdateUtil.instance.checkAppUpdate();
    await setInitValue();

    if (appData.read(kKeyIsLoggedIn)) {
      String token = appData.read(kKeyAccessToken);
      DioSingleton.instance.update(token);
      await performPostLoginActions();
    } else {
      //  NotificationService().cancelAllNotifications();
    }
    setState(() {
      _timer!.cancel();
      _isLoading = false;
    });

    // Check for pending call
    final pendingId = NotificationService.pendingCallId;
    if (pendingId != null) {
      NotificationService.pendingCallId = null; // consume it
      // Brief delay to ensure Home is rendered first if we want to "push" on top
      // Or just navigate immediately.
      // Since we use Get.to or Navigator, if we want to come back to Home, we should ensure Home is in stack.
      // But Loading builds HomeScreen if logged in.
      // So simple navigation should work if we are already logged in.
      if (appData.read(kKeyIsLoggedIn)) {
         Get.to(() => CallScreen(callId: pendingId));
      }
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
      return appData.read(kKeyIsLoggedIn)
          ? const HomeScreen()
          : appData.read(kKeyfirstTime)
          ? const LoginScreen()
          : const LoginScreen();
    }
  }
}
