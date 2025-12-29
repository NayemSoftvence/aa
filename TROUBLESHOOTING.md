# LiveKit Calling App - Troubleshooting & FAQ

## Troubleshooting Guide

### Setup Issues

#### 1. Flutter Installation Problems

**Problem**: `flutter doctor` shows errors

**Solution**:
```bash
# Update Flutter
flutter upgrade

# Clean Flutter cache
flutter clean

# Verify installation
flutter doctor -v

# If still issues, reinstall:
cd ~
rm -rf flutter
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"
```

#### 2. Pub Get Fails

**Problem**: `flutter pub get` hangs or fails

**Solution**:
```bash
# Clear pub cache
flutter pub cache clean

# Try again
flutter pub get

# Or use force flag
flutter pub get --force-packages-resolution
```

#### 3. Build Runner Issues

**Problem**: `flutter pub run build_runner build` fails

**Solution**:
```bash
# Delete build files
rm -rf .dart_tool

# Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

---

### Firebase Configuration Issues

#### 1. GoogleService Files Not Found

**Problem**: 
```
Error: Could not find GoogleService-Info.plist
```

**Solution**:
```bash
# Download from Firebase Console:
# 1. Go to Project Settings > Your Apps
# 2. Select iOS app > Download GoogleService-Info.plist
# 3. Place in: livekit_calling_app/ios/Runner/
# 
# Similarly for Android:
# Download google-services.json
# Place in: livekit_calling_app/android/app/

# Verify
ls ios/Runner/GoogleService-Info.plist
ls android/app/google-services.json
```

#### 2. Firebase Initialization Failed

**Problem**:
```
Error: Firebase initialization failed
```

**Solution**:
```bash
# Check firebase_options.dart has correct config
cat lib/firebase_options.dart

# Verify Firebase project ID in pubspec.yaml matches

# Re-download config files:
firebase setup:web  # For web
firebase setup:android  # For Android
firebase setup:ios  # For iOS
```

#### 3. Firebase Auth Not Working

**Problem**: Login always fails

**Solution**:
```bash
# Check Firebase Console:
# 1. Enable Google Sign-In provider
# 2. Add Android SHA-1 fingerprint
# 3. Configure iOS bundle ID
# 4. Set OAuth consent screen

# Get Android SHA-1:
cd android
./gradlew signingReport

# Check iOS Bundle ID matches app
grep -r "BUNDLE_IDENTIFIER" ios/Runner.xcodeproj
```

---

### Authentication Issues

#### 1. Google Sign-In Not Available

**Problem**: "Sign in with Google" button doesn't work

**Solution**:
```bash
# Verify dependencies installed
flutter pub get

# Check google_sign_in configuration:
# android/build.gradle has correct version
# ios/Podfile has correct pod

# Try rebuild
flutter clean
flutter pub get
flutter run
```

#### 2. Apple Sign-In Not Working (iOS)

**Problem**: "Sign in with Apple" button doesn't work on iOS

**Solution**:
```bash
# Check iOS setup:
# 1. Open ios/Runner.xcworkspace (NOT .xcodeproj)
# 2. Select Runner > Signing & Capabilities
# 3. Add "Sign In with Apple" capability
# 4. Ensure team is selected

# Rebuild
flutter clean
flutter build ios

# Run on real device (Simulator doesn't fully support Sign in with Apple)
flutter run -d <device-name>
```

#### 3. ID Token Expiration Issues

**Problem**: "Invalid token" errors after 1 hour

**Solution**:
```dart
// Token auto-refreshes but ensure this interceptor is in place:
InterceptorsWrapper(
  onRequest: (options, handler) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        if (token != null) {
          options.headers['Authorization'] = "Bearer $token";
        }
      }
    } catch (e) {
      print("Auth Interceptor Error: $e");
    }
    return handler.next(options);
  },
)
```

---

### Notification Issues

#### 1. FCM Token Not Syncing

**Problem**: `appData.read(kKeyFCMToken)` is null

**Solution**:
```dart
// Check permissions granted
// In app > Info.plist (iOS) or AndroidManifest.xml (Android)
// Should include:
// - INTERNET
// - RECEIVE_BOOT_COMPLETED
// - WAKE_LOCK

// Force sync FCM token
NotificationService.syncFcmToken();

// Wait and check
await Future.delayed(Duration(seconds: 5));
final token = appData.read(kKeyFCMToken);
print('FCM Token: $token');
```

#### 2. Notifications Not Received (App in Background)

**Problem**: Incoming call notification doesn't show when app is backgrounded

**Solution**:

**Android**:
```bash
# 1. Ensure notification icon configured
# 2. Check AndroidManifest.xml has notifications permission
# 3. Verify firebase_messaging configured

# Debug
adb logcat | grep FCM
adb shell dumpsys activity service GcmService
```

**iOS**:
```bash
# 1. Open ios/Runner.xcworkspace
# 2. Select Runner > Capabilities > Push Notifications (ON)
# 3. Ensure APNS certificate uploaded to Firebase

# Test
# Send notification from Firebase Console
# Check Console.app for push notification logs
```

#### 3. flutter_callkit_incoming Not Showing

**Problem**: Native call UI doesn't appear on incoming call

**Solution**:
```dart
// Ensure CallStateProvider initialized early in main()
final callProvider = CallStateProvider();
NotificationService.registerCallProvider(callProvider);

// Check notification payload has correct format:
// data: {
//   "type": "incoming_call",
//   "callId": "...",
//   "roomName": "...",
//   "callerId": "..."
// }

// iOS: Ensure VoIP push configured
// Android: Ensure flutter_callkit_incoming service running
```

---

### Live Call Issues

#### 1. WebRTC Connection Failed

**Problem**: "Failed to connect to LiveKit" or video doesn't appear

**Solution**:
```dart
// Check token is valid
final response = await dio.post('/api/functions/token', ...);
print('Token received: ${response.statusCode}');

// Check LiveKit server URL
print('LIVEKIT_URL: ${process.env.LIVEKIT_URL}');

// Try connecting with error logging
try {
  await liveKitClient.connect(url, token, roomName);
} catch (e) {
  print('LiveKit connection error: $e');
  // Check network connectivity
  // Verify firewall allows WebRTC
  // Check browser allows camera access
}
```

#### 2. No Video/Audio

**Problem**: Video shows but no media streams

**Solution**:
```bash
# Check permissions granted:
# iOS: Info.plist has NSCameraUsageDescription, NSMicrophoneUsageDescription
# Android: AndroidManifest.xml has CAMERA, RECORD_AUDIO, MODIFY_AUDIO_SETTINGS

# Grant permissions at runtime
flutter_permission_handler.Permission.camera.request();
flutter_permission_handler.Permission.microphone.request();

# Verify in app:
import 'package:permission_handler/permission_handler.dart';

final cameraStatus = await Permission.camera.status;
final micStatus = await Permission.microphone.status;

if (cameraStatus.isDenied || micStatus.isDenied) {
  // Request permissions
  await [Permission.camera,Permission.microphone].request();
}
```

#### 3. Poor Video Quality

**Problem**: Video is laggy or pixelated

**Solution**:
```dart
// Check network connection
final connectivity = await Connectivity().checkConnectivity();
if (connectivity == ConnectivityResult.none) {
  print('No internet connection');
}

// Monitor connection quality
liveKitClient.onConnectionQualityChanged.listen((quality) {
  print('Connection quality: $quality');
  // quality can be: good, poor, lost
});

// Check server logs for bitrate issues
// May need to reduce quality settings for poor connections
```

---

### Backend/API Issues

#### 1. Token Endpoint Returns 404

**Problem**: 
```
POST /api/functions/token returns 404
```

**Solution**:
```bash
# Check function file exists
ls livekit/netlify/functions/token.js

# Check netlify.toml
cat livekit/netlify.toml

# Should contain:
# [functions]
# directory = "netlify/functions"
# node_bundler = "esbuild"

# Verify function deployed
netlify functions:list

# If local dev:
cd livekit
netlify dev
# Should show: Loaded function token
```

#### 2. Firebase Auth Verification Fails

**Problem**:
```
Error: Failed to verify token
```

**Solution**:
```javascript
// In token.js, add debugging:
console.log('Received token:', idToken.substring(0, 20) + '...');
try {
  const decoded = await admin.auth().verifyIdToken(idToken);
  console.log('Decoded UID:', decoded.uid);
} catch (error) {
  console.error('Verification error:', error.message);
}

// Check Firebase credentials
console.log('Project ID:', process.env.FIREBASE_PROJECT_ID);
console.log('Client Email:', process.env.FIREBASE_CLIENT_EMAIL);

// Verify private key is correctly base64 encoded
const key = Buffer.from(process.env.FIREBASE_PRIVATE_KEY_BASE64, 'base64').toString('utf8');
console.log('Key starts with:', key.substring(0, 30));
```

#### 3. Firestore Query Fails

**Problem**: "Permission denied" when accessing Firestore

**Solution**:
```bash
# Check Firestore rules are correct:
firebase firestore:rules:get

# Should allow authenticated users to read/write their data:
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }
  }
}

# Deploy rules:
firebase deploy --only firestore:rules
```

---

## FAQ

### Q1: How do I run the app on a real device?

**A:**
```bash
# Connect device via USB
# Enable Developer Mode on device
# Check device detected:
flutter devices

# Run on device:
flutter run -d <device-id>

# Or let Flutter auto-select:
flutter run
```

---

### Q2: Can I test without signing in?

**A:**
No, authentication is required. However, for testing:
```dart
// In main.dart, you can hardcode a test route:
if (kDebugMode && false) { // Change false to true to skip auth
  return const HomeScreen();
}
```

For Firebase emulator testing:
```bash
firebase emulators:start
# This allows testing without real Firebase
```

---

### Q3: How do I debug Firebase calls?

**A:**
```bash
# Monitor Firestore changes
firebase firestore:delete
firebase firestore:inspect

# Check Authentication
firebase auth:list

# View Function logs
firebase functions:log

# Use Firestore Emulator UI
# Open http://localhost:4000 while running emulator
```

---

### Q4: Why is my APK so large?

**A:**
```bash
# Analyze APK
flutter build apk --analyze-size

# To reduce size:
# 1. Enable R8 shrinking (Android)
# 2. Remove unused dependencies
# 3. Use split APKs by ABI:
flutter build apk --split-per-abi

# Result: separate APKs for arm64, armv7, x86
```

---

### Q5: How do I handle app crashes?

**A:**
```dart
// Add crash reporting with Firebase Crashlytics
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

FlutterError.onError = (errorDetails) {
  FirebaseCrashlytics.instance.recordFlutterError(errorDetails);
};

// For async errors
PlatformDispatcher.instance.onError = (error, stack) {
  FirebaseCrashlytics.instance.recordError(error, stack);
  return true;
};

// View crashes in Firebase Console > Crashlytics
```

---

### Q6: Can I host this on my own server instead of Firebase?

**A:**
Yes, with modifications:
1. Replace Firebase Auth with your own auth server
2. Replace Firestore with your database
3. Replace FCM with another push service
4. Requires significant code changes

Not recommended for production without expertise.

---

### Q7: What's the maximum call duration?

**A:**
No built-in limit. Depends on:
- Server resources
- Network bandwidth
- Mobile device battery
- LiveKit subscription tier

For most devices: 4-8 hours possible.

---

### Q8: Can two people use the same account?

**A:**
Technically yes, but not recommended:
- Notifications may route to wrong device
- Call state may get confused
- Better practice: one account per person

---

### Q9: How do I update the app?

**A:**
```bash
# Pull latest code
git pull origin dev

# Update dependencies
flutter pub get

# Rebuild
flutter pub run build_runner build

# Test
flutter run
```

---

### Q10: Is there a web version?

**A:**
Flutter web support is available but not fully tested in this project.

To enable:
```bash
# Create web support
flutter create --platforms web .

# Run web version
flutter run -d web-chrome

# Build for production
flutter build web
```

Requires additional testing for WebRTC support.

---

### Q11: Can I use this for group calls?

**A:**
Current architecture is peer-to-peer (max 2 participants).

For group calls:
1. Modify call creation to support multiple calleeIds
2. Implement SFU (Selective Forwarding Unit) on LiveKit server
3. Update notification logic to handle multiple recipients
4. Modify UI for group call interface

Significant development effort required.

---

### Q12: How do I add more authentication methods?

**A:**
```dart
// In social_auth.dart, add new method:

static Future<UserCredential?> signInWithFacebook({
  required Future<void> Function(User user, String token)? onSuccess,
}) async {
  try {
    // Implementation using flutter_facebook_sdk
    // Follow similar pattern to Google/Apple
  } catch (e) {
    debugPrint("❌ Facebook Sign-In Error: $e");
    return null;
  }
}

// In login.dart, add button:
_PrimaryButton(
  label: 'Sign in with Facebook',
  onPressed: _signInWithFacebook,
  icon: Icons.facebook,
)
```

---

### Q13: How do I implement call history?

**A:**
```dart
// Query Firestore collection
Future<List<CallRecord>> getCallHistory(String userId) async {
  final db = FirebaseFirestore.instance;
  
  final snapshot = await db
    .collection('calls')
    .where('participants', arrayContains: userId)
    .where('status', isEqualTo: 'ended')
    .orderBy('endedAt', descending: true)
    .limit(50)
    .get();
    
  return snapshot.docs
    .map((doc) => CallRecord.fromFirestore(doc))
    .toList();
}

// Display in UI
ListView.builder(
  itemCount: callHistory.length,
  itemBuilder: (context, index) {
    final call = callHistory[index];
    return ListTile(
      title: Text(call.otherUserName),
      subtitle: Text('${call.duration} seconds'),
      trailing: Text(call.formattedDate),
    );
  },
)
```

---

### Q14: How do I implement call recording?

**A:**
LiveKit has built-in recording:
```dart
// On server side, enable recording:
// https://docs.livekit.io/reference/server-apis#recording

// Client receives recording events:
liveKitClient.onRecordingStarted.listen((event) {
  print('Recording started: ${event.roomName}');
});

liveKitClient.onRecordingStopped.listen((event) {
  print('Recording stopped');
});
```

Requires LiveKit server configuration and storage setup.

---

### Q15: How do I add video filters/effects?

**A:**
```dart
// Use livekit_client's capabilities:
// 1. Background blur/replacement
// 2. Face detection
// 3. Custom video processors

import 'package:livekit_client/livekit_client.dart';

// Apply effect before publishing
final videoTrack = localParticipant.videoTrack;
videoTrack?.applyVideoProcessor(
  CustomVideoProcessor(), // Implement custom processor
);

// Or use community packages:
// flutter_video_filters
// vid_processor
```

---

## Getting Help

1. **Check Logs**:
   ```bash
   flutter logs
   firebase functions:log
   ```

2. **Check Documentation**:
   - [System Design](./SYSTEM_DESIGN.md)
   - [Implementation Guide](./IMPLEMENTATION_GUIDE.md)
   - [API Reference](./API_REFERENCE.md)

3. **Debug in Firebase Console**:
   - View auth errors
   - Check Firestore queries
   - Monitor functions
   - View crash reports

4. **Search Issues**:
   - GitHub issues in related repos
   - Stack Overflow with tags: flutter, firebase, livekit

5. **Contact Support**:
   - Firebase: https://firebase.google.com/support
   - LiveKit: https://support.livekit.io
   - Flutter: https://flutter.dev/support

---

## Performance Tips

1. **Reduce App Size**:
   ```bash
   flutter build apk --split-per-abi
   ```

2. **Improve Startup Time**:
   - Lazy load providers
   - Use deferred imports
   - Optimize Firestore queries

3. **Better Battery Life**:
   - Disable video when not in call
   - Use lower quality settings on poor connection
   - Implement background service properly

4. **Reduce Network Usage**:
   - Enable video compression
   - Limit frame rate on poor connection
   - Cache user data locally

---

