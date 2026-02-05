import * as admin from "firebase-admin";
import {
  onDocumentWritten,
  FirestoreEvent,
  Change,
  DocumentSnapshot,
} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {logger} from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// Item interface matching Firestore schema
interface Item {
  itemId: string;
  type: "personal" | "space";
  ownerUid?: string;
  spaceId?: string;
  title: string;
  details?: string;
  isCompleted: boolean;
  completedAt?: admin.firestore.Timestamp;
  createdAt: admin.firestore.Timestamp;
  updatedAt: admin.firestore.Timestamp;
  createdByUid: string;
  updatedByUid: string;
  remindAt?: admin.firestore.Timestamp;
  timezone?: string;
  notifyStatus: "none" | "scheduled" | "sent" | "cancelled";
  notifyJobId?: string;
}

// Space interface
interface Space {
  spaceId: string;
  name: string;
  emoji?: string;
  ownerUid: string;
  members: Record<string, {role: string; joinedAt: admin.firestore.Timestamp}>;
}

// User interface for FCM tokens
interface User {
  uid: string;
  handle: string;
  displayName: string;
  fcmTokens: Record<string, boolean>;
}

/**
 * Trigger: When an item is created or updated
 * Updates notifyStatus based on remindAt field
 */
export const onItemWrite = onDocumentWritten(
  "items/{itemId}",
  async (
    event: FirestoreEvent<Change<DocumentSnapshot> | undefined, {itemId: string}>
  ) => {
    const change = event.data;
    if (!change) return;

    const before = change.before.data() as Item | undefined;
    const after = change.after.data() as Item | undefined;

    // Item was deleted
    if (!after) {
      logger.info(`Item ${event.params.itemId} deleted`);
      return;
    }

    const itemId = event.params.itemId;
    const now = admin.firestore.Timestamp.now();

    // Determine if we need to update notifyStatus
    let newStatus: Item["notifyStatus"] | null = null;

    if (after.remindAt) {
      // Has a reminder time
      if (after.remindAt.toMillis() > now.toMillis()) {
        // Reminder is in the future - schedule it
        if (after.notifyStatus !== "scheduled") {
          newStatus = "scheduled";
        }
      } else {
        // Reminder is in the past
        if (after.notifyStatus === "scheduled") {
          // Leave it for the cron to handle or mark as sent
          logger.info(`Item ${itemId} has past remindAt, leaving for cron`);
        }
      }
    } else {
      // No reminder time
      if (before?.remindAt && after.notifyStatus === "scheduled") {
        // Reminder was removed - cancel
        newStatus = "cancelled";
      } else if (!before?.remindAt) {
        // No change needed
        newStatus = "none";
      }
    }

    // Update status if changed
    if (newStatus && newStatus !== after.notifyStatus) {
      await db.collection("items").doc(itemId).update({
        notifyStatus: newStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      logger.info(`Item ${itemId} notifyStatus updated to ${newStatus}`);
    }
  }
);

/**
 * Scheduled function: Runs every minute to send due reminders
 * Queries items where remindAt <= now AND notifyStatus == "scheduled"
 * Sends FCM notifications to relevant users
 */
export const sendScheduledReminders = onSchedule(
  {
    schedule: "every 1 minutes",
    timeZone: "UTC",
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    // Add 60 second buffer to catch items due in the next minute
    const bufferTime = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + 60000
    );

    logger.info(`Checking for reminders due before ${bufferTime.toDate()}`);

    // Query items that need notifications
    const itemsSnapshot = await db
      .collection("items")
      .where("notifyStatus", "==", "scheduled")
      .where("remindAt", "<=", bufferTime)
      .get();

    if (itemsSnapshot.empty) {
      logger.info("No reminders due");
      return;
    }

    logger.info(`Found ${itemsSnapshot.size} items to notify`);

    // Process each item
    const batch = db.batch();
    const notificationPromises: Promise<void>[] = [];

    for (const doc of itemsSnapshot.docs) {
      const item = doc.data() as Item;

      // Skip completed items
      if (item.isCompleted) {
        batch.update(doc.ref, {
          notifyStatus: "cancelled",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        continue;
      }

      // Send notification based on item type
      if (item.type === "personal" && item.ownerUid) {
        notificationPromises.push(
          sendPersonalNotification(item, item.ownerUid)
        );
      } else if (item.type === "space" && item.spaceId) {
        notificationPromises.push(
          sendSpaceNotification(item, item.spaceId)
        );
      }

      // Mark as sent
      batch.update(doc.ref, {
        notifyStatus: "sent",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Wait for all notifications to be sent
    await Promise.all(notificationPromises);

    // Commit batch update
    await batch.commit();

    logger.info(`Processed ${itemsSnapshot.size} reminders`);
  }
);

/**
 * Send notification to a single user (personal reminder)
 */
async function sendPersonalNotification(
  item: Item,
  userId: string
): Promise<void> {
  const userDoc = await db.collection("users").doc(userId).get();
  if (!userDoc.exists) {
    logger.warn(`User ${userId} not found`);
    return;
  }

  const user = userDoc.data() as User;
  const tokens = Object.keys(user.fcmTokens || {});

  if (tokens.length === 0) {
    logger.warn(`User ${userId} has no FCM tokens`);
    return;
  }

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title: "Reminder",
      body: item.title,
    },
    data: {
      type: "personal",
      itemId: item.itemId,
    },
    android: {
      notification: {
        channelId: "reminders",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    logger.info(
      `Personal notification sent to ${userId}: ` +
      `${response.successCount} success, ${response.failureCount} failed`
    );

    // Remove invalid tokens
    await cleanupInvalidTokens(userId, tokens, response.responses);
  } catch (error) {
    logger.error(`Error sending personal notification: ${error}`);
  }
}

/**
 * Send notification to all members of a space
 */
async function sendSpaceNotification(
  item: Item,
  spaceId: string
): Promise<void> {
  // Get the space document
  const spaceDoc = await db.collection("spaces").doc(spaceId).get();
  if (!spaceDoc.exists) {
    logger.warn(`Space ${spaceId} not found`);
    return;
  }

  const space = spaceDoc.data() as Space;
  const memberIds = Object.keys(space.members || {});

  if (memberIds.length === 0) {
    logger.warn(`Space ${spaceId} has no members`);
    return;
  }

  // Get all member FCM tokens
  const userDocs = await db.getAll(
    ...memberIds.map((uid) => db.collection("users").doc(uid))
  );

  const allTokens: Array<{userId: string; token: string}> = [];

  for (const userDoc of userDocs) {
    if (!userDoc.exists) continue;
    const user = userDoc.data() as User;
    const tokens = Object.keys(user.fcmTokens || {});
    for (const token of tokens) {
      allTokens.push({userId: user.uid, token});
    }
  }

  if (allTokens.length === 0) {
    logger.warn(`No FCM tokens found for space ${spaceId} members`);
    return;
  }

  const tokens = allTokens.map((t) => t.token);

  const message: admin.messaging.MulticastMessage = {
    tokens,
    notification: {
      title: `${space.emoji || ""} ${space.name}`.trim(),
      body: item.title,
    },
    data: {
      type: "space",
      itemId: item.itemId,
      spaceId: spaceId,
      spaceName: space.name,
    },
    android: {
      notification: {
        channelId: "space_reminders",
        priority: "high",
        defaultSound: true,
      },
    },
    apns: {
      payload: {
        aps: {
          sound: "default",
          badge: 1,
        },
      },
    },
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    logger.info(
      `Space notification sent for ${spaceId}: ` +
      `${response.successCount} success, ${response.failureCount} failed`
    );

    // Clean up invalid tokens for each user
    for (let i = 0; i < response.responses.length; i++) {
      if (!response.responses[i].success) {
        const error = response.responses[i].error;
        if (
          error?.code === "messaging/registration-token-not-registered" ||
          error?.code === "messaging/invalid-registration-token"
        ) {
          const {userId, token} = allTokens[i];
          await db.collection("users").doc(userId).update({
            [`fcmTokens.${token}`]: admin.firestore.FieldValue.delete(),
          });
          logger.info(`Removed invalid token for user ${userId}`);
        }
      }
    }
  } catch (error) {
    logger.error(`Error sending space notification: ${error}`);
  }
}

/**
 * Remove invalid FCM tokens from user document
 */
async function cleanupInvalidTokens(
  userId: string,
  tokens: string[],
  responses: admin.messaging.SendResponse[]
): Promise<void> {
  const invalidTokens: string[] = [];

  for (let i = 0; i < responses.length; i++) {
    if (!responses[i].success) {
      const error = responses[i].error;
      if (
        error?.code === "messaging/registration-token-not-registered" ||
        error?.code === "messaging/invalid-registration-token"
      ) {
        invalidTokens.push(tokens[i]);
      }
    }
  }

  if (invalidTokens.length > 0) {
    const updates: Record<string, admin.firestore.FieldValue> = {};
    for (const token of invalidTokens) {
      updates[`fcmTokens.${token}`] = admin.firestore.FieldValue.delete();
    }
    await db.collection("users").doc(userId).update(updates);
    logger.info(`Removed ${invalidTokens.length} invalid tokens for ${userId}`);
  }
}
