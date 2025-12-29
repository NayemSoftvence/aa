# LiveKit Calling App - System Design Document

## Table of Contents
1. [Architecture Overview](#architecture-overview)
2. [System Components](#system-components)
3. [Data Flow Diagrams](#data-flow-diagrams)
4. [Technology Stack](#technology-stack)
5. [Database Schema](#database-schema)
6. [API Endpoints](#api-endpoints)
7. [Authentication Flow](#authentication-flow)
8. [Real-time Communication](#real-time-communication)
9. [Push Notifications](#push-notifications)
10. [Deployment Architecture](#deployment-architecture)

---

## Architecture Overview

This is a **three-tier architecture** system for peer-to-peer video calling:

```
┌─────────────────────────────────────────────────────────────────┐
│                     PRESENTATION LAYER                          │
│  Flutter Mobile App (iOS/Android) - LiveKit Calling App         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ (REST API + WebSockets)
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      APPLICATION LAYER                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │     Netlify Serverless Functions (Node.js)              │  │
│  │  - Token Generation (token.js)                          │  │
│  │  - Notification Management                             │  │
│  │  - Call State Management                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌──────────────────────────────────────────────────────────────────┐
│                      INFRASTRUCTURE LAYER                        │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │   Firebase       │  │   LiveKit        │  │  Firestore   │  │
│  │   Auth           │  │   Server         │  │  Database    │  │
│  │                  │  │                  │  │              │  │
│  │ - Google SignIn  │  │ - Video Routing  │  │ - User Data  │  │
│  │ - Apple SignIn   │  │ - Audio Routing  │  │ - Call Logs  │  │
│  │                  │  │ - Quality Control│  │ - Presence   │  │
│  └──────────────────┘  └──────────────────┘  └──────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  Firebase Cloud Messaging (FCM) - Push Notifications    │  │
│  └──────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────┘
```

---

## System Components

### 1. **Mobile Client (Flutter App)**

**Responsibilities:**
- User authentication (Google/Apple SignIn)
- Local user management
- Call initiation and receiving
- Real-time video/audio streaming via LiveKit
- Push notification handling
- UI/UX for calling interface

**Key Features:**
- Modern Flutter UI with Material Design
- Multi-platform support (iOS/Android)
- Offline capability awareness
- Background execution handling
- Call state management with Provider pattern

---

### 2. **Netlify Serverless Backend**

**Functions:**
- **token.js**: Generates LiveKit access tokens for authenticated users
- **notify.js**: Sends push notifications to call recipients
- **callAccepted.js**: Notifies caller when call is accepted
- **callDeclined.js**: Notifies caller when call is declined
- **endCall.js**: Cleans up call state and notifies peer

**Characteristics:**
- Stateless design (scales horizontally)
- Firebase Admin SDK integration
- Bearer token authentication
- CORS-enabled for client requests
- Environment variable configuration

---

### 3. **Firebase Ecosystem**

#### **Firebase Authentication**
- OAuth 2.0 with Google and Apple
- ID Token generation and validation
- User session management
- Token refresh mechanism

#### **Cloud Firestore**
- Real-time database for call state
- User presence tracking
- Call history logging
- User profile management

#### **Cloud Messaging (FCM)**
- iOS: APNs integration
- Android: GCM integration
- Call notifications with high priority
- Multi-device token management

---

### 4. **LiveKit Server**

**Role:** Real-time communication infrastructure
- Manages media routing
- Handles video/audio transcoding
- Enforces access control via access tokens
- Provides room-based call isolation
- Collects analytics and metrics

---

## Data Flow Diagrams

### Call Initiation Flow

```
┌─────────────────┐                              ┌─────────────────┐
│   Caller App    │                              │  Callee App     │
└────────┬────────┘                              └────────┬────────┘
         │                                                  │
         │ 1. createCall()                                 │
         ├──────────────────────────────────────────────►  │
         │   (callId, roomName, callerId, calleeId)        │
         │                                                  │
         │                          ▼                       │
         │                   ┌──────────────┐              │
         │                   │  Firestore   │              │
         │                   │   DB         │              │
         │                   └──────────────┘              │
         │                          │                      │
         │   2. notify()            │                      │
         │   (FCM Notification)     │                      │
         │   ◄──────────────────────┴──────────────────────┤
         │                                                  │
         │   3. Incoming Call Alert                        │
         │                                    Accept/Decline
         │                                                  │
         │   4. callAccepted()                             │
         │◄──────────────────────────────────────────────  │
         │   (via callAccepted.js)                         │
         │                                                  │
         │   5. getToken()                                 │
         │────────────────────────────────────────────────►│
         │   (Bearer token)                   getToken()   │
         │                                    ◄─────────────┤
         │                          │                      │
         │                          ▼                      │
         │                    ┌──────────────┐             │
         │                    │  LiveKit     │             │
         │                    │  (Room)      │             │
         │                    └──────────────┘             │
         │                          │                      │
         │   6. Join & Stream       │   Join & Stream     │
         │   ─────────────────────► │ ◄──────────────────  │
         │   (WebRTC)               │   (WebRTC)           │
         │                                                  │
         │            Connected - Video Call Active        │
         │   ◄────────────────────────────────────────────►│
```

### Push Notification Flow

```
┌─────────────┐
│   Caller    │
└──────┬──────┘
       │
       │ Call initiated
       │ (callId)
       ▼
┌──────────────────────────────────────────┐
│   Netlify notify.js Function             │
│ - Verify caller identity (ID token)      │
│ - Get callee's FCM tokens from Firestore │
│ - Send via Firebase Cloud Messaging      │
└──────┬───────────────────────────────────┘
       │
       │ Multi-cast Message
       ▼
┌──────────────────────────────────────────┐
│   Firebase Cloud Messaging               │
│ - Route to appropriate platform          │
│ - iOS: APNs                              │
│ - Android: GCM                           │
└──────┬───────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────────────┐
│   Callee Device(s)                          │
│ - Display incoming call notification        │
│ - Play ringtone                             │
│ - Trigger flutter_callkit_incoming          │
│ - Launch app if terminated                  │
└─────────────────────────────────────────────┘
```

---

## Technology Stack

| Layer | Technology | Version | Purpose |
|-------|-----------|---------|---------|
| **Mobile** | Flutter | ^3.0.6 | Cross-platform mobile framework |
| | Dart | >=3.0.6 <4.0.0 | Language |
| **UI Framework** | Material Design | Latest | Design system |
| **State Mgmt** | Provider | ^6.1.5 | State management |
| **Networking** | Dio | ^5.8.0 | HTTP client |
| **Authentication** | Firebase Auth | ^6.1.0 | User auth |
| | Google SignIn | ^6.2.2 | Google OAuth |
| | Sign in with Apple | ^7.0.1 | Apple OAuth |
| **Database** | Cloud Firestore | ^6.0.2 | Real-time DB |
| **Notifications** | Firebase Messaging | ^16.0.2 | Push notifications |
| | flutter_local_notifications | ^19.4.2 | Local notifications |
| | flutter_callkit_incoming | Latest | Native call UI |
| **Real-time Comms** | LiveKit Client | ^2.5.4 | WebRTC client |
| | flutter_webrtc | Latest | WebRTC support |
| **Utilities** | Get | ^4.7.2 | Service locator |
| | get_storage | ^2.1.1 | Local storage |
| | get_it | ^8.0.3 | Dependency injection |
| **Backend** | Node.js | >=18 | Runtime |
| | Firebase Functions | ^7.0.1 | Serverless functions |
| | LiveKit Server SDK | ^2.14.2 | Token generation |
| | Firebase Admin SDK | ^12.7.0 | Admin operations |

---

## Database Schema

### Firestore Collections

#### **users** Collection
```dart
users/{uid}
├── uid: String (document ID)
├── displayName: String
├── photoURL: String
├── email: String
├── lastSeen: Timestamp
├── createdAt: Timestamp
├── updatedAt: Timestamp
├── fcmTokens: Map<String, bool>  // { token: true }
└── status: String                // 'online' | 'offline'
```

#### **calls** Collection
```dart
calls/{callId}
├── callId: String (document ID)
├── callerId: String (uid of caller)
├── calleeId: String (uid of callee)
├── roomName: String (LiveKit room)
├── status: String // 'pending' | 'accepted' | 'rejected' | 'ended'
├── createdAt: Timestamp
├── startedAt: Timestamp
├── endedAt: Timestamp
├── duration: Number (seconds)
└── metadata: Map // Additional call info
```

#### **call_logs** Collection (Optional)
```dart
call_logs/{logId}
├── callId: String (reference to calls)
├── callerId: String
├── calleeId: String
├── status: String
├── duration: Number
├── startTime: Timestamp
├── endTime: Timestamp
└── quality: Map
    ├── videoBitrate: Number
    ├── audioBitrate: Number
    └── latency: Number
```

---

## API Endpoints

All endpoints are hosted on **Netlify Functions** and require Firebase ID Token authentication.

### 1. **Token Generation** 
```
POST /api/functions/token
Content-Type: application/json
Authorization: Bearer {firebaseIdToken}

Request Body:
{
  "callId": "string"
}

Response:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://livekit-server.example.com",
  "roomName": "room_xyz"
}
```

### 2. **Send Notification**
```
POST /api/functions/notify
Content-Type: application/json
Authorization: Bearer {firebaseIdToken}

Request Body:
{
  "callId": "string"
}

Response:
{
  "status": "sent|no_tokens",
  "recipientCount": number
}
```

### 3. **Call Accepted**
```
POST /api/functions/callAccepted
Content-Type: application/json
Authorization: Bearer {firebaseIdToken}

Request Body:
{
  "callId": "string"
}

Response:
{
  "status": "notified|no_tokens"
}
```

### 4. **Call Declined**
```
POST /api/functions/callDeclined
Content-Type: application/json
Authorization: Bearer {firebaseIdToken}

Request Body:
{
  "callId": "string"
}

Response:
{
  "status": "notified|no_tokens"
}
```

### 5. **End Call**
```
POST /api/functions/endCall
Content-Type: application/json
Authorization: Bearer {firebaseIdToken}

Request Body:
{
  "callId": "string"
}

Response:
{
  "status": "ended"
}
```

---

## Authentication Flow

### Google Sign-In Flow

```
1. User taps "Sign in with Google"
   ↓
2. GoogleSignIn SDK opens OAuth dialog
   ↓
3. User grants permissions
   ↓
4. Google returns OAuth credentials
   - accessToken
   - idToken
   ↓
5. Firebase Auth processes credentials
   ↓
6. Firebase Auth SDK creates/signs in user
   ↓
7. Create user document in Firestore
   ├── uid
   ├── displayName
   ├── photoURL
   ├── email
   └── timestamps
   ↓
8. Store Firebase ID Token locally
   ↓
9. Initialize notification token sync
   ↓
10. Navigate to Home Screen
```

### Apple Sign-In Flow

Similar to Google, with platform-specific handling:
- Apple returns `identityToken` (JWT)
- App manages `authorizationCode`
- Leverages existing Firebase Auth integration

### ID Token Usage

All API requests include Bearer token:
```
Authorization: Bearer {firebaseIdToken}
```

The backend verifies using Firebase Admin SDK:
```javascript
const decoded = await admin.auth().verifyIdToken(idToken);
const uid = decoded.uid;
```

---

## Real-time Communication

### LiveKit Integration

**Token Format:**
```
Header: { alg: "HS256", typ: "JWT" }
Payload: {
  iss: "livekit",
  sub: "{userId}",
  iat: timestamp,
  exp: timestamp + 3600,
  grants: {
    canPublish: true,
    canPublishData: true,
    canSubscribe: true,
    room: "{roomName}",
    roomJoin: true
  }
}
```

**Room Structure:**
- One room per call
- Room name: `call_{callId}`
- Maximum 2 participants (peer-to-peer)
- Auto-cleanup when room is empty

**Media Streams:**
- Video: H.264 or VP8 codec
- Audio: Opus codec
- Simulcast for quality adaptation
- Network quality indicators

---

## Push Notifications

### FCM Token Management

**Storage:**
```dart
// In users document
fcmTokens: {
  "device_token_1": true,
  "device_token_2": true,
  // Multiple devices supported
}
```

**Payload Structure (Incoming Call):**
```json
{
  "data": {
    "type": "incoming_call",
    "callId": "call_xyz",
    "roomName": "room_xyz",
    "callerId": "user_123"
  },
  "notification": {
    "title": "Incoming Call",
    "body": "Tap to answer"
  },
  "android": {
    "priority": "high"
  },
  "apns": {
    "headers": {
      "apns-priority": "10",
      "apns-push-type": "alert"
    }
  }
}
```

**Handling:**
- App running in foreground: `onMessage` handler
- App in background: Platform-specific notification
- App terminated: `flutter_callkit_incoming` displays native call UI
- Tapping notification launches app and triggers call accept/decline

---

## Deployment Architecture

### Development Environment

```
Local Machine
├── Flutter App (hot reload)
├── Firebase Emulator (local testing)
└── Netlify CLI (local functions)
```

### Production Environment

```
┌─────────────────────────────────────────────┐
│         Client Distribution                 │
│  ├─ Apple App Store (iOS)                  │
│  └─ Google Play Store (Android)            │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│   Netlify (Serverless Functions)            │
│   ├─ Region: Auto-scaling                  │
│   └─ Environment: Production                │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  Firebase (GCP)                             │
│  ├─ Project: livekit-calling                │
│  ├─ Region: us-central1 (default)          │
│  └─ Services:                              │
│     ├─ Authentication                      │
│     ├─ Cloud Firestore (us-east1)          │
│     ├─ Cloud Messaging                     │
│     └─ Cloud Storage                       │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  External Services                          │
│  ├─ LiveKit Server (Scalable)              │
│  ├─ Google OAuth                           │
│  └─ Apple OAuth                            │
└─────────────────────────────────────────────┘
```

### Environment Variables (Netlify)

```bash
# Firebase
FIREBASE_PROJECT_ID=livekit-calling
FIREBASE_CLIENT_EMAIL=xxx@xxx.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY_BASE64=<base64-encoded-key>

# LiveKit
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret
LIVEKIT_URL=ws://localhost:7880
```

---

## Security Considerations

### 1. **Authentication**
- All endpoints require valid Firebase ID token
- Tokens auto-refresh before expiration
- ID tokens verified server-side

### 2. **Authorization**
- Caller can only join as caller
- Callee can only join after accepting call
- Only call participants can request tokens
- FCM token access restricted to user's own tokens

### 3. **Data Protection**
- Firestore security rules enforce user isolation
- Call data encrypted in transit (HTTPS/WSS)
- Private key stored as environment variables (never in code)
- No sensitive data in client logs

### 4. **API Security**
- CORS properly configured
- Rate limiting recommended (backend level)
- Bearer token validation on every request
- Payload validation for all endpoints

---

## Scalability Considerations

### Horizontal Scaling
- Netlify functions scale automatically
- Firestore handles concurrent reads/writes
- LiveKit supports multi-server deployment
- FCM handles millions of messages

### Performance Optimization
- Token caching on client (1 hour TTL)
- Lazy loading of user lists
- Pagination for call history
- CDN for static assets (images, lottie files)

### Cost Optimization
- Serverless: pay per invocation
- Firestore: on-demand billing recommended
- LiveKit: hosted or self-hosted options
- Media transfer: consider regional servers

---

## Error Handling & Recovery

| Scenario | Handling |
|----------|----------|
| **Network Timeout** | Retry with exponential backoff |
| **Token Expired** | Auto-refresh, retry request |
| **Call Declined** | Clear UI, return to home |
| **WebRTC Connection Failed** | Show error, allow retry |
| **FCM Delivery Failed** | Log and notify caller |
| **Firebase Auth Error** | Log out user, return to login |
| **LiveKit Room Full** | Show "call in progress" error |

---

## Monitoring & Analytics

Recommended metrics to track:
- Call success rate
- Average call duration
- Token generation latency
- FCM delivery rate
- User retention
- Crash reporting (via Firebase Crashlytics)
- Performance monitoring (via Firebase Performance)

---

## References

- [LiveKit Documentation](https://docs.livekit.io/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Documentation](https://flutter.dev/docs)
- [Netlify Functions](https://docs.netlify.com/functions/overview/)

