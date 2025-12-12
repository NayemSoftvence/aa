import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_state_provider.dart';
import '../features/call/call_screen.dart';

/// Helper function to show CallScreen as a full-screen modal bottom sheet
Future<void> showCallScreen({
  required BuildContext context,
  required String callId,
}) {
  // Mark as maximized when showing
  final callProvider = context.read<CallStateProvider>();
  callProvider.maximize();

  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => CallScreen(callId: callId),
  );
}
