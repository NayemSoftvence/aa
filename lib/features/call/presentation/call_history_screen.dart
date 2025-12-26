import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../helpers/call_manager.dart';
import '../../../helpers/di.dart';
import '../data/call_repository.dart';
import '../model/call_model.dart';
import '../widgets/call_history_tile.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final callRepository = locate<CallRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recent Calls'),
      ),
      body: StreamBuilder<List<CallModel>>(
        stream: callRepository.watchCallHistory(limit: 100),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snap.hasError) {
            return Center(
              child: Text('Error: ${snap.error}'),
            );
          }

          final calls = snap.data ?? [];

          if (calls.isEmpty) {
            return _buildEmptyState();
          }

          // Group calls by date
          final grouped = _groupByDate(calls);

          return ListView.builder(
            itemCount: grouped.length,
            itemBuilder: (context, index) {
              final entry = grouped.entries.elementAt(index);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  // Call items
                  ...entry.value.map(
                    (call) => CallHistoryTile(
                      call: call,
                      currentUserId: callRepository.currentUserId,
                      onTap: () => _callBack(
                          context, call, callRepository.currentUserId),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.call, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No recent calls',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Your call history will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Map<String, List<CallModel>> _groupByDate(List<CallModel> calls) {
    final Map<String, List<CallModel>> grouped = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final call in calls) {
      final date = call.createdAt ?? now;
      final callDate = DateTime(date.year, date.month, date.day);

      String key;
      if (callDate == today) {
        key = 'Today';
      } else if (callDate == yesterday) {
        key = 'Yesterday';
      } else if (now.difference(date).inDays < 7) {
        key = DateFormat('EEEE').format(date); // Day name
      } else {
        key = DateFormat('MMMM d, yyyy').format(date);
      }

      grouped.putIfAbsent(key, () => []).add(call);
    }

    return grouped;
  }

  Future<void> _callBack(
    BuildContext context,
    CallModel call,
    String currentUserId,
  ) async {
    final otherUserId = call.otherParticipantId(currentUserId);
    final otherUserName = call.displayName(currentUserId);
    final otherUserPhoto = call.displayPhoto(currentUserId);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Call $otherUserName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Call'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await CallManager.instance.startCall(
        calleeId: otherUserId,
        calleeName: otherUserName,
        calleePhoto: otherUserPhoto,
      );
    }
  }
}
