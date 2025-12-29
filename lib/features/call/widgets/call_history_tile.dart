import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../constants/call_constants.dart';
import '../model/call_model.dart';

class CallHistoryTile extends StatelessWidget {
  final CallModel call;
  final String currentUserId;
  final VoidCallback? onTap;

  const CallHistoryTile({
    super.key,
    required this.call,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = call.isOutgoing(currentUserId);
    final isMissed = call.isMissed;
    final displayName = call.displayName(currentUserId);
    final displayPhoto = call.displayPhoto(currentUserId);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage:
            displayPhoto != null ? NetworkImage(displayPhoto) : null,
        child: displayPhoto == null
            ? Text(
                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              )
            : null,
      ),
      title: Text(
        displayName,
        style: TextStyle(
          color: isMissed ? Colors.red : null,
          fontWeight: isMissed ? FontWeight.w600 : null,
        ),
      ),
      subtitle: Row(
        children: [
          // Direction icon
          Icon(
            _getDirectionIcon(isOutgoing, isMissed),
            size: 16,
            color: isMissed ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 4),

          // Time
          Text(
            _formatTime(call.createdAt),
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),

          // Duration (if answered)
          if (call.wasAnswered && call.durationSeconds != null) ...[
            const Text(' • '),
            Text(
              call.formattedDuration,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ],

          // Call type indicator
          const SizedBox(width: 8),
          Icon(
            call.type == CallType.video ? Icons.videocam : Icons.call,
            size: 14,
            color: Colors.grey.shade500,
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          call.type == CallType.video ? Icons.videocam : Icons.call,
          color: Theme.of(context).primaryColor,
        ),
        onPressed: onTap,
        tooltip: 'Call back',
      ),
    );
  }

  IconData _getDirectionIcon(bool isOutgoing, bool isMissed) {
    if (isOutgoing) {
      return Icons.call_made;
    } else if (isMissed) {
      return Icons.call_missed;
    } else {
      return Icons.call_received;
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    return DateFormat('h:mm a').format(date);
  }
}
