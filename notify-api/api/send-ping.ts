import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as admin from 'firebase-admin';

// Initialize Firebase Admin (singleton)
if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const messaging = admin.messaging();

interface RequestBody {
  toUid: string;
  spaceId: string;
  itemId: string;
  itemTitle: string;
  spaceName: string;
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Verify Firebase ID token
  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing authorization token' });
  }

  const idToken = authHeader.split('Bearer ')[1];
  let fromUid: string;

  try {
    const decoded = await admin.auth().verifyIdToken(idToken);
    fromUid = decoded.uid;
  } catch {
    return res.status(401).json({ error: 'Invalid token' });
  }

  // Parse request body
  const { toUid, spaceId, itemId, itemTitle, spaceName } = req.body as RequestBody;

  if (!toUid || !spaceId || !itemId || !itemTitle) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  try {
    // Get sender's display name
    const senderDoc = await db.collection('users').doc(fromUid).get();
    const senderName = senderDoc.data()?.displayName || 'Someone';

    // Get target user's FCM tokens
    const targetDoc = await db.collection('users').doc(toUid).get();
    if (!targetDoc.exists) {
      return res.status(200).json({ sent: false, reason: 'User not found' });
    }

    const targetData = targetDoc.data();
    const tokens = Object.keys(targetData?.fcmTokens || {});

    if (tokens.length === 0) {
      return res.status(200).json({ sent: false, reason: 'No FCM tokens' });
    }

    // Send FCM notification
    const message: admin.messaging.MulticastMessage = {
      tokens,
      notification: {
        title: `${senderName} nudged you!`,
        body: `About "${itemTitle}" in ${spaceName || 'a space'}`,
      },
      data: {
        type: 'ping',
        itemId,
        spaceId,
        fromUid,
      },
      android: {
        notification: {
          channelId: 'nudges',
          priority: 'high',
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast(message);

    // Clean up invalid tokens
    for (let i = 0; i < response.responses.length; i++) {
      if (!response.responses[i].success) {
        const error = response.responses[i].error;
        if (
          error?.code === 'messaging/registration-token-not-registered' ||
          error?.code === 'messaging/invalid-registration-token'
        ) {
          await db.collection('users').doc(toUid).update({
            [`fcmTokens.${tokens[i]}`]: admin.firestore.FieldValue.delete(),
          });
        }
      }
    }

    return res.status(200).json({
      sent: true,
      successCount: response.successCount,
      failureCount: response.failureCount,
    });
  } catch (error) {
    console.error('Error sending ping notification:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
