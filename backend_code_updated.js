const admin = require('firebase-admin');

let inited = false;
const privateKeyBase64 = process.env.FIREBASE_PRIVATE_KEY_BASE64;
const privateKeyString = Buffer.from(privateKeyBase64, 'base64').toString('utf8');
if (!privateKeyBase64) {
    throw new Error('FIREBASE_PRIVATE_KEY_BASE64 environment variable is not defined');
}
// Critical: Restore the proper PEM format by replacing literal '\\n' with actual newlines
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

// NEW: Handler for ending calls (send notification to stop ringing)
exports.endCallHandler = async (event) => {
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

        if (call.callerId !== uid) {
            return { statusCode: 403, headers: cors(), body: JSON.stringify({ error: 'Only caller can notify' }) };
        }

        const userDoc = await db.collection('users').doc(call.calleeId).get();
        const tokensMap = userDoc.exists ? (userDoc.get('fcmTokens') || {}) : {};
        const tokens = Object.keys(tokensMap);
        if (!tokens.length) return { statusCode: 200, headers: cors(), body: JSON.stringify({ status: 'no_tokens' }) };

        await admin.messaging().sendEachForMulticast({
            tokens,
            // notification: { title: 'Incoming call', body: 'Tap to answer' },
            data: {
                type: 'incoming_call',
                callId,
                roomName: call.roomName,
                callerId: call.callerId,
            },
            android: { priority: 'high' },
            apns: {
                headers: { 'apns-priority': '10', 'apns-push-type': 'alert' },
                payload: {
                    aps: {
                        alert: { title: 'Incoming call', body: 'Tap to answer' }, // iOS only
                        sound: 'default',
                        badge: 1,
                        'content-available': 1,// lets iOS wake the app in background (not terminated)
                        category: 'INCOMING_CALL',

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
