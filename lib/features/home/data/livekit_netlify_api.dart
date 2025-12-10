import 'dart:convert';
import 'package:dio/dio.dart';

import '../../../networks/dio/dio.dart';
import '../../../networks/endpoints.dart';
import '../../../networks/exception_handler/data_source.dart';

final class LivekitNetlifyApi {
  LivekitNetlifyApi._();
  static final LivekitNetlifyApi instance = LivekitNetlifyApi._();

  Future<Map<String, dynamic>> createToken(String callId) async {
    try {
      final Response res = await postHttp(
        Endpoints.livekitToken(), // absolute URL, baseUrl ignored
        jsonEncode({'callId': callId}),
      );
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(
          res.data is Map ? res.data : json.decode(res.data),
        );
      }
      throw DataSource.DEFAULT.getFailure();
    } on DioException catch (_) {
      rethrow;
    }
  }

  Future<bool> notifyIncoming(String callId) async {
    try {
      final Response res = await postHttp(
        Endpoints.livekitNotify(),
        jsonEncode({'callId': callId}),
      );
      return res.statusCode == 200;
    } on DioException catch (_) {
      rethrow;
    }
  }

  Future<bool> notifyCallEnded(String callId) async {
    try {
      final Response res = await postHttp(
        Endpoints.livekitEndCall(), // You'll need to add this endpoint
        jsonEncode({'callId': callId}),
      );
      return res.statusCode == 200;
    } on DioException catch (_) {
      return false; // Don't throw, just return false if it fails
    }
  }
}
