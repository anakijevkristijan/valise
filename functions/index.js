"use strict";

// Tripdrobe — известувања од пријателите (push).
// Кога ќе се смени патување (trips/{id}): додаден во патување, некој се приклучи,
// те означи да носиш нешто од заедничките работи, некој друг ќе носи нешто.

const { onDocumentUpdatedWithAuthContext } = require("firebase-functions/v2/firestore");
const { setGlobalOptions, logger } = require("firebase-functions/v2");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { computeEvents, groupEvents, render, tripTitle } = require("./activity");

initializeApp();
setGlobalOptions({ region: "europe-west1", maxInstances: 10 });

const DEAD_TOKEN = new Set([
  "messaging/registration-token-not-registered",
  "messaging/invalid-registration-token",
  "messaging/invalid-argument"
]);

/** Кој ја направи промената: корисникот од Firebase Auth (ако е член), инаку полето editedBy од апликацијата. */
function actorOf(event, before, after) {
  const members = new Set([...(before.memberUIDs || []), ...(after.memberUIDs || [])]);
  if (event.authId && members.has(event.authId)) return event.authId;
  if (typeof after.editedBy === "string" && members.has(after.editedBy)) return after.editedBy;
  return null;
}

exports.tripActivity = onDocumentUpdatedWithAuthContext("trips/{tripId}", async (event) => {
  const before = event.data && event.data.before && event.data.before.data();
  const after = event.data && event.data.after && event.data.after.data();
  if (!before || !after) return;

  const actorUID = actorOf(event, before, after);
  const events = computeEvents(before, after, actorUID);
  if (events.length === 0) return;

  const tripId = event.params.tripId;
  const title = tripTitle(after);
  const db = getFirestore();

  for (const [uid, list] of groupEvents(events)) {
    const snap = await db.collection("users").doc(uid).get();
    if (!snap.exists) continue;
    const user = snap.data() || {};
    if (user.friendAlerts === false) continue;
    const tokens = Array.isArray(user.fcmTokens) ? user.fcmTokens.filter((t) => typeof t === "string" && t) : [];
    if (tokens.length === 0) continue;
    const lang = user.lang === "en" ? "en" : "mk";

    for (const item of list) {
      const body = render(item, lang);
      if (!body) continue;
      try {
        const response = await getMessaging().sendEachForMulticast({
          tokens,
          notification: { title, body },
          data: { tripID: tripId, type: item.type },
          apns: { payload: { aps: { sound: "default", "thread-id": tripId } } }
        });
        const dead = [];
        response.responses.forEach((r, i) => {
          if (r.error && DEAD_TOKEN.has(r.error.code)) dead.push(tokens[i]);
        });
        if (dead.length > 0) {
          await snap.ref.update({ fcmTokens: FieldValue.arrayRemove(...dead) });
        }
      } catch (error) {
        logger.error("push failed", { uid, type: item.type, error: String(error) });
      }
    }
  }
});
