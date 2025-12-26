import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../../../../common_widgets/custom_toast.dart';
import '../../../../helpers/navigation_service.dart';
import '../../../../networks/rx_base.dart';
import 'api.dart';

final class LivekitTokenRx extends RxResponseInt<Map<String, dynamic>> {
  final _api = LivekitApi.instance;

  LivekitTokenRx()
      : super(
          empty: <String, dynamic>{},
          dataFetcher: BehaviorSubject<Map<String, dynamic>>.seeded({}),
        );

  ValueStream<Map<String, dynamic>> get tokenStream => dataFetcher.stream;

  /// Get the current credentials
  LivekitCredentials? get credentials {
    final data = dataFetcher.valueOrNull;
    if (data == null || data.isEmpty) return null;
    return LivekitCredentials.fromJson(data);
  }

  /// Fetch token for a call
  Future<bool> fetchToken(String callId) async {
    try {
      log('[LivekitTokenRx] Fetching token for: $callId');
      final Map<String, dynamic> data = await _api.createToken(callId);
      return await handleSuccessWithReturn(data);
    } catch (error) {
      return await handleErrorWithReturn(error);
    }
  }

  /// Clear current token
  void clear() {
    dataFetcher.add({});
  }

  @override
  Future<bool> handleSuccessWithReturn(dynamic data) async {
    dataFetcher.add(data as Map<String, dynamic>);
    log('[LivekitTokenRx] Token fetched successfully');
    return true;
  }

  @override
  Future<bool> handleErrorWithReturn(dynamic error) async {
    String message = 'Failed to get call token';
    log('[LivekitTokenRx] Error: $error');

    if (error is DioException) {
      if (error.response?.data is Map) {
        message = error.response?.data['error'] as String? ?? message;
      } else if (error.message != null) {
        message = error.message!;
      }

      if (error.type == DioExceptionType.connectionError) {
        message = 'Check your network connection';
      }
    }

    // Only show toast if app UI is available (Overlay present). When called
    // from background isolates or notification handlers there may be no
    // active context, which causes an exception. Check that an OverlayState
    // is available from the navigator context before calling Get.snackbar.
    try {
      final ctx = NavigationService.context;
      final hasOverlay = ctx != null;
      if (hasOverlay) {
        customToastMessage('Error', message);
      } else {
        log('[LivekitTokenRx] UI overlay not available, skipping toast: $message');
      }
    } catch (e, st) {
      log('[LivekitTokenRx] Failed to show toast: $e');
      log(st.toString());
    }

    return false;
  }
}
