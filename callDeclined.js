const admin = require("firebase-admin");

let inited = false;
const privateKeyBase64 = process.env.FIREBASE_PRIVATE_KEY_BASE64;
// Handle both base64 and direct private key cases to be robust, preferring base64 if present like callAccepted
let privateKey;

if (privateKeyBase64) {
    privateKey = Buffer.from(privateKeyBase64, 'base64').toString('utf8').replace(/\\n/g, '\n');
} else if (process.env.FIREBASE_PRIVATE_KEY) {
    privateKey = process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n');
}

function initAdmin() {
    if (inited) return;
    if (!admin.apps.length) {
        if (!privateKey) {
            throw new Error('FIREBASE_PRIVATE_KEY_BASE64 or FIREBASE_PRIVATE_KEY environment variable is missing');
        }
        admin.initializeApp({
            credential: admin.credential.cert({
                projectId: process.env.FIREBASE_PROJECT_ID,
                clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
                privateKey: privateKey,
            }),
        });
    }
    inited = true;
}

function cors() {
    return {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Authorization, Content-Type',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
    };
}

exports.handler = async (event, context) => {
    if (event.httpMethod === "OPTIONS") {
        return { statusCode: 204, headers: cors() };
    }
    if (event.httpMethod !== "POST") {
        return { statusCode: 405, headers: cors(), body: "Method Not Allowed" };
    }

    try {
        initAdmin();
        const db = admin.firestore();
        const fcm = admin.messaging();

        const { callId } = JSON.parse(event.body);

        if (!callId) {
            return { statusCode: 400, headers: cors(), body: "Missing callId" };
        }

        const callDoc = await db.collection("calls").doc(callId).get();
        if (!callDoc.exists) {
            return { statusCode: 404, headers: cors(), body: "Call ignored - doc missing" };
        }

        const data = callDoc.data();
        // Since we are declining (cancelling), we want to notify all participants.
        // Usually, the caller initiates the drop, so we notify the callee to stop ringing.
        // Or if callee declines, we notify caller.
        // Safest approach: Notify everyone in the participants list so their devices updates.

        const participants = data.participants || [];
        const tokensToSend = [];

        for (const uid of participants) {
            const userDoc = await db.collection("users").doc(uid).get();
            if (userDoc.exists) {
                const tokenMap = userDoc.data().fcmTokens || {};
                Object.keys(tokenMap).forEach(t => tokensToSend.push(t));
            }
        }

        if (tokensToSend.length === 0) {
            return { statusCode: 200, headers: cors(), body: "No tokens to notify" };
        }

        // De-duplicate tokens
        const uniqueTokens = [...new Set(tokensToSend)];

        const message = {
            data: {
                type: "call_declined",
                callId: callId,
            },
            android: { priority: "high", ttl: 0 },
            tokens: uniqueTokens,
        };

        const response = await fcm.sendMulticast(message);
        console.log("Sent declined notification:", response.successCount, "success out of", uniqueTokens.length);

        return {
            statusCode: 200,
            headers: cors(),
            body: JSON.stringify({ success: true, sent: response.successCount }),
        };
    } catch (error) {
        console.error("Error sending declined notification:", error);
        // Return debug info to help user fix Env Vars
        const debugInfo = {
            error: error.message,
            projectId: process.env.FIREBASE_PROJECT_ID,
            clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
            hasKey: !!privateKey,
            keyLength: (privateKey || '').length
        };
        return {
            statusCode: 500,
            headers: cors(),
            body: JSON.stringify(debugInfo),
        };
    }
};
