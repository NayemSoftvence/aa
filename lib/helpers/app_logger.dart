import 'package:flutter/foundation.dart';

/// Log levels
enum LogLevel { debug, info, warning, error }

/// Centralized logging utility
class AppLogger {
  static LogLevel minLevel = kDebugMode ? LogLevel.debug : LogLevel.warning;

  /// Debug log
  static void d(String tag, String message) {
    _log(LogLevel.debug, tag, message);
  }

  /// Info log
  static void i(String tag, String message) {
    _log(LogLevel.info, tag, message);
  }

  /// Warning log
  static void w(String tag, String message) {
    _log(LogLevel.warning, tag, message);
  }

  /// Error log
  static void e(String tag, String message,
      [Object? error, StackTrace? stack]) {
    _log(LogLevel.error, tag, message);
    if (error != null) {
      debugPrint('  Error: $error');
      if (stack != null) {
        debugPrint('  Stack: $stack');
      }
    }

    // In production, report to crash analytics
    // if (!kDebugMode && error != null) {
    //   FirebaseCrashlytics.instance.recordError(error, stack);
    // }
  }

  static void _log(LogLevel level, String tag, String message) {
    if (level.index < minLevel.index) return;

    final prefix = switch (level) {
      LogLevel.debug => '🔍',
      LogLevel.info => 'ℹ️',
      LogLevel.warning => '⚠️',
      LogLevel.error => '❌',
    };

    final timestamp = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('$prefix [$timestamp] [$tag] $message');
  }
}
