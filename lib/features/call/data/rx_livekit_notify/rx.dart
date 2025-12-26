import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:rxdart/subjects.dart';
import '../../../../common_widgets/custom_toast.dart';
import '../../../../networks/rx_base.dart';
import '../rx_livekit_token/api.dart';

final class LivekitNotifyRx extends RxResponseInt<bool> {
  final _api = LivekitApi.instance;

  LivekitNotifyRx()
      : super(
          empty: false,
          dataFetcher: BehaviorSubject<bool>.seeded(false),
        );

  /// Send incoming call notification to callee
  Future<bool> notifyIncoming(String callId) async {
    try {
      log('[LivekitNotifyRx] Notifying incoming: $callId');
      final ok = await _api.notifyIncoming(callId);
      return await handleSuccessWithReturn(ok);
    } catch (error) {
      return await handleErrorWithReturn(error);
    }
  }

  /// Notify that call ended
  Future<bool> notifyEnded(String callId) async {
    try {
      log('[LivekitNotifyRx] Notifying ended: $callId');
      final ok = await _api.notifyCallEnded(callId);
      return ok;
    } catch (error) {
      log('[LivekitNotifyRx] Notify ended failed: $error');
      return false; // Silent fail
    }
  }

  /// Notify that call was accepted
  Future<bool> notifyAccepted(String callId) async {
    try {
      log('[LivekitNotifyRx] Notifying accepted: $callId');
      final ok = await _api.notifyCallAccepted(callId);
      return ok;
    } catch (error) {
      log('[LivekitNotifyRx] Notify accepted failed: $error');
      return false;
    }
  }

  /// Notify that call was declined
  Future<bool> notifyDeclined(String callId) async {
    try {
      log('[LivekitNotifyRx] Notifying declined: $callId');
      final ok = await _api.notifyCallDeclined(callId);
      return ok;
    } catch (error) {
      log('[LivekitNotifyRx] Notify declined failed: $error');
      return false;
    }
  }

  @override
  Future<bool> handleSuccessWithReturn(dynamic data) async {
    log('[LivekitNotifyRx] Notification sent successfully');
    return true;
  }

  @override
  Future<bool> handleErrorWithReturn(dynamic error) async {
    String message = 'Failed to send notification';
    log('[LivekitNotifyRx] Error: $error');

    if (error is DioException) {
      if (error.response?.data is Map) {
        message = error.response?.data['error'] as String? ?? message;
      } else if (error.message != null) {
        message = error.message!;
      }
    }

    customToastMessage('Error', message);
    return false;
  }
}
