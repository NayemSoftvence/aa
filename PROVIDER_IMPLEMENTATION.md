# Provider-Based Call State Management Implementation

## Overview

I've implemented a Provider-based state management system for handling call states throughout the app. This solves the timing issues with cold starts and provides a cleaner architecture.

## Files Created/Modified

### 1. **Created: `lib/providers/call_state_provider.dart`**
- Manages call state (idle, ringing, accepted, inCall, ended)
- Stores call information (callId, callerId, roomName)
- Provides methods to handle call lifecycle
- Notifies listeners when state changes

### 2. **Modified: `lib/main.dart`**
- Wrapped the app with `ChangeNotifierProvider<CallStateProvider>`
- Makes the provider available throughout the app

### 3. **Modified: `lib/helpers/notification_service.dart`**
- Added static reference to `CallStateProvider`
- `_showIncomingCall`: Notifies provider when call arrives
- `_acceptCall`: Uses provider to mark call as accepted
- Fallback to old `pendingCallId` if provider not available (background handler)

### 4. **Modified: `lib/loading_screen.dart`**
- Registers provider with NotificationService after init
- Checks provider for pending calls
- Uses `Consumer<CallStateProvider>` to reactively navigate

## How It Works

### Cold Start Flow (App Killed):

1. **User accepts call via CallKit**
   - `_acceptCall` called
   - Provider might be null (app not started yet)
   - Fallback: Sets `pendingCallId`

2. **App starts**
   - Provider is created in `main.dart`
   - `LoadingScreen` initializes

3. **LoadingScreen.loadInitialData()**
   - Registers provider with `NotificationService`
   - Checks `pendingCallId` (fallback)
   - If found: Updates provider with call info
   - Sets state to `accepted`

4. **After setState**
   - `WidgetsBinding.addPostFrameCallback` fires
   - `_checkPendingCall` checks provider
   - If `hasPendingCall` → navigates to CallScreen

5. **Consumer listens**
   - If provider state changes while on HomeScreen
   - Automatically navigates to CallScreen

### Background/Foreground Flow:

1. **Call arrives**
   - `_showIncomingCall` → Updates provider (ringing)
   - Shows CallKit notification

2. **User accepts**
   - `_acceptCall` → Updates provider (accepted)
   - Navigator is ready → navigates immediately

## Required Action

### Add Provider Package

You need to add the `provider` package to your `pubspec.yaml`:

```yaml
dependencies:
  provider: ^6.1.1  # or latest version
```

Then run:
```bash
flutter pub get
```

This will fix the import errors for `package:provider/provider.dart`.

## Advantages

1. **No Race Conditions**: Provider handles state consistently
2. **Reactive**: UI updates automatically when call state changes
3. **Cleaner Code**: No static variables scattered around
4. **Testable**: Provider can be mocked for testing
5. **Fallback**: Still works if provider isn't ready (uses `pendingCallId`)

## Testing

1. **Kill app**
2. **Accept call via CallKit**
3. **Expected logs**:
```
_acceptCall called with callId: xxx
Provider not available, using fallback pendingCallId
Navigator state: null
[LoadingScreen] loadInitialData started
CallStateProvider registered in NotificationService
[LoadingScreen] Found pending call from fallback: xxx
[LoadingScreen] First frame rendered, checking pending call
[LoadingScreen] Checking pending call from provider: callId=xxx, state=accepted
[LoadingScreen] Navigating to CallScreen with callId: xxx
```

4. **App should**: Show loading → Navigate directly to CallScreen

## Future Improvements

- Add call history to provider
- Handle multiple simultaneous calls
- Add call duration tracking
- Integrate with analytics
