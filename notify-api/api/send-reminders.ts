import type { VercelRequest, VercelResponse } from '@vercel/node';
import * as admin from 'firebase-admin';

if (!admin.apps.length) {
  const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

const db = admin.firestore();
const messaging = admin.messaging();

const CRON_SECRET = process.env.CRON_SECRET || '';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST' && req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Verify cron secret
  const rawSecret = req.headers['x-cron-secret'] || req.query['secret'];
  const secret = Array.isArray(rawSecret) ? rawSecret[0] : rawSecret;
  if (!CRON_SECRET || secret !== CRON_SECRET) {
    return res.status(401).json({
      error: 'Unauthorized',
      debug: { hasEnv: !!CRON_SECRET, envLength: CRON_SECRET.length, secretReceived: typeof secret, secretLength: String(secret || '').length },
    });
  }

  const now = admin.firestore.Timestamp.now();
  const buffer = admin.firestore.Timestamp.fromMillis(now.toMillis() + 60000);

  try {
    const snapshot = await db
      .collection('items')
      .where('notifyStatus', '==', 'scheduled')
      .where('remindAt', '<=', buffer)
      .get();

    if (snapshot.empty) {
      return res.status(200).json({ processed: 0 });
    }

    const batch = db.batch();
    let sent = 0;

    for (const doc of snapshot.docs) {
      const item = doc.data();

      if (item.isCompleted) {
        batch.update(doc.ref, { notifyStatus: 'cancelled', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
        continue;
      }

      if (item.type === 'personal' && item.ownerUid) {
        await sendToUser(item.ownerUid, 'Reminder', item.title, { type: 'personal', itemId: item.itemId });
        sent++;
      } else if (item.type === 'space' && item.spaceId) {
        const spaceDoc = await db.collection('spaces').doc(item.spaceId).get();
        if (spaceDoc.exists) {
          const space = spaceDoc.data()!;
          const title = `${space.emoji || ''} ${space.name}`.trim();
          const memberIds = Object.keys(space.members || {});
          for (const uid of memberIds) {
            await sendToUser(uid, title, item.title, { type: 'space', itemId: item.itemId, spaceId: item.spaceId });
          }
          sent++;
        }
      }

      batch.update(doc.ref, { notifyStatus: 'sent', updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    }

    await batch.commit();
    return res.status(200).json({ processed: snapshot.size, sent });
  } catch (error) {
    console.error('Error processing reminders:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}

async function sendToUser(uid: string, title: string, body: string, data: Record<string, string>) {
  const userDoc = await db.collection('users').doc(uid).get();
  if (!userDoc.exists) return;

  const tokens = Object.keys(userDoc.data()?.fcmTokens || {});
  if (tokens.length === 0) return;

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: { title, body },
    data,
    android: { notification: { channelId: 'reminders', priority: 'high', defaultSound: true } },
    apns: { payload: { aps: { sound: 'default', badge: 1 } } },
  };

  const response = await messaging.sendEachForMulticast(message);

  // Clean invalid tokens
  for (let i = 0; i < response.responses.length; i++) {
    const err = response.responses[i].error;
    if (err?.code === 'messaging/registration-token-not-registered' || err?.code === 'messaging/invalid-registration-token') {
      await db.collection('users').doc(uid).update({ [`fcmTokens.${tokens[i]}`]: admin.firestore.FieldValue.delete() });
    }
  }
}
