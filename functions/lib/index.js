"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.onUserDeleted = exports.resetWeeklyLeaderboards = exports.updateLeaderboard = exports.validateXP = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
admin.initializeApp();
const db = admin.firestore();
// ============================================================
// XP LEVEL SYSTEM (must match client-side XPSystem.swift)
// ============================================================
function xpRequiredForLevel(level) {
    if (level <= 1)
        return 0;
    const n = level - 1;
    return 5 * n * n + 5 * n;
}
function levelForXP(totalXP) {
    let level = 1;
    while (level < 100 && totalXP >= xpRequiredForLevel(level + 1)) {
        level++;
    }
    return level;
}
// ============================================================
// validateXP - Server-side XP validation
// Called by the client after completing a Task Go session.
// Validates activity data and awards XP atomically.
// ============================================================
exports.validateXP = functions.https.onCall(async (request) => {
    const data = request.data;
    const auth = request.auth;
    // Verify authentication
    if (!auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be authenticated to earn XP");
    }
    const userId = auth.uid;
    const { taskId, elapsedMinutes, activityPercentage, totalIntervals, activeIntervals, } = data;
    // Validate input
    if (typeof elapsedMinutes !== "number" ||
        elapsedMinutes < 0 ||
        elapsedMinutes > 720) {
        // Max 12 hours
        throw new functions.https.HttpsError("invalid-argument", "Invalid elapsed minutes");
    }
    if (typeof activityPercentage !== "number" ||
        activityPercentage < 0 ||
        activityPercentage > 1) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid activity percentage");
    }
    // Anti-cheat validations
    const REQUIRED_ACTIVITY = 0.6; // 60% threshold
    const MAX_XP_PER_SESSION = 720; // Max 12 hours = 720 XP
    // Check activity threshold
    if (activityPercentage < REQUIRED_ACTIVITY) {
        return {
            success: true,
            xpAwarded: 0,
            reason: "Activity below threshold",
        };
    }
    // Calculate XP: 1 XP per active minute
    const activeMinutes = Math.floor(elapsedMinutes * activityPercentage);
    const xpToAward = Math.min(activeMinutes, MAX_XP_PER_SESSION);
    if (xpToAward <= 0) {
        return { success: true, xpAwarded: 0, reason: "No XP earned" };
    }
    // Atomic XP update using transaction
    const result = await db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(userId);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found");
        }
        const userData = userDoc.data();
        const currentTotalXP = userData.totalXP || 0;
        const currentWeeklyXP = userData.weeklyXP || 0;
        const newTotalXP = currentTotalXP + xpToAward;
        const newWeeklyXP = currentWeeklyXP + xpToAward;
        const newLevel = levelForXP(newTotalXP);
        transaction.update(userRef, {
            totalXP: newTotalXP,
            weeklyXP: newWeeklyXP,
            level: newLevel,
        });
        return {
            xpAwarded: xpToAward,
            newTotalXP,
            newWeeklyXP,
            newLevel,
        };
    });
    return {
        success: true,
        ...result,
    };
});
// ============================================================
// updateLeaderboard - Triggered on user XP change
// Updates the user's weekly XP in all their social groups
// ============================================================
exports.updateLeaderboard = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const before = change.before.data();
    const after = change.after.data();
    // Only trigger if weeklyXP changed
    if (before.weeklyXP === after.weeklyXP) {
        return null;
    }
    const newWeeklyXP = after.weeklyXP || 0;
    const newLevel = after.level || 1;
    const displayName = after.displayName || "";
    const username = after.username || "";
    // Find all social groups this user is a member of
    const groupsSnapshot = await db.collectionGroup("members")
        .where(admin.firestore.FieldPath.documentId(), "==", userId)
        .get();
    // Batch update all group memberships
    const batch = db.batch();
    for (const memberDoc of groupsSnapshot.docs) {
        // memberDoc.ref is socialGroups/{groupId}/members/{userId}
        batch.update(memberDoc.ref, {
            weeklyXP: newWeeklyXP,
            level: newLevel,
            displayName: displayName,
            username: username,
        });
    }
    if (!groupsSnapshot.empty) {
        await batch.commit();
    }
    return null;
});
// ============================================================
// resetWeeklyLeaderboards - Scheduled weekly reset
// Runs every Monday at midnight UTC
// Resets weeklyXP for all users and all social group members
// ============================================================
exports.resetWeeklyLeaderboards = functions.pubsub
    .schedule("0 0 * * 1") // Every Monday at midnight UTC
    .timeZone("UTC")
    .onRun(async () => {
    console.log("Starting weekly leaderboard reset...");
    // Reset all users' weeklyXP
    const usersSnapshot = await db.collection("users")
        .where("weeklyXP", ">", 0)
        .get();
    const userBatch = db.batch();
    let userCount = 0;
    for (const userDoc of usersSnapshot.docs) {
        userBatch.update(userDoc.ref, {
            weeklyXP: 0,
            weeklyXPResetDate: admin.firestore.FieldValue.serverTimestamp(),
        });
        userCount++;
    }
    if (userCount > 0) {
        await userBatch.commit();
        console.log(`Reset weeklyXP for ${userCount} users`);
    }
    // Reset all social group members' weeklyXP
    const membersSnapshot = await db.collectionGroup("members")
        .where("weeklyXP", ">", 0)
        .get();
    // Firestore batch limit is 500, so chunk if needed
    const BATCH_SIZE = 400;
    let memberBatch = db.batch();
    let memberCount = 0;
    for (const memberDoc of membersSnapshot.docs) {
        memberBatch.update(memberDoc.ref, { weeklyXP: 0 });
        memberCount++;
        if (memberCount % BATCH_SIZE === 0) {
            await memberBatch.commit();
            memberBatch = db.batch();
        }
    }
    if (memberCount % BATCH_SIZE !== 0) {
        await memberBatch.commit();
    }
    console.log(`Reset weeklyXP for ${memberCount} social group memberships`);
    console.log("Weekly leaderboard reset complete!");
    return null;
});
// ============================================================
// onUserDeleted - Clean up when a user deletes their account
// ============================================================
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    console.log(`Cleaning up data for deleted user: ${userId}`);
    // Delete user profile
    await db.collection("users").doc(userId).delete();
    // Delete username reservation
    const usernamesSnapshot = await db.collection("usernames")
        .where("userId", "==", userId)
        .get();
    const batch = db.batch();
    for (const doc of usernamesSnapshot.docs) {
        batch.delete(doc.ref);
    }
    // Remove from all social groups
    const membersSnapshot = await db.collectionGroup("members")
        .where(admin.firestore.FieldPath.documentId(), "==", userId)
        .get();
    for (const doc of membersSnapshot.docs) {
        batch.delete(doc.ref);
    }
    if (!usernamesSnapshot.empty || !membersSnapshot.empty) {
        await batch.commit();
    }
    console.log(`Cleanup complete for user: ${userId}`);
});
//# sourceMappingURL=index.js.map