import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';

import '../../../common_widgets/custom_toast.dart';
import '../../../networks/rx_base.dart';
import 'livekit_netlify_api.dart';

final class LivekitTokenRx extends RxResponseInt {
  final _api = LivekitNetlifyApi.instance;

  LivekitTokenRx({required super.empty, required super.dataFetcher});

  ValueStream<dynamic> get tokenStream => dataFetcher.stream;

  Future<bool> fetchToken(String callId) async {
    try {
      final Map<String, dynamic> data = await _api.createToken(callId);
      return await handleSuccessWithReturn(data);
    } catch (error) {
      return await handleErrorWithReturn(error);
    }
  }

  @override
  handleSuccessWithReturn(data) async {
    dataFetcher.add(data);
    return true;
  }

  @override
  handleErrorWithReturn(error) {
    String message = 'Something went wrong';
    log(error.toString());
    if (error is DioException) {
      message =
          error.response?.data is Map
              ? (error.response?.data['error'] ?? message)
              : (error.message ?? message);
      if (error.type == DioExceptionType.connectionError) {
        message = 'Check your network connection';
      }
    }
    customToastMessage('Error', message);
    return false;
  }
}
