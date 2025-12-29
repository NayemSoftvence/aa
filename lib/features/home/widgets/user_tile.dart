import 'package:flutter/material.dart';

class UserTile extends StatelessWidget {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final VoidCallback onCall;

  const UserTile({
    super.key,
    required this.uid,
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.isOnline,
    required this.lastSeen,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl!) : null,
              child: photoUrl == null ? const Icon(Icons.person) : null,
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green : Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          isOnline
              ? 'Online'
              : (lastSeen != null
                  ? 'Last seen: ${_formatAgo(lastSeen!)}'
                  : email),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: onSurface.withOpacity(0.7)),
        ),
        trailing: FilledButton.icon(
          onPressed: onCall,
          icon: const Icon(Icons.call, size: 18),
          label: const Text('Call'),
        ),
      ),
    );
  }

  static String _formatAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
