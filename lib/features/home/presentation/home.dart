import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../auth/login.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  String _search = '';
  bool _showOnlyOnline = false;

  User get me => _auth.currentUser!;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(12),
          child: CircleAvatar(
            radius: 18,
            backgroundImage:
                me.photoURL != null ? NetworkImage(me.photoURL!) : null,
            child:
                me.photoURL == null ? const Icon(Icons.person, size: 18) : null,
          ),
        ),
        title: const Text('LiveCall'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              _auth.signOut();
              Get.offAll(() => const LoginScreen());
            },
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          _IncomingCallBanner(myUid: me.uid, db: _db),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged:
                        (v) => setState(() => _search = v.trim().toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search people',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Online'),
                  selected: _showOnlyOnline,
                  onSelected: (v) => setState(() => _showOnlyOnline = v),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db.collection('users').snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snap.hasData) {
                  return const Center(child: Text('No users yet'));
                }

                // Filter: remove me, apply search and online toggle
                final docs =
                    snap.data!.docs.where((d) => d.id != me.uid).where((d) {
                        final data = d.data();
                        if (_showOnlyOnline && (data['isOnline'] != true)) {
                          return false;
                        }

                        if (_search.isEmpty) return true;
                        final name =
                            (data['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                        final email =
                            (data['email'] ?? '').toString().toLowerCase();
                        return name.contains(_search) ||
                            email.contains(_search);
                      }).toList()
                      ..sort((a, b) {
                        final an =
                            (a.data()['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                        final bn =
                            (b.data()['displayName'] ?? '')
                                .toString()
                                .toLowerCase();
                        return an.compareTo(bn);
                      });

                if (docs.isEmpty) {
                  return const Center(child: Text('No matching users'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final data = docs[i].data();
                    final uid = docs[i].id;
                    final name = data['displayName'] ?? 'Unknown';
                    final email = data['email'] ?? '';
                    final photo = data['photoURL'] as String?;
                    final online = data['isOnline'] == true;
                    final lastSeen = data['lastSeen'] as Timestamp?;

                    return _UserTile(
                      uid: uid,
                      name: name,
                      email: email,
                      photoUrl: photo,
                      isOnline: online,
                      lastSeen: lastSeen?.toDate(),
                      onCall: () => _startCall(calleeId: uid, calleeName: name),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Optional: open dialer / join by room name
        },
        icon: const Icon(Icons.add_call),
        label: const Text('New call'),
      ),
    );
  }

  Future<void> _startCall({
    required String calleeId,
    required String calleeName,
  }) async {
    try {
      // Create a call doc. Cloud Function can send FCM to callee on onCreate.
      final callRef = _db.collection('calls').doc();
      final roomName = 'room_${callRef.id}';
      await callRef.set({
        'callerId': me.uid,
        'calleeId': calleeId,
        'participants': [me.uid, calleeId], // useful for queries later
        'roomName': roomName,
        'status': 'ringing',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Calling $calleeName...')));

      // Next step (when ready): navigate to a "Ringing" screen or wait for accept,
      // then request LiveKit token and join the room.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
    }
  }
}

class _UserTile extends StatelessWidget {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final bool isOnline;
  final DateTime? lastSeen;
  final VoidCallback onCall;

  const _UserTile({
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
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: Theme.of(context).colorScheme.surface,
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
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
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
          icon: const Icon(Icons.call),
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

class _IncomingCallBanner extends StatelessWidget {
  final String myUid;
  final FirebaseFirestore db;

  const _IncomingCallBanner({required this.myUid, required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          db
              .collection('calls')
              .where('calleeId', isEqualTo: myUid)
              .where('status', isEqualTo: 'ringing')
              .limit(1)
              .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final d = snap.data!.docs.first;
        final callId = d.id;
        final callerId = d['callerId'] as String?;
        final roomName = d['roomName'] as String?;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueAccent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.ring_volume_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Incoming call${callerId != null ? ' from $callerId' : ''}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              TextButton(
                onPressed:
                    () => db.collection('calls').doc(callId).update({
                      'status': 'declined',
                      'endedAt': FieldValue.serverTimestamp(),
                    }),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  await db.collection('calls').doc(callId).update({
                    'status': 'accepted',
                    'acceptedAt': FieldValue.serverTimestamp(),
                  });
                  // Next step: fetch LiveKit token and join roomName.
                },
                child: const Text('Accept'),
              ),
            ],
          ),
        );
      },
    );
  }
}
