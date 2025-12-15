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
        _handleLogout();
      }
    });
  }

  loadInitialData() async {
    print('[LoadingScreen] loadInitialData started');

    await setInitValue();

    if (appData.read(kKeyIsLoggedIn)) {
      String token = appData.read(kKeyAccessToken);
      DioSingleton.instance.update(token);
      await performPostLoginActions();
    }

    // CallStateProvider registration moved to main.dart for early initialization

    setState(() {
      _timer!.cancel();
      _isLoading = false;
    });
  }

  void _handleLogout() {
    appData.write(kKeyIsLoggedIn, false);
  }

  @override
  Widget build(BuildContext context) {
    return appData.read(kKeyIsLoggedIn)
        ? const HomeScreen()
        : const LoginScreen();
  }
}
