import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:auto_animated/auto_animated.dart';
import 'package:livekit_calling_app/loading_screen.dart';
import 'constants/custome_theme.dart';
import 'gen/colors.gen.dart';
import 'helpers/all_routes.dart';
import 'helpers/call_manager.dart';
import 'helpers/di.dart';
import 'helpers/helper_methods.dart';
import 'helpers/navigation_service.dart';
import 'helpers/notification_service.dart';
import 'networks/dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'common_widgets/call_screen_overlay.dart';
import 'providers/call_state_provider.dart';

/// Background message handler - must be top-level function

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.handleRemoteMessage(
    message,
    openedFromTray: false,
    coldStart: false,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await GetStorage.init();
  diSetup();
  DioSingleton.instance.create();

  final callProvider = CallStateProvider();

  CallManager.instance.registerProvider(callProvider);
  NotificationService.registerCallProvider(callProvider);
  await NotificationService.initialize();

  // Only restore ALREADY accepted calls
  await CallManager.instance.restoreActiveCall();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: callProvider),
      ],
      child: const MyApp(),
    ),
  );
}

Future<void> _checkPendingCalls() async {
  try {
    // First check if there's an accepted call in CallKit
    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    if (activeCalls is List && activeCalls.isNotEmpty) {
      for (final call in activeCalls) {
        final callId = call['id'] as String?;
        final isAccepted = call['isAccepted'] as bool? ?? false;

        if (callId != null && isAccepted) {
          // User accepted while app was killed - restore and connect
          await CallManager.instance.restoreActiveCall();
          return;
        }
      }
    }

    // Check for any ongoing calls in Firestore
    await CallManager.instance.restoreActiveCall();
  } catch (e) {
    debugPrint('Error checking pending calls: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    rotation();

    return AnimateIfVisibleWrapper(
      showItemInterval: const Duration(milliseconds: 150),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return const UtillScreenMobile();
        },
      ),
    );
  }
}

//all feature working fine
class UtillScreenMobile extends StatelessWidget {
  const UtillScreenMobile({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, _) async {
            showMaterialDialog(context);
          },
          child: GetMaterialApp(
            theme: ThemeData(
              unselectedWidgetColor: Colors.white,
              primarySwatch: CustomTheme.kToDark,
              useMaterial3: false,
              scaffoldBackgroundColor: AppColors.cFFFFFF,
              appBarTheme: const AppBarTheme(
                backgroundColor: AppColors.cFFFFFF,
                elevation: 0,
              ),
            ),
            debugShowCheckedModeBanner: false,
            builder: (context, widget) {
              return CallScreenOverlay(
                child: MediaQuery(data: MediaQuery.of(context), child: widget!),
              );
            },
            navigatorKey: NavigationService.navigatorKey,
            onGenerateRoute: RouteGenerator.generateRoute,
            home: const Loading(),
          ),
        );
      },
    );
  }
}
