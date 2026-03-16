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
exports.onUserDeleted = exports.cleanupOldActivity = exports.resetWeeklyLeaderboards = exports.updateLeaderboard = exports.validateXP = exports.api = exports.listApiKeys = exports.revokeApiKey = exports.generateApiKey = void 0;
const functions = __importStar(require("firebase-functions"));
const admin = __importStar(require("firebase-admin"));
const crypto = __importStar(require("crypto"));
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
// API KEY HELPERS
// ============================================================
function hashKey(rawKey) {
    return crypto.createHash("sha256").update(rawKey).digest("hex");
}
function generateRawKey() {
    const bytes = crypto.randomBytes(32);
    const encoded = bytes
        .toString("base64url")
        .replace(/[^a-zA-Z0-9]/g, "")
        .substring(0, 40);
    return `tg_sk_${encoded}`;
}
async function authenticateApiKey(req) {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer "))
        return null;
    const rawKey = authHeader.substring(7).trim();
    if (!rawKey.startsWith("tg_sk_"))
        return null;
    const hashed = hashKey(rawKey);
    const doc = await db.collection("apiKeys").doc(hashed).get();
    if (!doc.exists)
        return null;
    const data = doc.data();
    doc.ref.update({ lastUsedAt: admin.firestore.FieldValue.serverTimestamp() });
    return data.userId;
}
// ============================================================
// generateApiKey - Callable from the app
// ============================================================
exports.generateApiKey = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }
    const userId = context.auth.uid;
    const label = (data === null || data === void 0 ? void 0 : data.label) || "API Key";
    const existing = await db
        .collection("apiKeys")
        .where("userId", "==", userId)
        .get();
    if (existing.size >= 5) {
        throw new functions.https.HttpsError("resource-exhausted", "Maximum 5 API keys per account");
    }
    const rawKey = generateRawKey();
    const hashed = hashKey(rawKey);
    const prefix = rawKey.substring(0, 12);
    await db.collection("apiKeys").doc(hashed).set({
        userId,
        label,
        prefix,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUsedAt: null,
    });
    return { key: rawKey, prefix, label };
});
// ============================================================
// revokeApiKey - Callable from the app
// ============================================================
exports.revokeApiKey = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }
    const userId = context.auth.uid;
    const prefix = data === null || data === void 0 ? void 0 : data.prefix;
    if (!prefix) {
        throw new functions.https.HttpsError("invalid-argument", "prefix is required");
    }
    const snapshot = await db
        .collection("apiKeys")
        .where("userId", "==", userId)
        .where("prefix", "==", prefix)
        .limit(1)
        .get();
    if (snapshot.empty) {
        throw new functions.https.HttpsError("not-found", "Key not found");
    }
    await snapshot.docs[0].ref.delete();
    return { success: true };
});
// ============================================================
// listApiKeys - Callable from the app
// ============================================================
exports.listApiKeys = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be signed in");
    }
    const userId = context.auth.uid;
    const snapshot = await db
        .collection("apiKeys")
        .where("userId", "==", userId)
        .get();
    return {
        keys: snapshot.docs.map((doc) => {
            var _a, _b, _c, _d, _e, _f;
            const d = doc.data();
            return {
                prefix: d.prefix,
                label: d.label,
                createdAt: ((_c = (_b = (_a = d.createdAt) === null || _a === void 0 ? void 0 : _a.toDate) === null || _b === void 0 ? void 0 : _b.call(_a)) === null || _c === void 0 ? void 0 : _c.toISOString()) || null,
                lastUsedAt: ((_f = (_e = (_d = d.lastUsedAt) === null || _d === void 0 ? void 0 : _d.toDate) === null || _e === void 0 ? void 0 : _e.call(_d)) === null || _f === void 0 ? void 0 : _f.toISOString()) || null,
            };
        }),
    };
});
// ============================================================
// REST API - HTTPS function for external access via API key
// ============================================================
exports.api = functions.https.onRequest(async (req, res) => {
    res.set("Access-Control-Allow-Origin", "*");
    res.set("Access-Control-Allow-Methods", "GET, POST, PATCH, DELETE, OPTIONS");
    res.set("Access-Control-Allow-Headers", "Authorization, Content-Type");
    if (req.method === "OPTIONS") {
        res.status(204).send("");
        return;
    }
    const userId = await authenticateApiKey(req);
    if (!userId) {
        res.status(401).json({ error: "Invalid or missing API key" });
        return;
    }
    const path = req.path.replace(/^\/+|\/+$/g, "");
    const segments = path.split("/");
    const resource = segments[0] || "";
    const resourceId = segments[1] || "";
    try {
        switch (resource) {
            case "profile":
                await handleProfile(req, res, userId);
                break;
            case "tasks":
                await handleTasks(req, res, userId, resourceId);
                break;
            case "groups":
                await handleGroups(req, res, userId, resourceId);
                break;
            case "notes":
                await handleNotes(req, res, userId, resourceId);
                break;
            case "plans":
                await handlePlans(req, res, userId, resourceId);
                break;
            case "reminders":
                await handleReminders(req, res, userId, resourceId);
                break;
            case "activity":
                await handleActivity(req, res, userId, resourceId);
                break;
            default:
                res.status(404).json({ error: `Unknown resource: ${resource}` });
        }
    }
    catch (err) {
        const message = err instanceof Error ? err.message : "Internal error";
        console.error(`API error: ${message}`);
        res.status(500).json({ error: message });
    }
});
// ============================================================
// RESOURCE HANDLERS
// ============================================================
async function handleProfile(req, res, userId) {
    const userRef = db.collection("users").doc(userId);
    if (req.method === "GET") {
        const doc = await userRef.get();
        if (!doc.exists) {
            res.status(404).json({ error: "User not found" });
            return;
        }
        res.json({ id: doc.id, ...doc.data() });
    }
    else if (req.method === "PATCH") {
        const allowed = ["displayName", "username"];
        const updates = {};
        for (const key of allowed) {
            if (req.body[key] !== undefined)
                updates[key] = req.body[key];
        }
        if (Object.keys(updates).length === 0) {
            res.status(400).json({ error: "No valid fields to update" });
            return;
        }
        await userRef.update(updates);
        res.json({ success: true, updated: Object.keys(updates) });
    }
    else {
        res.status(405).json({ error: "Method not allowed" });
    }
}
async function handleTasks(req, res, userId, taskId) {
    const col = db.collection(`users/${userId}/tasks`);
    if (req.method === "GET" && !taskId) {
        const groupId = req.query.groupId;
        let query = col;
        if (groupId)
            query = query.where("groupId", "==", groupId);
        const snap = await query.get();
        res.json({ tasks: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
    }
    else if (req.method === "GET" && taskId) {
        const doc = await col.doc(taskId).get();
        if (!doc.exists) {
            res.status(404).json({ error: "Task not found" });
            return;
        }
        res.json({ id: doc.id, ...doc.data() });
    }
    else if (req.method === "POST") {
        const ref = await col.add({
            ...req.body,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(201).json({ id: ref.id });
    }
    else if (req.method === "PATCH" && taskId) {
        await col.doc(taskId).update(req.body);
        res.json({ success: true });
    }
    else if (req.method === "DELETE" && taskId) {
        await col.doc(taskId).delete();
        res.json({ success: true });
    }
    else {
        res.status(405).json({ error: "Method not allowed" });
    }
}
async function handleGroups(req, res, userId, groupId) {
    const col = db.collection(`users/${userId}/groups`);
    if (req.method === "GET") {
        const snap = await col.orderBy("order").get();
        res.json({ groups: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
    }
    else if (req.method === "POST") {
        const ref = await col.add(req.body);
        res.status(201).json({ id: ref.id });
    }
    else if (req.method === "DELETE" && groupId) {
        await col.doc(groupId).delete();
        res.json({ success: true });
    }
    else {
        res.status(405).json({ error: "Method not allowed" });
    }
}
async function handleNotes(req, res, userId, noteId) {
    const col = db.collection(`users/${userId}/notes`);
    if (req.method === "GET" && !noteId) {
        const date = req.query.date;
        if (date) {
            const doc = await col.doc(date).get();
            if (!doc.exists) {
                res.status(404).json({ error: "Note not found" });
                return;
            }
            res.json({ id: doc.id, ...doc.data() });
        }
        else {
            const snap = await col.orderBy("date", "desc").limit(30).get();
            res.json({ notes: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
        }
    }
    else if (req.method === "POST") {
        const date = req.body.date;
        if (!date) {
            res.status(400).json({ error: "date is required" });
            return;
        }
        await col.doc(date).set({ ...req.body, updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
        res.status(201).json({ id: date });
    }
    else if (req.method === "DELETE" && noteId) {
        await col.doc(noteId).delete();
        res.json({ success: true });
    }
    else {
        res.status(405).json({ error: "Method not allowed" });
    }
}
async function handlePlans(req, res, userId, planId) {
    const col = db.collection(`users/${userId}/plans`);
    if (req.method === "GET" && !planId) {
        const snap = await col.orderBy("createdAt", "desc").get();
        res.json({ plans: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
    }
    else if (req.method === "GET" && planId) {
        const doc = await col.doc(planId).get();
        if (!doc.exists) {
            res.status(404).json({ error: "Plan not found" });
            return;
        }
        res.json({ id: doc.id, ...doc.data() });
    }
    else if (req.method === "POST") {
        const ref = await col.add({
            ...req.body,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        res.status(201).json({ id: ref.id });
    }
    else if (req.method === "PATCH" && planId) {
        await col.doc(planId).update(req.body);
        res.json({ success: true });
    }
    else if (req.method === "DELETE" && planId) {
        await col.doc(planId).delete();
        res.json({ success: true });
    }
    else {
        res.status(405).json({ error: "Method not allowed" });
    }
}
async function handleReminders(req, res, userId, reminderId) {
    const col = db.collection(`users/${userId}/reminders`);
    if (req.method === "GET") {
        const snap = await col.orderBy("scheduledDate").get();
        res.json({ reminders: snap.docs.map((d) => ({ id: d.id, ...d.data() })) });
    }
    else if (req.method === "POST") {
        const ref = await col.add(req.body);
        res.status(201).json({ id: ref.id });
    }
    else if (req.method === "DELETE" && reminderId) {
        await col.doc(reminderId).delete();
        res.json({ success: true });
    }
    else {
        res.status(405).json({ error: "Method not allowed" });
    }
}
async function handleActivity(req, res, userId, subpath) {
    if (req.method !== "GET") {
        res.status(405).json({ error: "Activity is read-only" });
        return;
    }
    const col = db.collection(`users/${userId}/activityDays`);
    if (subpath === "summary") {
        const from = req.query.from;
        const to = req.query.to;
        let query = col;
        if (from)
            query = query.where("date", ">=", new Date(from));
        if (to)
            query = query.where("date", "<=", new Date(to));
        const snap = await query.orderBy("date").get();
        res.json({
            days: snap.docs.map((d) => {
                const data = d.data();
                return {
                    id: d.id,
                    date: data.date,
                    totalActiveMinutes: data.totalActiveMinutes || 0,
                    totalKeyboard: data.totalKeyboard || 0,
                    totalClicks: data.totalClicks || 0,
                    totalScrolls: data.totalScrolls || 0,
                    totalMovement: data.totalMovement || 0,
                    totalInputs: (data.totalKeyboard || 0) +
                        (data.totalClicks || 0) +
                        (data.totalScrolls || 0) +
                        (data.totalMovement || 0),
                };
            }),
        });
    }
    else {
        const date = req.query.date || subpath;
        if (!date) {
            res.status(400).json({ error: "date query param required (YYYY-MM-DD)" });
            return;
        }
        const doc = await col.doc(date).get();
        if (!doc.exists) {
            res.status(404).json({ error: `No activity for ${date}` });
            return;
        }
        res.json({ id: doc.id, ...doc.data() });
    }
}
// ============================================================
// validateXP - Server-side XP validation
// ============================================================
exports.validateXP = functions.https.onCall(async (request) => {
    const data = request.data;
    const auth = request.auth;
    if (!auth) {
        throw new functions.https.HttpsError("unauthenticated", "Must be authenticated to earn XP");
    }
    const userId = auth.uid;
    const { taskId, elapsedMinutes, activityPercentage, totalIntervals, activeIntervals, } = data;
    if (typeof elapsedMinutes !== "number" ||
        elapsedMinutes < 0 ||
        elapsedMinutes > 720) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid elapsed minutes");
    }
    if (typeof activityPercentage !== "number" ||
        activityPercentage < 0 ||
        activityPercentage > 1) {
        throw new functions.https.HttpsError("invalid-argument", "Invalid activity percentage");
    }
    const REQUIRED_ACTIVITY = 0.6;
    const MAX_XP_PER_SESSION = 720;
    if (activityPercentage < REQUIRED_ACTIVITY) {
        return { success: true, xpAwarded: 0, reason: "Activity below threshold" };
    }
    const activeMinutes = Math.floor(elapsedMinutes * activityPercentage);
    const xpToAward = Math.min(activeMinutes, MAX_XP_PER_SESSION);
    if (xpToAward <= 0) {
        return { success: true, xpAwarded: 0, reason: "No XP earned" };
    }
    const result = await db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(userId);
        const userDoc = await transaction.get(userRef);
        if (!userDoc.exists) {
            throw new functions.https.HttpsError("not-found", "User not found");
        }
        const userData = userDoc.data();
        const newTotalXP = (userData.totalXP || 0) + xpToAward;
        const newWeeklyXP = (userData.weeklyXP || 0) + xpToAward;
        const newLevel = levelForXP(newTotalXP);
        transaction.update(userRef, {
            totalXP: newTotalXP,
            weeklyXP: newWeeklyXP,
            level: newLevel,
        });
        return { xpAwarded: xpToAward, newTotalXP, newWeeklyXP, newLevel };
    });
    return { success: true, ...result };
});
// ============================================================
// updateLeaderboard
// ============================================================
exports.updateLeaderboard = functions.firestore
    .document("users/{userId}")
    .onUpdate(async (change, context) => {
    const userId = context.params.userId;
    const before = change.before.data();
    const after = change.after.data();
    if (before.weeklyXP === after.weeklyXP)
        return null;
    const batch = db.batch();
    const groupsSnapshot = await db
        .collectionGroup("members")
        .where(admin.firestore.FieldPath.documentId(), "==", userId)
        .get();
    for (const memberDoc of groupsSnapshot.docs) {
        batch.update(memberDoc.ref, {
            weeklyXP: after.weeklyXP || 0,
            level: after.level || 1,
            displayName: after.displayName || "",
            username: after.username || "",
        });
    }
    if (!groupsSnapshot.empty)
        await batch.commit();
    return null;
});
// ============================================================
// resetWeeklyLeaderboards
// ============================================================
exports.resetWeeklyLeaderboards = functions.pubsub
    .schedule("0 0 * * 1")
    .timeZone("UTC")
    .onRun(async () => {
    const usersSnapshot = await db
        .collection("users")
        .where("weeklyXP", ">", 0)
        .get();
    const userBatch = db.batch();
    for (const userDoc of usersSnapshot.docs) {
        userBatch.update(userDoc.ref, {
            weeklyXP: 0,
            weeklyXPResetDate: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    if (!usersSnapshot.empty)
        await userBatch.commit();
    const membersSnapshot = await db
        .collectionGroup("members")
        .where("weeklyXP", ">", 0)
        .get();
    const BATCH_SIZE = 400;
    let memberBatch = db.batch();
    let count = 0;
    for (const doc of membersSnapshot.docs) {
        memberBatch.update(doc.ref, { weeklyXP: 0 });
        count++;
        if (count % BATCH_SIZE === 0) {
            await memberBatch.commit();
            memberBatch = db.batch();
        }
    }
    if (count % BATCH_SIZE !== 0)
        await memberBatch.commit();
    return null;
});
// ============================================================
// cleanupOldActivity
// ============================================================
exports.cleanupOldActivity = functions.pubsub
    .schedule("0 3 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    const cutoff = new Date();
    cutoff.setFullYear(cutoff.getFullYear() - 1);
    const usersSnapshot = await db.collection("users").get();
    let totalDeleted = 0;
    for (const userDoc of usersSnapshot.docs) {
        const oldDocs = await db
            .collection(`users/${userDoc.id}/activityDays`)
            .where("date", "<", cutoff)
            .limit(500)
            .get();
        if (!oldDocs.empty) {
            const batch = db.batch();
            oldDocs.docs.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
            totalDeleted += oldDocs.size;
        }
    }
    return null;
});
// ============================================================
// onUserDeleted
// ============================================================
exports.onUserDeleted = functions.auth.user().onDelete(async (user) => {
    const userId = user.uid;
    const batch = db.batch();
    await db.collection("users").doc(userId).delete();
    const activityDocs = await db
        .collection(`users/${userId}/activityDays`)
        .limit(500)
        .get();
    for (const doc of activityDocs.docs)
        batch.delete(doc.ref);
    const apiKeyDocs = await db
        .collection("apiKeys")
        .where("userId", "==", userId)
        .get();
    for (const doc of apiKeyDocs.docs)
        batch.delete(doc.ref);
    const usernamesSnapshot = await db
        .collection("usernames")
        .where("userId", "==", userId)
        .get();
    for (const doc of usernamesSnapshot.docs)
        batch.delete(doc.ref);
    const membersSnapshot = await db
        .collectionGroup("members")
        .where(admin.firestore.FieldPath.documentId(), "==", userId)
        .get();
    for (const doc of membersSnapshot.docs)
        batch.delete(doc.ref);
    if (batch)
        await batch.commit();
});
//# sourceMappingURL=index.js.map