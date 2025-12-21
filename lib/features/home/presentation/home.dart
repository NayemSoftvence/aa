import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:provider/provider.dart';
import '../../../common_widgets/call_bar_overlay.dart';
import '../../../constants/app_constants.dart';
import '../../../helpers/di.dart';
import '../../../providers/call_state_provider.dart';
import '../../auth/login.dart';
import '../data/livekit_netlify_api.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  StreamSubscription? _callDocSubscription;
  StreamSubscription? _restoreCallSub;

  String _search = '';
  bool _showOnlyOnline = false;

  User get me => _auth.currentUser!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCallRestoration();
    _checkNativeActiveCalls(); // Also check immediately on load
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNativeActiveCalls();
    }
  }

  /// Checks if CallKit has an active call that we missed
  Future<void> _checkNativeActiveCalls() async {
    try {
      final calls = await FlutterCallkitIncoming.activeCalls();
      if (calls is List && calls.isNotEmpty) {
        print('[HomeScreen] Found ${calls.length} active native calls');
        for (final call in calls) {
          final data = call as Map<dynamic, dynamic>;
          final callId = data['id'] as String?;
          final extra = data['extra'] as Map<dynamic, dynamic>?;
          final caller =
              data['nameCaller'] as String? ?? extra?['nameCaller'] as String?;
          final roomName = extra?['roomName'] as String?;

          if (callId != null) {
            final callProvider = context.read<CallStateProvider>();
            // If provider doesn't know about this call, hydrate it
            if (callProvider.callId != callId ||
                callProvider.state == CallState.idle) {
              print('[HomeScreen] Syncing native call $callId to provider');
              callProvider.handleIncomingCall(
                callId: callId,
                callerId: caller ?? 'Unknown',
                roomName: roomName,
                isIncoming: true, // Assume incoming for native sync usually
              );
              callProvider.acceptCall();
              callProvider.startCall();
            }
          }
        }
      }
    } catch (e) {
      print('[HomeScreen] Error checking native calls: $e');
    }
  }

  void _setupCallRestoration() {
    // Listen for any active calls involving me
    // This handles:
    // 1. App restart during call
    // 2. Ensuring UI stays in sync with 'accepted' state
    _restoreCallSub = _db
        .collection('calls')
        .where('participants', arrayContains: me.uid)
        .where('status', isEqualTo: 'accepted')
        .limit(5) // Fetch a few to find the valid one
        .snapshots()
        .listen((snap) {
      if (snap.docs.isNotEmpty) {
        // Find the most recent valid call
        QueryDocumentSnapshot<Map<String, dynamic>>? targetDoc;
        DateTime? latestTime;

        for (var doc in snap.docs) {
          final data = doc.data();
          final ts = data['createdAt'] as Timestamp?;
          if (ts == null) continue;

          final dt = ts.toDate();
          // Ignore calls older than 6 hours
          if (DateTime.now().difference(dt).inHours > 6) continue;

          if (latestTime == null || dt.isAfter(latestTime)) {
            latestTime = dt;
            targetDoc = doc;
          }
        }

        if (targetDoc != null) {
          final data = targetDoc.data();
          final callId = targetDoc.id;

          final callProvider = context.read<CallStateProvider>();
          // Only restore if we aren't already in THAT call
          if (callProvider.callId != callId || !callProvider.isInCall) {
            print('[HomeScreen] Restoring active recent call: $callId');

            final isMeCaller = data['callerId'] == me.uid;
            final callerName = isMeCaller
                ? (data['callerName'] as String? ?? 'Unknown')
                : (data['callerId'] as String? ?? 'Unknown');

            callProvider.handleIncomingCall(
              callId: callId,
              callerId: callerName,
              roomName: data['roomName'] as String?,
              isIncoming: !isMeCaller,
            );
            callProvider.acceptCall();
            callProvider.startCall();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _callDocSubscription?.cancel();
    _restoreCallSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              appData.write(kKeyIsLoggedIn, false);
            },
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: CallBarOverlay(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) =>
                          setState(() => _search = v.trim().toLowerCase()),
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
                        (data['displayName'] ?? '').toString().toLowerCase();
                    final email =
                        (data['email'] ?? '').toString().toLowerCase();
                    return name.contains(_search) || email.contains(_search);
                  }).toList()
                        ..sort((a, b) {
                          final an = (a.data()['displayName'] ?? '')
                              .toString()
                              .toLowerCase();
                          final bn = (b.data()['displayName'] ?? '')
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
                        onCall: () =>
                            _startCall(calleeId: uid, calleeName: name),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
      final callId = callRef.id;

      await callRef.set({
        'callerId': me.uid,
        'callerName': calleeName, // Store the callee name (who we're calling)
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

      // Update provider to prepare for call (set generic info)
      final callProvider = context.read<CallStateProvider>();
      callProvider.handleIncomingCall(
        callId: callId,
        callerId: calleeName, // Show who we are calling
        roomName: roomName,
        isIncoming: false, // We are the caller
      );

      // Cancel any existing listener
      await _callDocSubscription?.cancel();

      // Listen to the call document for status changes (accepted/declined)
      _callDocSubscription = callRef.snapshots().listen((snapshot) async {
        if (!snapshot.exists) return;

        final data = snapshot.data();
        final status = data?['status'] as String?;

        print('[HomeScreen] Call $callId status update: $status');

        if (status == 'accepted') {
          // Updates provider to transition to InCall state
          // This will trigger CallScreenOverlay to show the CallScreen
          callProvider.acceptCall();
          callProvider.startCall();
          // Hand off to CallScreen, stop listening here to avoid double logic
          await _callDocSubscription?.cancel();
        } else if (status == 'declined' || status == 'ended') {
          callProvider.endCall();
          await _callDocSubscription?.cancel();
        }
      });

      // Optional: send FCM push to callee (don’t block UI)
      unawaited(
        LivekitNetlifyApi.instance
            .notifyIncoming(callRef.id)
            .catchError((_) {}),
      );

      // Provider will be updated when call starts
      // Overlay will show CallScreen automatically
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
