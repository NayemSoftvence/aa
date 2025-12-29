# LiveKit Calling App - API Reference

## Overview

All API endpoints are hosted on **Netlify Functions** and deployed to `https://{netlify-site}.netlify.app`.

**Base URL**: `https://livekit-netlify-app.netlify.app` (or your custom domain)

**Authentication**: All requests require a valid Firebase ID Token in the Authorization header.

---

## Authentication

### Bearer Token Format
```
Authorization: Bearer {firebaseIdToken}
```

### Obtaining Token
```dart
final user = FirebaseAuth.instance.currentUser;
final token = await user?.getIdToken();
// Automatically refreshes if expired
```

### Token Validation
All endpoints validate the token server-side:
```javascript
const decoded = await admin.auth().verifyIdToken(idToken);
const uid = decoded.uid;
```

---

## API Endpoints

### 1. Generate LiveKit Token

Generate a short-lived access token for joining a LiveKit room.

```
POST /api/functions/token
```

#### Request
```bash
curl -X POST https://livekit-netlify-app.netlify.app/api/functions/token \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "callId": "call_abc123"
  }'
```

#### Request Body
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| callId | string | Yes | Call identifier from Firestore |

#### Response (200 OK)
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "url": "wss://livekit.example.com",
  "roomName": "call_abc123"
}
```

#### Response (Error)
| Code | Message | Reason |
|------|---------|--------|
| 401 | Missing bearer token | No Authorization header |
| 400 | callId required | Missing callId in request |
| 403 | Not a participant | User not in call |
| 404 | Call not found | Invalid callId |
| 412 | Call not accepted yet | Callee joining before accepting |
| 500 | Server error | Internal error |

#### Example (Dart)
```dart
Future<Map<String, dynamic>> getToken(String callId) async {
  final user = FirebaseAuth.instance.currentUser;
  final idToken = await user?.getIdToken();
  
  final response = await Dio().post(
    'https://livekit-netlify-app.netlify.app/api/functions/token',
    data: {'callId': callId},
    options: Options(
      headers: {'Authorization': 'Bearer $idToken'},
    ),
  );
  
  return response.data; // Contains token, url, roomName
}
```

---

### 2. Send Incoming Call Notification

Send push notification to call recipient.

```
POST /api/functions/notify
```

#### Request
```bash
curl -X POST https://livekit-netlify-app.netlify.app/api/functions/notify \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "callId": "call_abc123"
  }'
```

#### Request Body
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| callId | string | Yes | Call identifier from Firestore |

#### Response (200 OK)
```json
{
  "status": "sent",
  "recipientCount": 2
}
```

Or if no tokens available:
```json
{
  "status": "no_tokens"
}
```

#### Response (Error)
| Code | Message | Reason |
|------|---------|--------|
| 401 | Missing bearer token | No Authorization header |
| 400 | callId required | Missing callId in request |
| 403 | Only caller can notify | Non-caller attempting to notify |
| 404 | Call not found | Invalid callId |
| 500 | Server error | Internal error |

#### Notification Payload (Received by User)
```json
{
  "data": {
    "type": "incoming_call",
    "callId": "call_abc123",
    "roomName": "call_abc123",
    "callerId": "user_xyz789"
  }
}
```

#### Example (Dart)
```dart
Future<void> sendCallNotification(String callId) async {
  final user = FirebaseAuth.instance.currentUser;
  final idToken = await user?.getIdToken();
  
  final response = await Dio().post(
    'https://livekit-netlify-app.netlify.app/api/functions/notify',
    data: {'callId': callId},
    options: Options(
      headers: {'Authorization': 'Bearer $idToken'},
    ),
  );
  
  print('Notification sent: ${response.data['status']}');
}
```

---

### 3. Call Accepted Notification

Notify caller that callee accepted the call.

```
POST /api/functions/callAccepted
```

#### Request
```bash
curl -X POST https://livekit-netlify-app.netlify.app/api/functions/callAccepted \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "callId": "call_abc123"
  }'
```

#### Request Body
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| callId | string | Yes | Call identifier |

#### Response (200 OK)
```json
{
  "status": "notified"
}
```

Or if no tokens:
```json
{
  "status": "no_tokens"
}
```

#### Response (Error)
| Code | Message | Reason |
|------|---------|--------|
| 401 | Missing bearer token | No Authorization header |
| 400 | callId required | Missing callId in request |
| 403 | Only callee can accept | Non-callee attempting to accept |
| 404 | Call not found | Invalid callId |
| 500 | Server error | Internal error |

#### Notification Received (by Caller)
```json
{
  "data": {
    "type": "call_accepted",
    "callId": "call_abc123",
    "calleeId": "user_def456"
  }
}
```

#### Example (Dart)
```dart
Future<void> notifyCallAccepted(String callId) async {
  final user = FirebaseAuth.instance.currentUser;
  final idToken = await user?.getIdToken();
  
  await Dio().post(
    'https://livekit-netlify-app.netlify.app/api/functions/callAccepted',
    data: {'callId': callId},
    options: Options(
      headers: {'Authorization': 'Bearer $idToken'},
    ),
  );
}
```

---

### 4. Call Declined Notification

Notify caller that callee declined the call.

```
POST /api/functions/callDeclined
```

#### Request
```bash
curl -X POST https://livekit-netlify-app.netlify.app/api/functions/callDeclined \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "callId": "call_abc123"
  }'
```

#### Request Body
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| callId | string | Yes | Call identifier |

#### Response (200 OK)
```json
{
  "status": "notified"
}
```

#### Response (Error)
| Code | Message | Reason |
|------|---------|--------|
| 401 | Missing bearer token | No Authorization header |
| 400 | callId required | Missing callId in request |
| 403 | Only callee can decline | Non-callee attempting to decline |
| 404 | Call not found | Invalid callId |
| 500 | Server error | Internal error |

#### Notification Received (by Caller)
```json
{
  "data": {
    "type": "call_declined",
    "callId": "call_abc123",
    "calleeId": "user_def456"
  }
}
```

#### Example (Dart)
```dart
Future<void> notifyCallDeclined(String callId) async {
  final user = FirebaseAuth.instance.currentUser;
  final idToken = await user?.getIdToken();
  
  await Dio().post(
    'https://livekit-netlify-app.netlify.app/api/functions/callDeclined',
    data: {'callId': callId},
    options: Options(
      headers: {'Authorization': 'Bearer $idToken'},
    ),
  );
}
```

---

### 5. End Call

End active call and notify peer.

```
POST /api/functions/endCall
```

#### Request
```bash
curl -X POST https://livekit-netlify-app.netlify.app/api/functions/endCall \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "callId": "call_abc123"
  }'
```

#### Request Body
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| callId | string | Yes | Call identifier |

#### Response (200 OK)
```json
{
  "status": "ended",
  "duration": 125
}
```

#### Response (Error)
| Code | Message | Reason |
|------|---------|--------|
| 401 | Missing bearer token | No Authorization header |
| 400 | callId required | Missing callId in request |
| 403 | Not a participant | User not in call |
| 404 | Call not found | Invalid callId |
| 500 | Server error | Internal error |

#### Side Effects
- Updates call status to 'ended' in Firestore
- Records end timestamp and duration
- Notifies other participant
- Cleans up call resources

#### Notification Received (by Peer)
```json
{
  "data": {
    "type": "call_ended",
    "callId": "call_abc123",
    "duration": 125
  }
}
```

#### Example (Dart)
```dart
Future<void> endCall(String callId) async {
  final user = FirebaseAuth.instance.currentUser;
  final idToken = await user?.getIdToken();
  
  final response = await Dio().post(
    'https://livekit-netlify-app.netlify.app/api/functions/endCall',
    data: {'callId': callId},
    options: Options(
      headers: {'Authorization': 'Bearer $idToken'},
    ),
  );
  
  final duration = response.data['duration'];
  print('Call ended after $duration seconds');
}
```

---

## Error Handling

### General Error Response Format
```json
{
  "error": "Error message describing what went wrong"
}
```

### Common HTTP Status Codes
| Code | Meaning |
|------|---------|
| 200 | Success |
| 204 | No Content (CORS preflight) |
| 400 | Bad Request (missing/invalid params) |
| 401 | Unauthorized (invalid token) |
| 403 | Forbidden (permission denied) |
| 404 | Not Found |
| 405 | Method Not Allowed |
| 412 | Precondition Failed (call not in expected state) |
| 500 | Server Error |

### Best Practices
```dart
try {
  final response = await dio.post(url, data: data);
  return response.data;
} on DioException catch (e) {
  switch (e.response?.statusCode) {
    case 401:
      // Handle auth error - refresh token and retry
      break;
    case 403:
      // Handle permission error
      break;
    case 404:
      // Handle not found
      break;
    default:
      // Handle other errors
  }
  rethrow;
}
```

---

## CORS & Headers

### CORS Configuration
All endpoints return proper CORS headers:
```
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: Authorization, Content-Type
```

### Required Headers
```
Content-Type: application/json
Authorization: Bearer {firebaseIdToken}
```

---

## Rate Limiting

Currently not enforced but recommended configuration:
- **10 requests per second** per user
- **100 requests per minute** per user
- **1000 requests per hour** per IP

Implement at Netlify level for production.

---

## Webhook Events (Firestore Realtime)

Listen to call state changes in real-time:

```dart
// Listen to specific call
FirebaseFirestore.instance
  .collection('calls')
  .doc(callId)
  .snapshots()
  .listen((snapshot) {
    final call = snapshot.data();
    final status = call?['status'];
    
    switch (status) {
      case 'pending':
        // Call initiated, waiting for answer
        break;
      case 'accepted':
        // Callee accepted, ready to join
        break;
      case 'rejected':
        // Callee declined
        break;
      case 'ended':
        // Call ended
        break;
    }
  });

// Listen to user presence
FirebaseFirestore.instance
  .collection('users')
  .doc(userId)
  .snapshots()
  .listen((snapshot) {
    final status = snapshot.get('status');
    final lastSeen = snapshot.get('lastSeen');
  });
```

---

## Integration Examples

### Complete Call Flow Example

```dart
class CallManager {
  final _dio = DioSingleton.instance.dio;
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  // 1. Initiate call
  Future<String> initiateCall(String calleeId) async {
    final user = _auth.currentUser!;
    final callId = const Uuid().v4();
    final roomName = 'call_$callId';
    
    // Create call document
    await _db.collection('calls').doc(callId).set({
      'callId': callId,
      'callerId': user.uid,
      'calleeId': calleeId,
      'roomName': roomName,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    // Send notification
    await _sendNotification(callId);
    
    return callId;
  }
  
  // 2. Send notification
  Future<void> _sendNotification(String callId) async {
    final token = await _getIdToken();
    await _dio.post(
      'https://livekit-netlify-app.netlify.app/api/functions/notify',
      data: {'callId': callId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
  
  // 3. Accept call
  Future<void> acceptCall(String callId) async {
    // Update status
    await _db.collection('calls').doc(callId).update({
      'status': 'accepted',
      'startedAt': FieldValue.serverTimestamp(),
    });
    
    // Notify caller
    final token = await _getIdToken();
    await _dio.post(
      'https://livekit-netlify-app.netlify.app/api/functions/callAccepted',
      data: {'callId': callId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    // Get token and join room
    await _joinRoom(callId);
  }
  
  // 4. Join room
  Future<void> _joinRoom(String callId) async {
    final token = await _getIdToken();
    final response = await _dio.post(
      'https://livekit-netlify-app.netlify.app/api/functions/token',
      data: {'callId': callId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    final livekitToken = response.data['token'];
    final url = response.data['url'];
    final roomName = response.data['roomName'];
    
    // Join LiveKit room with token
    await _liveKitClient.connect(url, livekitToken, roomName);
  }
  
  // 5. End call
  Future<void> endCall(String callId) async {
    final token = await _getIdToken();
    await _dio.post(
      'https://livekit-netlify-app.netlify.app/api/functions/endCall',
      data: {'callId': callId},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    
    // Disconnect from LiveKit
    await _liveKitClient.disconnect();
  }
  
  // Helper
  Future<String> _getIdToken() async {
    return (await _auth.currentUser?.getIdToken())!;
  }
}
```

---

## Testing API Endpoints

### Using curl
```bash
# Get token first
TOKEN=$(firebase auth:export --format=json | jq -r '.users[0].customClaims.idToken')

# Test token endpoint
curl -X POST http://localhost:8888/api/functions/token \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"callId":"test-call-123"}'
```

### Using Postman
1. Create new POST request
2. URL: `http://localhost:8888/api/functions/token`
3. Headers tab:
   - Key: `Authorization`
   - Value: `Bearer {firebaseIdToken}`
4. Body (raw JSON):
   ```json
   {
     "callId": "test-call-123"
   }
   ```
5. Click Send

---

## Changelog

### v1.0.0
- Initial API release
- 5 core endpoints
- Firebase authentication
- Real-time Firestore integration

---

## Support

For issues or questions:
1. Check error responses for details
2. Review logs in Firebase Console
3. Check Netlify Function logs
4. Refer to [Implementation Guide](./IMPLEMENTATION_GUIDE.md)

