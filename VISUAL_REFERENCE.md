# LiveKit Calling App - Visual Reference & Architecture Diagrams

## System Architecture Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                               │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │           Flutter Mobile App (iOS/Android)              │    │
│  │                                                          │    │
│  │  ┌────────────┐ ┌──────────────┐ ┌───────────┐         │    │
│  │  │   Auth     │ │    Home      │ │   Call    │         │    │
│  │  │  Screen    │ │   Screen     │ │  Screen   │         │    │
│  │  └────────────┘ └──────────────┘ └───────────┘         │    │
│  │        │                │                │             │    │
│  │        └────────────────┼────────────────┘             │    │
│  │                         │                              │    │
│  │  ┌──────────────────────▼──────────────────────┐       │    │
│  │  │      Provider State Management            │       │    │
│  │  │   (CallStateProvider, AuthProvider)      │       │    │
│  │  └──────────────────────────────────────────┘       │    │
│  │                                                      │    │
│  │  ┌──────────────────────────────────────────┐       │    │
│  │  │   Service Layer                         │       │    │
│  │  │ - Dio HTTP Client                       │       │    │
│  │  │ - Firebase Auth                         │       │    │
│  │  │ - Cloud Messaging                       │       │    │
│  │  │ - Firestore                             │       │    │
│  │  │ - LiveKit Client                        │       │    │
│  │  └──────────────────────────────────────────┘       │    │
│  └──────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
                              │
                    REST API + WebSockets
                              ▼
┌────────────────────────────────────────────────────────────────────┐
│                     APPLICATION LAYER                             │
│  ┌──────────────────────────────────────────────────────────┐    │
│  │        Netlify Serverless Functions (Node.js)           │    │
│  │                                                          │    │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐    │    │
│  │  │   Token      │ │   Notify     │ │  Call       │    │    │
│  │  │ Generation   │ │ Management   │ │ Management  │    │    │
│  │  └──────────────┘ └──────────────┘ └──────────────┘    │    │
│  │                                                          │    │
│  └──────────────────────────────────────────────────────────┘    │
└────────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼────────────────┐
              ▼               ▼                ▼
┌──────────────────┐ ┌──────────────┐ ┌──────────────┐
│    Firebase      │ │   LiveKit    │ │   Firebase   │
│   Auth & User    │ │   Server     │ │  Cloud Msg   │
│   Firestore DB   │ │   (Signaling │ │   (FCM)      │
│                  │ │   & Media)   │ │              │
└──────────────────┘ └──────────────┘ └──────────────┘
```

---

## Call Flow Sequence Diagram

```
Caller                    Backend                    Firestore         Callee
  │                         │                           │                │
  ├──── POST /token ────────>                           │                │
  │     (get LiveKit token)  │                           │                │
  │<──── token ──────────────┤                           │                │
  │                          │                           │                │
  ├──────────────────────────────── createCall() ───────>                │
  │     (callId, roomName,          │                    │                │
  │      callerId, calleeId)         │                   │                │
  │                          │<──── store call ────────  │                │
  │                          │                           │                │
  │                          │──── queryFCMTokens ───────>                │
  │                          │<──── return tokens ───────│                │
  │                          │                           │                │
  │                          │──── sendMulticast ───────────────────────>  │
  │                          │     (FCM notification)    │                │
  │                          │                           │                │
  │                          │                      [Notification received]
  │                          │                      [Display incoming call]
  │                          │                           │                │
  │                          │                           │<─ Accept ──────┤
  │                          │                           │                │
  │                          │<───────────── updateCall("accepted") ──────┤
  │                          │                           │                │
  │                          │──── notify caller ────────────────────────>│
  │                          │     (call_accepted)       │                │
  │                          │                           │                │
  ├──── POST /token ────────>│                           │                │
  │<──── token ──────────────┤                           │                │
  │                          │                           │                │
  │───────────────────────────────────── Connect to LiveKit ───────────────│
  │                  WebRTC Peer Connection Established
  │<─────────────────── Video & Audio Streams ────────────────────────────>│
  │                          │                           │                │
  │───────────────────────── During Call ──────────────────────────────────│
  │                                                      │                │
  ├──── POST /endCall ──────>│                           │                │
  │                          │                           │                │
  │                          │──── updateCall("ended") ──>                │
  │                          │<──── update ──────────────                 │
  │                          │                           │                │
  │                          │──── notify callee ──────────────────────────>
  │                          │     (call_ended)          │                │
  │                          │                           │                │
  │─────────────────── WebRTC Disconnected ───────────────────────────────>│
```

---

## Authentication Flow

```
User                 App                    Firebase              Google
  │                  │                         │                    │
  ├─ Tap SignIn ───>│                         │                    │
  │                  │                         │                    │
  │                  ├─ GoogleSignIn.signIn ─>│                    │
  │                  │                         ├─ OAuth Dialog ────>│
  │                  │                         │                    │
  │                  │                         │<─ Grant Permission ─┤
  │                  │                         │                    │
  │                  │<─── OAuth Token ───────┤                    │
  │                  │                         │                    │
  │                  ├─ signInWithCredential ─>│                    │
  │                  │<─ UserCredential ──────┤                    │
  │                  │                         │                    │
  │                  ├─ Store ID Token        │                    │
  │                  │                         │                    │
  │                  ├─ Create User Doc ─────>│                    │
  │                  │  (in Firestore)        │                    │
  │                  │                         │                    │
  │                  ├─ Sync FCM Token ──────>│                    │
  │                  │                         │                    │
  │<─ Welcome ──────┤                         │                    │
  │  Navigate Home   │                         │                    │
```

---

## Notification Flow

```
App                 Firestore              Firebase             Device
 │                     │                   Messaging              │
 │                     │                     │                    │
 │ Initiate Call       │                     │                    │
 ├────────────────────>│                     │                    │
 │ (callId, rooms)     │                     │                    │
 │                     │                     │                    │
 │ Get Callee FCM ─────>                     │                    │
 │ Tokens              │                     │                    │
 │                     │<──── return ────────┤                    │
 │                     │                     │                    │
 │ POST /notify ───────────────────────────>│                    │
 │ (with tokens)       │                     │                    │
 │                     │                     │                    │
 │                     │                     ├─ Route ──────────>│
 │                     │                     │  (iOS/Android)     │
 │                     │                     │                    │
 │                     │                     │                    │
 │                     │                     │<─ Notification ───┤
 │                     │                     │  Display           │
 │                     │                     │                    │
 │                     │                     │  (Tap notification) │
 │<───────────────────────── Launch App ────────────────────────│
 │                     │                     │                    │
```

---

## Database Schema

```
users/{uid}
├── uid: string
├── displayName: string
├── photoURL: string
├── email: string
├── status: string ("online" | "offline")
├── lastSeen: timestamp
├── fcmTokens: {
│   "token1": true,
│   "token2": true
│}
├── createdAt: timestamp
└── updatedAt: timestamp

calls/{callId}
├── callId: string
├── callerId: string
├── calleeId: string
├── roomName: string
├── status: string ("pending" | "accepted" | "rejected" | "ended")
├── createdAt: timestamp
├── startedAt: timestamp (if accepted)
├── endedAt: timestamp (if ended)
├── duration: number (seconds)
└── metadata: {...}

call_logs/{logId}
├── callId: string
├── callerId: string
├── calleeId: string
├── duration: number
├── startTime: timestamp
├── endTime: timestamp
└── quality: {
    videoBitrate: number,
    audioBitrate: number,
    latency: number
}
```

---

## API Endpoint Diagram

```
Client App                 Netlify Functions
    │                              │
    ├─ POST /token ───────────────>│ token.js
    │  (callId, Bearer token)      │ - Verify Firebase Token
    │                              │ - Check call participation
    │<──── {token, url, room} ─────┤ - Generate LiveKit JWT
    │                              │ - Return token
    │
    ├─ POST /notify ──────────────>│ notify.js
    │  (callId, Bearer token)      │ - Verify Firebase Token
    │                              │ - Get callee FCM tokens
    │<──── {status} ───────────────┤ - Send via FCM
    │                              │ - Return status
    │
    ├─ POST /callAccepted ────────>│ callAccepted.js
    │  (callId, Bearer token)      │ - Verify Firebase Token
    │                              │ - Get caller FCM tokens
    │<──── {status} ───────────────┤ - Notify caller
    │                              │
    ├─ POST /callDeclined ────────>│ callDeclined.js
    │  (callId, Bearer token)      │ - Verify Firebase Token
    │                              │ - Get caller FCM tokens
    │<──── {status} ───────────────┤ - Notify caller
    │                              │
    ├─ POST /endCall ────────────>│ endCall.js
    │  (callId, Bearer token)      │ - Verify Firebase Token
    │                              │ - Update call status
    │<──── {status} ───────────────┤ - Notify peer
    │                              │

Legend:
→  Request
←  Response
```

---

## Flutter App Navigation Flow

```
┌─────────────────────────────────────┐
│         MyApp (Root)                │
│  - Theme configuration              │
│  - Firebase initialization          │
│  - Navigation routes                │
└──────────────┬──────────────────────┘
               │
               ▼
        ┌─────────────┐
        │   Loading   │ ← Check authentication status
        │   Screen    │
        └──────┬──────┘
               │
        ┌──────▼──────┐
        │   Logged    │
        │   In?       │
        └──┬─────┬────┘
      Yes  │     │  No
          │     │
          ▼     ▼
      ┌───────────────┐      ┌──────────────┐
      │ HomeScreen    │      │ LoginScreen  │
      │               │      │              │
      ├─ User List    │      ├─ Google Sign │
      ├─ Call State   │      ├─ Apple Sign  │
      ├─ Call Screen  │      └──────────────┘
      └───────────────┘


HomeScreen Flow:
┌──────────────────────┐
│   Home Screen        │
├──────────────────────┤
│ - Display Users      │
│ - Filter Online      │
│ - Search             │
└──────┬───────────────┘
       │
       ├─ Tap User ────────> CallScreen
       │                      │
       │                      ├─ Show Incoming
       │                      ├─ Show Outgoing
       │                      ├─ Accept/Decline
       │                      └─ End Call
       │
       ├─ Listen to Calls ──> CallStateProvider
       │                      │
       │                      ├─ Update UI
       │                      └─ Play Sounds
       │
       └─ Listen to Notifications
          │
          ├─ Incoming Call
          ├─ Call Accepted
          └─ Call Ended
```

---

## File Structure with Dependencies

```
main.dart
├── firebase_options.dart
├── loading_screen.dart
│   ├── helpers/di.dart
│   ├── helpers/post_login.dart
│   └── constants/app_constants.dart
├── welcome_screen.dart
├── providers/call_state_provider.dart
│   └── helpers/notification_service.dart
└── features/

features/auth/login.dart
├── helpers/social_auth.dart
│   ├── firebase_auth
│   ├── google_sign_in
│   └── sign_in_with_apple
├── cloud_firestore
└── networks/dio/dio.dart

features/home/presentation/home.dart
├── cloud_firestore
├── firebase_auth
├── flutter_callkit_incoming
├── providers/call_state_provider.dart
└── features/call/
    └── data/livekit_netlify_api.dart
        └── networks/dio/dio.dart

features/call/presentation/call_screen.dart
├── livekit_client
├── flutter_webrtc
└── networks/dio/dio.dart

helpers/notification_service.dart
├── firebase_messaging
├── flutter_local_notifications
├── flutter_callkit_incoming
└── providers/call_state_provider.dart

networks/dio/dio.dart
├── dio
├── firebase_auth
└── networks/endpoints.dart
```

---

## Deployment Architecture

```
Development                    Staging                    Production
┌─────────────────┐        ┌─────────────────┐       ┌─────────────────┐
│  Local Machine  │        │  CI/CD Pipeline │       │  App Stores     │
│  - Flutter      │        │  - GitHub       │       │  - iOS AppStore │
│  - Netlify Dev  │        │  - Tests        │       │  - Google Play  │
│  - Emulator     │        │  - Build        │       │                 │
└────────┬────────┘        └────────┬────────┘       └────────┬────────┘
         │                          │                        │
         └──────────────┬───────────┴────────────────────────┘
                        │
                        ▼
         ┌──────────────────────────────┐
         │  Firebase Project            │
         │  (livekit-calling)           │
         │                              │
         ├─ Authentication              │
         ├─ Cloud Firestore             │
         ├─ Cloud Messaging             │
         └─ Cloud Functions (optional)  │
         
         ┌──────────────────────────────┐
         │  Netlify                     │
         │  - Serverless Functions      │
         │  - Auto-scaling              │
         │  - Environment Variables     │
         └──────────────────────────────┘
         
         ┌──────────────────────────────┐
         │  LiveKit                     │
         │  - Signaling Server          │
         │  - Media Router              │
         │  - Recording (optional)      │
         └──────────────────────────────┘
```

---

## State Management Flow

```
User Interaction
       │
       ▼
┌──────────────────────┐
│   UI Layer           │
│  (Flutter Widgets)   │
└──────┬───────────────┘
       │
       ├─ CallStateProvider
       │  ├─ setIncomingCall()
       │  ├─ setOutgoingCall()
       │  ├─ setCallEnded()
       │  └─ listeners
       │
       └─ NotificationService
          ├─ listenToMessages()
          ├─ handleIncomingCall()
          └─ updateCallState()
       
       ▼
┌──────────────────────┐
│   Service Layer      │
│  (Firebase, DIO)     │
└──────┬───────────────┘
       │
       ├─ FirebaseAuth
       │  └─ Firebase Messaging
       │
       └─ Dio Client
          ├─ POST /token
          ├─ POST /notify
          └─ POST /endCall
       
       ▼
┌──────────────────────┐
│   Backend            │
│  (Netlify Functions) │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│   External Services  │
│  (Firebase, LiveKit) │
└──────────────────────┘
```

---

## Error Handling Flow

```
API Request
    │
    ▼
┌──────────────┐
│  DIO         │
│  Interceptor │
└──┬───────────┘
   │
   ├─ Verify ID Token
   │  │
   │  └─ Expired?
   │     └─ Refresh & Retry
   │
   ├─ Network Error?
   │  └─ Retry with Backoff
   │
   ├─ Auth Error (401)?
   │  └─ Logout User
   │
   ├─ Not Found (404)?
   │  └─ Show Error Message
   │
   └─ Server Error (500)?
      └─ Log & Retry Later

Response Handler
    │
    ├─ Parse JSON
    ├─ Validate Data
    ├─ Update State
    └─ Show Snackbar (if error)
```

---

## Testing Pyramid

```
        ┌─────────────┐
        │   E2E       │
        │   Tests     │  ← Full app flow testing
        └─────────────┘
           (Small)

       ┌─────────────────┐
       │  Integration    │
       │  Tests          │  ← Widget & Service tests
       └─────────────────┘
           (Medium)

   ┌─────────────────────────┐
   │   Unit Tests            │
   │   - Auth functions      │  ← Individual functions
   │   - API calls           │
   │   - State management    │
   └─────────────────────────┘
       (Large - Fast - Frequent)
```

---

## Performance Monitoring

```
┌─────────────────────────────────┐
│   App Performance               │
├─────────────────────────────────┤
│                                 │
│  Startup Time                   │
│  ├─ App Launch        50ms      │
│  ├─ Firebase Init      200ms    │
│  ├─ Notification Init  100ms    │
│  └─ Total             350ms     │
│                                 │
│  Call Initiation                │
│  ├─ Create Call Doc    100ms    │
│  ├─ Send Notification  200ms    │
│  ├─ Get Token          300ms    │
│  └─ Total             600ms     │
│                                 │
│  Memory Usage                   │
│  ├─ App Idle           80MB     │
│  ├─ With Call         150MB     │
│  └─ Peak              200MB     │
│                                 │
│  Network (per call)             │
│  ├─ Signaling          ~1MB     │
│  ├─ Media              1-5MB/s  │
│  └─ (varies by quality)         │
│                                 │
└─────────────────────────────────┘
```

---

## Document Interconnection Map

```
README.md (Start here)
    │
    ├──> QUICK_START.md
    │    └─> "How do I run it?"
    │
    ├──> SYSTEM_DESIGN.md
    │    ├─> "How does it work?"
    │    └─> "What's the architecture?"
    │
    ├──> IMPLEMENTATION_GUIDE.md
    │    ├─> "How do I code?"
    │    └─> "What's in the code?"
    │
    ├──> API_REFERENCE.md
    │    ├─> "How do I use the API?"
    │    └─> Reference from IMPLEMENTATION_GUIDE.md
    │
    ├──> TROUBLESHOOTING.md
    │    ├─> "Why doesn't this work?"
    │    └─> Covers all docs
    │
    ├──> ONBOARDING.md
    │    └─> "How do I get started?"
    │
    └──> This file (Visual Reference)
         └─> "Show me diagrams!"
```

---

## Quick Lookup Table

| I want to... | Read This |
|---|---|
| Run the app | QUICK_START.md |
| Understand the system | SYSTEM_DESIGN.md |
| Write code | IMPLEMENTATION_GUIDE.md |
| Use an API | API_REFERENCE.md |
| Fix a problem | TROUBLESHOOTING.md |
| Get started | ONBOARDING.md |
| See diagrams | This file |

---

**This visual reference complements the other documentation. Use it alongside the detailed guides for a complete understanding of the system.**

