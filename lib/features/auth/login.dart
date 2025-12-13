import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../helpers/notification_service.dart';
import '../../helpers/social_auth.dart';
import '../home/presentation/home.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  bool _appleAvailable = false;

  @override
  void initState() {
    super.initState();
    _checkAppleAvailability();
  }

  Future<void> _checkAppleAvailability() async {
    // Only check on non-web platforms
    bool available = false;
    try {
      if (!kIsWeb) {
        available = await SignInWithApple.isAvailable();
      }
    } catch (_) {}
    if (mounted) setState(() => _appleAvailable = available);
  }

  Future<void> _onAuthSuccess(User user, String idToken) async {
    // Create/merge user profile in Firestore

    final users = FirebaseFirestore.instance.collection('users');
    await users.doc(user.uid).set({
      'uid': user.uid,
      'displayName': user.displayName,
      'photoURL': user.photoURL,
      'email': user.email,
      'lastSeen': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // User logged in or restored session
    NotificationService.syncFcmToken();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Welcome, ${user.displayName ?? 'there'}!')),
    );
    Get.to(() => const HomeScreen());

    // If you're using an AuthGate that listens to authStateChanges,
    // no navigation is needed here. It will switch to Home automatically.
  }

  Future<void> _signInWithGoogle() async {
    try {
      await SocialAuthHelper.signInWithGoogle(onSuccess: _onAuthSuccess);
    } catch (e) {
      _showError(e.toString());
    } finally {}
  }

  Future<void> _signInWithApple() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await SocialAuthHelper.signInWithApple(onSuccess: _onAuthSuccess);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Sign-in failed: $message')));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.secondaryContainer],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo + Title
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.call_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'LiveCall',
                        style: textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Call anyone instantly with LiveKit',
                        style: textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withOpacity(0.95),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Card with actions
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 24,
                              spreadRadius: -8,
                              color: Colors.black.withOpacity(0.25),
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PrimaryButton(
                              label: 'Sign in with Google',
                              onPressed: _signInWithGoogle,
                              icon: Icons.login,
                            ),
                            if (_appleAvailable) ...[
                              const SizedBox(height: 12),
                              _SecondaryButton(
                                label: 'Continue with Apple',
                                onPressed: _signInWithApple,
                                icon: Icons.apple,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  'By continuing, you agree to our',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    // TODO: open Terms URL
                                  },
                                  child: Text(
                                    'Terms',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                                Text(
                                  'and',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    // TODO: open Privacy URL
                                  },
                                  child: Text(
                                    'Privacy Policy',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Loading overlay
          // if (_loading)
          //   Container(
          //     color: Colors.black.withOpacity(0.15),
          //     child: const Center(child: CircularProgressIndicator()),
          //   ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.login),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData? icon;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon ?? Icons.person),
        label: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
