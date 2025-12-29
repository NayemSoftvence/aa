import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../constants/call_constants.dart';

class CallPermissions {
  /// Request permissions needed for a call
  /// Returns true if all required permissions are granted
  static Future<bool> requestCallPermissions({
    required BuildContext context,
    CallType type = CallType.audio,
  }) async {
    // Microphone is always required
    final micGranted = await _requestMicrophone(context);
    if (!micGranted) return false;

    // Camera only needed for video calls
    if (type == CallType.video) {
      await _requestCamera(context);
      // Camera is optional, don't fail if denied
    }

    // Notification permission (Android 13+)
    await _requestNotifications(context);

    return true;
  }

  static Future<bool> _requestMicrophone(BuildContext context) async {
    var status = await Permission.microphone.status;

    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isPermanentlyDenied) {
      if (context.mounted) {
        await _showPermissionDeniedDialog(
          context,
          'Microphone',
          'Microphone access is required for calls. Please enable it in settings.',
        );
      }
      return false;
    }

    return status.isGranted;
  }

  static Future<bool> _requestCamera(BuildContext context) async {
    var status = await Permission.camera.status;

    if (status.isGranted) return true;

    if (status.isDenied) {
      status = await Permission.camera.request();
    }

    if (!status.isGranted && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera permission denied. Video will be disabled.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    return status.isGranted;
  }

  static Future<void> _requestNotifications(BuildContext context) async {
    final status = await Permission.notification.status;

    if (!status.isGranted) {
      await Permission.notification.request();
    }
  }

  static Future<void> _showPermissionDeniedDialog(
    BuildContext context,
    String permission,
    String message,
  ) async {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$permission Required'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  /// Check if all required permissions are granted
  static Future<bool> hasCallPermissions({
    CallType type = CallType.audio,
  }) async {
    final mic = await Permission.microphone.isGranted;
    if (!mic) return false;

    if (type == CallType.video) {
      final cam = await Permission.camera.isGranted;
      return cam;
    }

    return true;
  }
}
