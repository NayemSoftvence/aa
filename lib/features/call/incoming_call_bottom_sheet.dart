import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../common_widgets/show_call_screen.dart';
import '../../providers/call_state_provider.dart';

/// Shows incoming call as a bottom sheet that can be dragged to expand
Future<void> showIncomingCallBottomSheet({
  required BuildContext context,
  required String callId,
  required String callerId,
  required String roomName,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    builder:
        (context) => IncomingCallBottomSheet(
          callId: callId,
          callerId: callerId,
          roomName: roomName,
        ),
  );
}

class IncomingCallBottomSheet extends StatefulWidget {
  final String callId;
  final String callerId;
  final String roomName;

  const IncomingCallBottomSheet({
    super.key,
    required this.callId,
    required this.callerId,
    required this.roomName,
  });

  @override
  State<IncomingCallBottomSheet> createState() =>
      _IncomingCallBottomSheetState();
}

class _IncomingCallBottomSheetState extends State<IncomingCallBottomSheet> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        // Ringing indicator
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.withOpacity(0.1),
                            border: Border.all(color: Colors.blue, width: 2),
                          ),
                          child: const Icon(
                            Icons.phone_in_talk,
                            size: 50,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Incoming call text
                        const Text(
                          'Incoming video call',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                        const SizedBox(height: 8),

                        // Caller name
                        Text(
                          widget.callerId,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 48),

                        // Action buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Decline button
                            _CallActionButton(
                              icon: Icons.call_end,
                              label: 'Decline',
                              color: Colors.red,
                              onTap: () => _declineCall(),
                            ),

                            // Accept button
                            _CallActionButton(
                              icon: Icons.videocam,
                              label: 'Accept',
                              color: Colors.green,
                              onTap: () => _acceptCall(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptCall() async {
    try {
      await _db.collection('calls').doc(widget.callId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // Update provider
      if (mounted) {
        final callProvider = context.read<CallStateProvider>();
        callProvider.acceptCall();

        // Close bottom sheet
        Navigator.pop(context);

        // Navigate to call screen as modal
        showCallScreen(context: context, callId: widget.callId);
      }
    } catch (e) {
      print('Error accepting call: $e');
    }
  }

  Future<void> _declineCall() async {
    try {
      await _db.collection('calls').doc(widget.callId).update({
        'status': 'declined',
        'endedAt': FieldValue.serverTimestamp(),
      });

      // Update provider
      if (mounted) {
        final callProvider = context.read<CallStateProvider>();
        callProvider.endCall();

        // Close bottom sheet
        Navigator.pop(context);
      }
    } catch (e) {
      print('Error declining call: $e');
    }
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(35),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
