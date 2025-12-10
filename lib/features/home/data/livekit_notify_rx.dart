import 'dart:developer';
import 'package:dio/dio.dart';

import '../../../common_widgets/custom_toast.dart';
import '../../../networks/rx_base.dart';
import 'livekit_netlify_api.dart';

final class LivekitNotifyRx extends RxResponseInt {
  final _api = LivekitNetlifyApi.instance;

  LivekitNotifyRx({required super.empty, required super.dataFetcher});

  Future<bool> notify(String callId) async {
    try {
      final ok = await _api.notifyIncoming(callId);
      return await handleSuccessWithReturn(ok);
    } catch (error) {
      return await handleErrorWithReturn(error);
    }
  }

  @override
  handleSuccessWithReturn(data) async => true;

  @override
  handleErrorWithReturn(error) {
    String message = 'Failed to send notification';
    log(error.toString());
    if (error is DioException) {
      message =
          error.response?.data is Map
              ? (error.response?.data['error'] ?? message)
              : (error.message ?? message);
    }
    customToastMessage('Error', message);
    return false;
  }
}
