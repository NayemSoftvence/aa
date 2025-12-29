import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';

import '../../../../networks/dio/dio.dart';
import '../../../../networks/endpoints.dart';
import '../../../../networks/exception_handler/data_source.dart';

/// LiveKit API client for Netlify functions
final class LivekitApi {
  LivekitApi._();
  static final LivekitApi instance = LivekitApi._();

  // ==================== TOKEN ====================

  /// Get LiveKit room token for a call
  Future<Map<String, dynamic>> createToken(String callId) async {
    try {
      log('[LivekitApi] Creating token for call: $callId');

      final Response res = await postHttp(
        Endpoints.livekitToken(),
        jsonEncode({'callId': callId}),
      );

      if (res.statusCode == 200) {
        final data = res.data is Map
            ? Map<String, dynamic>.from(res.data)
            : json.decode(res.data) as Map<String, dynamic>;

        log('[LivekitApi] Token created successfully');
        return data;
      }

      throw DataSource.DEFAULT.getFailure();
    } on DioException catch (e) {
      log('[LivekitApi] Token creation failed: ${e.message}');
      rethrow;
    }
  }

  // ==================== NOTIFICATIONS ====================

  /// Notify callee of incoming call via FCM
  Future<bool> notifyIncoming(String callId) async {
    try {
      log('[LivekitApi] Sending incoming notification for: $callId');

      final Response res = await postHttp(
        Endpoints.livekitNotify(),
        jsonEncode({'callId': callId}),
      );

      return res.statusCode == 200;
    } on DioException catch (e) {
      log('[LivekitApi] Notify incoming failed: ${e.message}');
      rethrow;
    }
  }

  /// Notify that call has ended
  Future<bool> notifyCallEnded(String callId) async {
    try {
      log('[LivekitApi] Sending end notification for: $callId');

      final Response res = await postHttp(
        Endpoints.livekitEndCall(),
        jsonEncode({'callId': callId}),
      );

      return res.statusCode == 200;
    } on DioException catch (e) {
      log('[LivekitApi] Notify ended failed: ${e.message}');
      return false; // Don't throw, just return false
    }
  }

  /// Notify that call was accepted
  Future<bool> notifyCallAccepted(String callId) async {
    try {
      log('[LivekitApi] Sending accepted notification for: $callId');

      final Response res = await postHttp(
        Endpoints.livekitCallAccepted(),
        jsonEncode({'callId': callId}),
      );

      return res.statusCode == 200;
    } on DioException catch (e) {
      log('[LivekitApi] Notify accepted failed: ${e.message}');
      return false;
    }
  }

  /// Notify that call was declined
  Future<bool> notifyCallDeclined(String callId) async {
    try {
      log('[LivekitApi] Sending declined notification for: $callId');

      final Response res = await postHttp(
        Endpoints.livekitCallDeclined(),
        jsonEncode({'callId': callId}),
      );

      return res.statusCode == 200;
    } on DioException catch (e) {
      log('[LivekitApi] Notify declined failed: ${e.message}');
      return false;
    }
  }
}

/// LiveKit credentials returned from token API
class LivekitCredentials {
  final String url;
  final String token;

  const LivekitCredentials({
    required this.url,
    required this.token,
  });

  factory LivekitCredentials.fromJson(Map<String, dynamic> json) {
    return LivekitCredentials(
      url: json['url'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }

  bool get isValid => url.isNotEmpty && token.isNotEmpty;

  @override
  String toString() => 'LivekitCredentials(url: $url, token: [hidden])';
}
