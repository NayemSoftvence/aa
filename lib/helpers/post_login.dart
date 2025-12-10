// ignore_for_file: use_build_context_synchronously

import 'package:livekit_calling_app/networks/dio/dio.dart';

import '../constants/app_constants.dart';
import 'di.dart';

Future<void> performPostLoginActions() async {
  final token = appData.read(kKeyAccessToken);
  DioSingleton.instance.update(token);
  // API CALL 1 - If this fails with global error
  // await apiCall1();
  // // API CALL 2 - Won't execute
  // await apiCall2();
  // // API CALL 3 - Won't execute
  // await apiCall3();
}
