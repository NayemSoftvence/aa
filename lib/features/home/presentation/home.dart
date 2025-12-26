import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import '../../../common_widgets/call_bar_overlay.dart';
import '../../../constants/app_constants.dart';
import '../../../constants/call_constants.dart';
import '../../../helpers/call_manager.dart';
import '../../../helpers/di.dart';
import '../../../providers/call_state_provider.dart';
import '../../auth/presentation/login.dart';
import '../../call/presentation/call_history_screen.dart';
import '../widgets/user_tile.dart';

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
  CallManager get _callManager => CallManager.instance;

  @override
  void initState() {
    super.initState();
    // NO call restoration here - it's handled in main.dart
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startCall({
    required String calleeId,
    required String calleeName,
    String? calleePhoto,
  }) async {
    final success = await _callManager.startCall(
      calleeId: calleeId,
      calleeName: calleeName,
      calleePhoto: calleePhoto,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Calling $calleeName...'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final callProvider = context.read<CallStateProvider>();
    if (callProvider.hasActiveCall) {
      await _callManager.endCall();
    }

    await _auth.signOut();
    appData.write(kKeyIsLoggedIn, false);
    Get.offAll(() => const LoginScreen());
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
            tooltip: 'Call History',
            onPressed: () => Get.to(() => const CallHistoryScreen()),
            icon: const Icon(Icons.history),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
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
                stream: _db.collection(CallCollections.users).snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snap.hasData) {
                    return const Center(child: Text('No users yet'));
                  }

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
                      final name = data['displayName'] as String? ?? 'Unknown';
                      final email = data['email'] as String? ?? '';
                      final photo = data['photoURL'] as String?;
                      final online = data['isOnline'] == true;
                      final lastSeen = data['lastSeen'] as Timestamp?;

                      return UserTile(
                        uid: uid,
                        name: name,
                        email: email,
                        photoUrl: photo,
                        isOnline: online,
                        lastSeen: lastSeen?.toDate(),
                        onCall: () => _startCall(
                          calleeId: uid,
                          calleeName: name,
                          calleePhoto: photo,
                        ),
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
}
