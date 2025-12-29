# LiveKit Calling App - Implementation Guide

## Table of Contents
1. [Project Setup](#project-setup)
2. [Flutter Application Structure](#flutter-application-structure)
3. [Backend Functions](#backend-functions)
4. [Firebase Configuration](#firebase-configuration)
5. [Development Workflow](#development-workflow)
6. [Building & Deployment](#building--deployment)
7. [Testing Guide](#testing-guide)
8. [Troubleshooting](#troubleshooting)
9. [Code Examples](#code-examples)

---

## Project Setup

### Prerequisites
- **Flutter SDK**: >=3.0.6
- **Dart SDK**: >=3.0.6 <4.0.0
- **Node.js**: >=18 (for Netlify functions)
- **Firebase CLI**: Latest
- **Xcode** (for iOS development)
- **Android Studio** (for Android development)
- **Git**: For version control

### Initial Setup Steps

#### 1. Clone Repository
```bash
git clone <repository-url>
cd calling\ app
```

#### 2. Setup Flutter Application
```bash
cd livekit_calling_app

# Get Flutter dependencies
flutter pub get

# Generate code (for flutter_gen)
flutter pub run build_runner build

# Check setup
flutter doctor
```

#### 3. Setup Backend (Netlify Functions)
```bash
cd ../livekit

# Install Node dependencies
npm install

# Install Netlify CLI globally (if not already installed)
npm install -g netlify-cli
```

#### 4. Firebase Setup
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Select the correct project
firebase use livekit-calling
```

---

## Flutter Application Structure

```
livekit_calling_app/
├── lib/
│   ├── main.dart                          # Entry point
│   ├── firebase_options.dart              # Firebase config
│   ├── loading_screen.dart                # Splash/Loading
│   ├── welcome_screen.dart                # Welcome page
│   │
│   ├── features/                          # Feature modules
│   │   ├── auth/
│   │   │   └── login.dart                 # Login screen
│   │   ├── call/
│   │   │   ├── presentation/
│   │   │   │   └── call_screen.dart
│   │   │   └── data/
│   │   │       └── livekit_netlify_api.dart
│   │   └── home/
│   │       ├── presentation/
│   │       │   └── home.dart              # User list & calling
│   │       └── data/
│   │           └── livekit_netlify_api.dart
│   │
│   ├── common_widgets/                    # Reusable widgets
│   │   ├── call_bar_overlay.dart
│   │   └── ...
│   │
│   ├── providers/                         # Provider state management
│   │   └── call_state_provider.dart       # Call state
│   │
│   ├── helpers/                           # Utility functions
│   │   ├── di.dart                        # Dependency injection
│   │   ├── notification_service.dart      # FCM handling
│   │   ├── social_auth.dart               # OAuth helpers
│   │   ├── post_login.dart                # Post-login actions
│   │   └── ...
│   │
│   ├── networks/                          # Network layer
│   │   ├── dio/
│   │   │   ├── dio.dart                   # Dio singleton
│   │   │   ├── log.dart                   # Request logging
│   │   │   └── endpoints.dart             # API endpoints
│   │   └── ...
│   │
│   ├── constants/
│   │   ├── app_constants.dart             # App-wide constants
│   │   └── ...
│   │
│   └── gen/                               # Generated code
│       └── assets.gen.dart                # Asset references
│
├── pubspec.yaml                           # Dependencies
├── firebase.json                          # Firebase config
├── analysis_options.yaml                  # Lint rules
├── android/                               # Android native code
├── ios/                                   # iOS native code
├── web/                                   # Web support
├── windows/                               # Windows support
├── linux/                                 # Linux support
└── macos/                                 # macOS support
```

### Key Files Explained

#### **main.dart** - Application Entry Point
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase Cloud Messaging handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize local storage
  await GetStorage.init();
  
  // Setup dependency injection
  diSetup();
  
  // Initialize HTTP client
  DioSingleton.instance.create();
  
  // Initialize notifications
  await NotificationService.initialize();

  // Early CallStateProvider initialization for CallKit events
  final callProvider = CallStateProvider();
  NotificationService.registerCallProvider(callProvider);

  runApp(MyApp(callProvider));
}
```

#### **loading_screen.dart** - App Entry & Auth Check
- Checks if user is logged in
- Syncs notification tokens
- Initializes post-login actions
- Routes to Home or Login based on auth state

#### **features/auth/login.dart** - Authentication
- Google SignIn button
- Apple SignIn button (iOS only)
- Firebase Auth integration
- User profile creation in Firestore

#### **features/home/presentation/home.dart** - Main Screen
- Lists online users
- Initiates calls
- Listens to incoming call notifications
- Manages active calls
- Shows call status

#### **providers/call_state_provider.dart** - Call State Management
- Tracks active call state
- Manages call lifecycle
- Coordinates between notification service and UI
- Handles incoming/outgoing call tracking

#### **helpers/notification_service.dart** - Push Notifications
- FCM token registration
- Foreground message handling
- Background message handling (with CallKit)
- Message parsing and routing

---

## Backend Functions

### Directory Structure
```
livekit/netlify/functions/
├── token.js                 # Generate LiveKit tokens
├── notify.js                # Send incoming call notifications
├── callAccepted.js          # Notify caller of acceptance
├── callDeclined.js          # Notify caller of decline
└── endCall.js               # End call and cleanup
```

### Function Specifications

#### **token.js** - Access Token Generation

**Purpose**: Generate short-lived LiveKit access tokens for room access

**Trigger**: POST request from mobile app

```javascript
Handler expects:
- Authorization: Bearer {firebaseIdToken}
- Body: { callId: string }

Returns:
- token: LiveKit JWT token
- url: LiveKit server URL
- roomName: Generated room name
```

**Security**:
- Verifies Firebase ID token
- Validates user is call participant
- Callee only joins if call is accepted
- Enforces 1-hour token TTL

#### **notify.js** - Incoming Call Notification

**Purpose**: Send FCM notification to call recipient

**Trigger**: POST request after call creation

```javascript
Handler expects:
- Authorization: Bearer {firebaseIdToken}
- Body: { callId: string }

Behavior:
- Only caller can send notifications
- Retrieves callee's FCM tokens
- Sends multi-platform message (iOS/Android)
- Sets high priority for immediate delivery
```

#### **callAccepted.js** - Acceptance Notification

**Purpose**: Notify caller that callee accepted the call

**Trigger**: POST request when callee taps "Accept"

```javascript
Handler expects:
- Authorization: Bearer {firebaseIdToken}
- Body: { callId: string }

Behavior:
- Only callee can call this endpoint
- Notifies caller's devices
- Updates call status in Firestore to 'accepted'
```

#### **callDeclined.js** - Decline Notification

**Purpose**: Notify caller of call rejection

**Trigger**: POST request when callee declines call

```javascript
Handler expects:
- Authorization: Bearer {firebaseIdToken}
- Body: { callId: string }

Behavior:
- Notifies caller
- Updates call status to 'rejected'
- Cleans up call document
```

#### **endCall.js** - Call Termination

**Purpose**: End active call and notify peer

**Trigger**: POST request when either participant ends call

```javascript
Handler expects:
- Authorization: Bearer {firebaseIdToken}
- Body: { callId: string }

Behavior:
- Retrieves call document
- Notifies other participant
- Updates call status to 'ended'
- Records end timestamp and duration
```

---

## Firebase Configuration

### Project Structure

**Firebase Project ID**: `livekit-calling`

### Collections & Rules

#### **Firestore Security Rules**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read/write their own document
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
    }

    // Users can read all users (for contact list)
    match /users/{uid} {
      allow read: if request.auth != null;
    }

    // Calls can be read by participants
    match /calls/{callId} {
      allow read: if request.auth.uid in resource.data.participants;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid in resource.data.participants;
    }

    // Call logs for analytics
    match /call_logs/{logId} {
      allow write: if request.auth != null;
      allow read: if request.auth != null;
    }
  }
}
```

### Indexes

Create the following Firestore indexes:

**Collection**: `users`
- Field: `status` (Ascending)
- Field: `lastSeen` (Descending)

**Collection**: `calls`
- Field: `callerId` (Ascending), `status` (Ascending)
- Field: `calleeId` (Ascending), `status` (Ascending)

### Firebase Authentication

**Sign-in Providers**:
- Google (configure OAuth consent screen)
- Apple (configure Apple developer account)

**Email Enumeration Protection**: Disabled (to show helpful error messages)

---

## Development Workflow

### 1. Setting Up Development Environment

#### Firebase Emulator (Local Testing)
```bash
# Install emulator
firebase setup:emulators:firestore

# Start emulator
firebase emulators:start
```

#### Netlify Functions Local Development
```bash
# In livekit/ directory
netlify dev

# This runs local functions at http://localhost:8888
```

#### Flutter Hot Reload
```bash
# In livekit_calling_app/ directory
flutter run
```

### 2. Environment Configuration

#### Firebase Configuration File
**File**: `livekit_calling_app/firebase.json`
```json
{
  "flutter": {
    "platforms": {
      "android": {
        "default": {
          "projectId": "livekit-calling",
          "appId": "1:949138181567:android:4b45e0b60017550b30250a",
          "fileOutput": "android/app/google-services.json"
        }
      },
      "ios": {
        "default": {
          "projectId": "livekit-calling",
          "appId": "1:949138181567:ios:27909bb5dddd3ba330250a",
          "fileOutput": "ios/Runner/GoogleService-Info.plist"
        }
      }
    }
  }
}
```

#### Netlify Environment Variables
**File**: `.env` (netlify/) or via Netlify Dashboard

```bash
# Firebase Admin Configuration
FIREBASE_PROJECT_ID=livekit-calling
FIREBASE_CLIENT_EMAIL=xxx@xxx.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY_BASE64=<base64-encoded-service-account-key>

# LiveKit Configuration
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_URL=ws://localhost:7880
```

### 3. Local Testing Checklist

- [ ] Flutter dependencies installed (`flutter pub get`)
- [ ] Code generation completed (`flutter pub run build_runner build`)
- [ ] Android/iOS setup verified (`flutter doctor`)
- [ ] Firebase emulator running
- [ ] Netlify functions running locally
- [ ] Google OAuth credentials configured
- [ ] Apple SignIn configured (iOS)
- [ ] Push notifications enabled in Firebase

### 4. Daily Development Workflow

```bash
# 1. Start emulator (if using local Firebase)
firebase emulators:start

# 2. Start Netlify functions
cd livekit
netlify dev

# 3. Run Flutter app (in another terminal)
cd ../livekit_calling_app
flutter run

# 4. Use hot reload during development
# Press 'r' to hot reload
# Press 'R' to hot restart
```

---

## Building & Deployment

### Android Build

#### Debug APK
```bash
flutter build apk --debug
# Output: build/app/outputs/apk/debug/app-debug.apk
```

#### Release APK
```bash
flutter build apk --release
# Output: build/app/outputs/apk/release/app-release.apk
```

#### Release Bundle (for Play Store)
```bash
flutter build appbundle
# Output: build/app/outputs/bundle/release/app-release.aab
```

**Key Files**:
- Keystore: `android/app/upload-keystore.jks`
- Key properties: `android/key.properties`

### iOS Build

#### Debug
```bash
flutter build ios --debug
```

#### Release
```bash
flutter build ios --release
```

#### Archive for App Store
```bash
flutter build ipa --release
# Output: build/ios/ipa/livekit_calling_app.ipa
```

### Backend Deployment

#### Deploy to Netlify
```bash
# In livekit/ directory
netlify deploy --prod
```

#### Deploy Specific Function
```bash
netlify deploy --prod --functions ./netlify/functions
```

#### Environment Setup
1. Add environment variables to Netlify dashboard
2. Deploy triggers automatically on Git push

---

## Testing Guide

### Unit Testing

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/auth_test.dart

# Run tests with coverage
flutter test --coverage
```

### Widget Testing

Example test for login screen:
```dart
testWidgets('Login screen renders correctly', (WidgetTester tester) async {
  await tester.pumpWidget(const MyApp());
  
  expect(find.byType(LoginScreen), findsOneWidget);
  expect(find.text('Sign in with Google'), findsOneWidget);
  expect(find.text('Sign in with Apple'), findsWidgets);
});
```

### Integration Testing

```bash
flutter drive \
  --target=test_driver/app.dart \
  --driver=test_driver/app_test.dart
```

### Manual Testing Checklist

**Authentication**:
- [ ] Google SignIn works
- [ ] Apple SignIn works (iOS)
- [ ] User profile created in Firestore
- [ ] FCM token synced

**Calling**:
- [ ] Can see online users
- [ ] Can initiate call
- [ ] Receiver gets notification
- [ ] Can accept/decline call
- [ ] Video/audio streams work
- [ ] Can end call

**Notifications**:
- [ ] Receives notification (app in foreground)
- [ ] Receives notification (app in background)
- [ ] Receives notification (app terminated)
- [ ] Tap notification opens app

---

## Troubleshooting

### Common Issues & Solutions

#### 1. **Flutter: "Error: Unable to generate bytecode"**
```bash
# Solution: Clean and rebuild
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 2. **Firebase: "Permission Denied"**
```bash
# Verify Firestore rules allow your user
# Check Firebase auth state in app logs
# Ensure id token is current
```

#### 3. **LiveKit: "Failed to Connect"**
```bash
# Verify token is valid and not expired
# Check LiveKit server is running
# Verify firewall allows WebRTC ports
# Check LIVEKIT_URL environment variable
```

#### 4. **Notifications: "FCM Token Not Synced"**
```bash
# Ensure permissions granted
# Check Firestore has fcmTokens field for user
# Verify Firebase Messaging initialized
// In notification_service.dart:
await NotificationService.initialize();
```

#### 5. **iOS: "APNs Not Configured"**
```bash
# Steps:
# 1. Go to Apple Developer Console
# 2. Enable push notifications capability
# 3. Create APNs certificate
# 4. Upload to Firebase Console
# 5. Delete and reinstall app
```

#### 6. **Android: "Google Play Services Not Available"**
```bash
# Ensure device has Google Play Store installed
# Update Google Play Services
# Check Android version compatibility
```

#### 7. **Netlify Functions: "404 Not Found"**
```bash
# Verify function files are in netlify/functions/
# Check netlify.toml has correct functions directory
# Ensure environment variables are set
# Test locally: netlify dev
```

### Debug Logs

**Enable Verbose Logging**:
```dart
// In main.dart
if (kDebugMode) {
  print('Debug mode enabled');
}

// In DioSingleton
// Already has Logger() interceptor
```

**Firebase Debug Logs**:
```bash
firebase functions:log
```

**Netlify Function Logs**:
```bash
netlify logs:functions
```

---

## Code Examples

### Example 1: Making a Call

```dart
// In home.dart or call feature
Future<void> initiateCall(String calleeId) async {
  try {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final caller = auth.currentUser!;
    
    // 1. Create call document
    final callId = const Uuid().v4();
    final roomName = 'call_$callId';
    
    await db.collection('calls').doc(callId).set({
      'callId': callId,
      'callerId': caller.uid,
      'calleeId': calleeId,
      'roomName': roomName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // 2. Send notification to callee
    final idToken = await caller.getIdToken();
    await DioSingleton.instance.dio.post(
      '/api/functions/notify',
      data: {'callId': callId},
      options: Options(
        headers: {'Authorization': 'Bearer $idToken'},
      ),
    );
    
    // 3. Navigate to call screen
    Get.to(() => CallScreen(callId: callId));
    
  } catch (e) {
    print('Error initiating call: $e');
    // Show error to user
  }
}
```

### Example 2: Accepting a Call

```dart
// In notification handler or call screen
Future<void> acceptCall(String callId) async {
  try {
    final db = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    
    // 1. Update call status
    await db.collection('calls').doc(callId).update({
      'status': 'accepted',
      'startedAt': FieldValue.serverTimestamp(),
    });
    
    // 2. Notify caller
    final idToken = await auth.currentUser!.getIdToken();
    await DioSingleton.instance.dio.post(
      '/api/functions/callAccepted',
      data: {'callId': callId},
      options: Options(
        headers: {'Authorization': 'Bearer $idToken'},
      ),
    );
    
    // 3. Get LiveKit token
    final tokenResponse = await DioSingleton.instance.dio.post(
      '/api/functions/token',
      data: {'callId': callId},
      options: Options(
        headers: {'Authorization': 'Bearer $idToken'},
      ),
    );
    
    final token = tokenResponse.data['token'];
    final roomName = tokenResponse.data['roomName'];
    
    // 4. Join LiveKit room
    await _joinLiveKitRoom(token, roomName);
    
  } catch (e) {
    print('Error accepting call: $e');
  }
}
```

### Example 3: Handling Incoming Notifications

```dart
// In notification_service.dart
static Future<void> handleMessage(RemoteMessage message) async {
  print('Message received: ${message.data}');
  
  final type = message.data['type'];
  final callId = message.data['callId'];
  
  switch (type) {
    case 'incoming_call':
      await _handleIncomingCall(callId);
      break;
    case 'call_accepted':
      await _handleCallAccepted(callId);
      break;
    case 'call_declined':
      await _handleCallDeclined(callId);
      break;
    case 'call_ended':
      await _handleCallEnded(callId);
      break;
  }
}

static Future<void> _handleIncomingCall(String callId) async {
  // Update call state
  _callProvider?.setIncomingCall(callId);
  
  // Show notification (if not in foreground)
  if (!GetPlatform.isMobile) return;
  
  // For Android/iOS: flutter_callkit_incoming handles it
  // For Web: show custom notification
}
```

### Example 4: Netlify Function - Token Generation

```javascript
// In netlify/functions/token.js
exports.handler = async (event) => {
    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 204, headers: cors() };
    }
    if (event.httpMethod !== 'POST') {
        return { 
            statusCode: 405, 
            headers: cors(), 
            body: 'Method not allowed' 
        };
    }

    try {
        initAdmin();
        
        // Verify Firebase ID token
        const header = event.headers.authorization || '';
        const m = header.match(/^Bearer (.+)$/);
        if (!m) {
            return { 
                statusCode: 401, 
                headers: cors(), 
                body: JSON.stringify({ error: 'Missing bearer token' }) 
            };
        }
        
        const idToken = m[1];
        const decoded = await admin.auth().verifyIdToken(idToken);
        const uid = decoded.uid;
        
        // Get call details
        const body = JSON.parse(event.body || '{}');
        const callId = body.callId;
        if (!callId) {
            return { 
                statusCode: 400, 
                headers: cors(), 
                body: JSON.stringify({ error: 'callId required' }) 
            };
        }
        
        const db = admin.firestore();
        const callSnap = await db.collection('calls').doc(callId).get();
        if (!callSnap.exists) {
            return { 
                statusCode: 404, 
                headers: cors(), 
                body: JSON.stringify({ error: 'Call not found' }) 
            };
        }
        
        const call = callSnap.data();
        
        // Verify user is participant
        if (call.callerId !== uid && call.calleeId !== uid) {
            return { 
                statusCode: 403, 
                headers: cors(), 
                body: JSON.stringify({ error: 'Not a participant' }) 
            };
        }
        
        // Callee must accept before joining
        if (uid === call.calleeId && call.status !== 'accepted') {
            return { 
                statusCode: 412, 
                headers: cors(), 
                body: JSON.stringify({ error: 'Call not accepted yet' }) 
            };
        }
        
        // Get user display name
        const userDoc = await db.collection('users').doc(uid).get();
        const displayName = userDoc.exists 
            ? (userDoc.get('displayName') || uid) 
            : uid;
        
        // Generate LiveKit token
        const at = new AccessToken(
            process.env.LIVEKIT_API_KEY, 
            process.env.LIVEKIT_API_SECRET, 
            {
                identity: uid,
                name: displayName,
                ttl: 60 * 60, // 1 hour
            }
        );
        
        at.addGrant({
            roomJoin: true,
            room: call.roomName,
            canPublish: true,
            canPublishData: true,
            canSubscribe: true,
        });
        
        return {
            statusCode: 200,
            headers: cors(),
            body: JSON.stringify({
                token: await at.toJwt(),
                url: process.env.LIVEKIT_URL,
                roomName: call.roomName,
            }),
        };
        
    } catch (error) {
        console.error('Token generation error:', error);
        return {
            statusCode: 500,
            headers: cors(),
            body: JSON.stringify({ error: error.message }),
        };
    }
};
```

---

## Best Practices

### Code Style
- Follow Dart code style guide (use `dart format`)
- Use meaningful variable names
- Add comments for complex logic
- Keep functions small and focused

### Performance
- Lazy load user lists (pagination)
- Cache tokens before expiration
- Use `const` constructors where possible
- Optimize rebuild using `const` widgets

### Security
- Never hardcode API keys
- Use environment variables
- Validate all user inputs
- Verify ID tokens server-side
- Use HTTPS/WSS for all communications

### Error Handling
- Wrap async calls in try-catch
- Provide user-friendly error messages
- Log errors for debugging
- Implement retry logic for network errors

### Testing
- Write unit tests for business logic
- Test error scenarios
- Test integration points
- Perform manual testing before release

---

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Docs](https://firebase.google.com/docs)
- [LiveKit Docs](https://docs.livekit.io)
- [Dart Effective Dart Guide](https://dart.dev/guides/language/effective-dart)
- [REST API Best Practices](https://restfulapi.net/)

