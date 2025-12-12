import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' as getx;
import '../endpoints.dart';
import 'log.dart';

final class DioSingleton {
  static final DioSingleton _singleton = DioSingleton._internal();
  static CancelToken cancelToken = CancelToken();
  DioSingleton._internal();

  static DioSingleton get instance => _singleton;

  late Dio dio;

  void create() {
    BaseOptions options = BaseOptions(
      baseUrl: url,
      connectTimeout: const Duration(milliseconds: 100000),
      receiveTimeout: const Duration(milliseconds: 100000),
      headers: {
        NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE,
        NetworkConstants.APP_KEY: NetworkConstants.APP_KEY_VALUE,
      },
    );

    dio =
        Dio(options)
          ..interceptors.add(Logger())
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                // Check/Refresh Firebase Token before every request
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final token =
                        await user.getIdToken(); // Auto-refreshes if expired
                    if (token != null) {
                      options.headers[NetworkConstants.AUTHORIZATION] =
                          "Bearer $token";
                    }
                  }
                } catch (e) {
                  if (kDebugMode) print("Auth Interceptor Error: $e");
                }
                return handler.next(options);
              },
              onError: (error, handler) {
                if (_isGlobalError(error)) {
                  _handleGlobalError(error);
                  return handler.reject(error);
                }
                return handler.next(error);
              },
            ),
          );
  }

  void update(String auth) {
    if (kDebugMode) {
      print("Dio update with auth token");
    }
    BaseOptions options = BaseOptions(
      baseUrl: url,
      responseType: ResponseType.json,
      headers: {
        NetworkConstants.ACCEPT: NetworkConstants.ACCEPT_TYPE,
        NetworkConstants.AUTHORIZATION: "Bearer $auth",
      },
      connectTimeout: const Duration(milliseconds: 100000),
      receiveTimeout: const Duration(milliseconds: 100000),
    );

    dio =
        Dio(options)
          ..interceptors.add(Logger())
          ..interceptors.add(
            InterceptorsWrapper(
              onRequest: (options, handler) async {
                // Check/Refresh Firebase Token before every request
                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user != null) {
                    final token =
                        await user.getIdToken(); // Auto-refreshes if expired
                    if (token != null) {
                      options.headers[NetworkConstants.AUTHORIZATION] =
                          "Bearer $token";
                    }
                  }
                } catch (e) {
                  if (kDebugMode) print("Auth Interceptor Error: $e");
                }
                return handler.next(options);
              },
              onError: (error, handler) {
                if (_isGlobalError(error)) {
                  _handleGlobalError(error);
                  return handler.reject(error);
                }
                return handler.next(error);
              },
            ),
          );
  }

  bool _isGlobalError(DioException error) {
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.response?.statusCode == 401 ||
        error.response?.statusCode == 403 ||
        error.response?.statusCode == 500 ||
        error.response?.statusCode == 502 ||
        error.response?.statusCode == 503;
  }

  void _handleGlobalError(DioException error) {
    // if (error.type == DioExceptionType.connectionError) {
    //   _navigateToScreen('/network-error');
    // }
    // else if (error.response?.statusCode == 401) {
    //   _navigateToScreen('/login');
    // }
    // else if (error.response?.statusCode == 500) {
    //   _navigateToScreen('/server-error');
    // }
  }

  void _navigateToScreen(String route) {
    if (getx.Get.currentRoute != route) {
      getx.Get.offAllNamed(route);
    }
  }
}

// Simplified HTTP methods - global errors are already handled by interceptor
Future<Response> postHttp(String path, [dynamic data]) async {
  return DioSingleton.instance.dio.post(
    path,
    data: data,
    cancelToken: DioSingleton.cancelToken,
  );
}

Future<Response> putHttp(String path, [dynamic data]) async {
  return DioSingleton.instance.dio.put(
    path,
    data: data,
    cancelToken: DioSingleton.cancelToken,
  );
}

Future<Response> getHttp(String path, [dynamic data]) async {
  return DioSingleton.instance.dio.get(
    path,
    cancelToken: DioSingleton.cancelToken,
  );
}

Future<Response> deleteHttp(String path, [dynamic data]) async {
  return DioSingleton.instance.dio.delete(
    path,
    data: data,
    cancelToken: DioSingleton.cancelToken,
  );
}
