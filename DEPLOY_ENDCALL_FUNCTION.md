# Deploying the endCall Backend Function

## Problem
The app is getting a 404 error because it's trying to call `/.netlify/functions/endCall` which doesn't exist yet.

## Solution
You need to deploy the `endCallHandler` function to Netlify. Here's how:

## Option 1: Separate Function File (Recommended)

1. **Create a new file** in your Netlify functions directory:
   - Path: `netlify/functions/endCall.js` (or wherever your functions are)

2. **Copy this code**:
```javascript
const admin = require('firebase-admin');

let inited = false;
const privateKeyBase64 = process.env.FIREBASE_PRIVATE_KEY_BASE64;
const privateKeyString = Buffer.from(privateKeyBase64, 'base64').toString('utf8');
if (!privateKeyBase64) {
    throw new Error('FIREBASE_PRIVATE_KEY_BASE64 environment variable is not defined');
}
const privateKey = privateKeyString.replace(/\\\\n/g, '\\n');

function initAdmin() {
    if (inited) return;
    admin.initializeApp({
        credential: admin.credential.cert({
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            privateKey: privateKey,
        }),
    });
    inited = true;
}

function cors() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    };
}

exports.handler = async (event) => {
    if (event.httpMethod === 'OPTIONS') {
        return { statusCode: 204, headers: cors() };
    }
    if (event.httpMethod !== 'POST') {
        return { statusCode: 405, headers: cors(), body: 'Method not allowed' };
    }

    try {
        initAdmin();
        const header = event.headers.authorization || event.headers.Authorization || '';
        const m = header.match(/^Bearer (.+)$/);
        if (!m) return { statusCode: 401, headers: cors(), body: JSON.stringify({ error: 'Missing bearer token' }) };

        const idToken = m[1];
        const decoded = await admin.auth().verifyIdToken(idToken);
        const uid = decoded.uid;

        const body = JSON.parse(event.body || '{}');
        const callId = body.callId;
        if (!callId) return { statusCode: 400, headers: cors(), body: JSON.stringify({ error: 'callId required' }) };

        const db = admin.firestore();
        const callSnap = await db.collection('calls').doc(callId).get();
        if (!callSnap.exists) return { statusCode: 404, headers: cors(), body: JSON.stringify({ error: 'Call not found' }) };
        const call = callSnap.data();

        // Determine who to notify (the other person in the call)
        const otherUserId = call.callerId === uid ? call.calleeId : call.callerId;
        
        const userDoc = await db.collection('users').doc(otherUserId).get();
        const tokensMap = userDoc.exists ? (userDoc.get('fcmTokens') || {}) : {};
        const tokens = Object.keys(tokensMap);
        if (!tokens.length) return { statusCode: 200, headers: cors(), body: JSON.stringify({ status: 'no_tokens' }) };

        // Send "call_ended" notification to stop ringing
        await admin.messaging().sendEachForMulticast({
            tokens,
            data: {
                type: 'call_ended',
                callId,
            },
            android: { priority: 'high' },
            apns: {
                headers: { 'apns-priority': '10', 'apns-push-type': 'background' },
                payload: {
                    aps: {
                        'content-available': 1,
                    }
                }
            },
        });

        return { statusCode: 200, headers: cors(), body: JSON.stringify({ status: 'ok' }) };

    } catch (e) {
        console.error(e);
        return { statusCode: 500, headers: cors(), body: JSON.stringify({ error: e.message || 'server_error' }) };
    }
};
```

3. **Deploy to Netlify**:
   - Commit and push your code
   - Or use Netlify CLI: `netlify deploy --prod`

## Option 2: Add to Existing Functions File

If you have all functions in one file, you can export multiple handlers. Check Netlify's documentation on how to do this.

## After Deploying

1. **Test the endpoint**:
   - Try making a call
   - Hang up
   - Should not see 404 error anymore

2. **Uncomment the code** in `lib/features/call/call_screen.dart`:
```dart
// Change this:
// TODO: Uncomment after deploying endCall function to Netlify
// LivekitNetlifyApi.instance
//     .notifyCallEnded(widget.callId)
//     .catchError((_) => false);

// To this:
// Notify the other user to stop ringing
LivekitNetlifyApi.instance
    .notifyCallEnded(widget.callId)
    .catchError((_) => false);
```

## What This Function Does

When someone hangs up a call, it:
1. Sends an FCM notification to the other user
2. The notification has `type: 'call_ended'`
3. The receiver's app will stop ringing and dismiss CallKit

## Note

For now, I've commented out the call to this function in the app so you won't see the 404 error. The app will still work, but the receiver might keep ringing for a bit longer after you hang up until they see the Firestore status change.
