"use strict";

// Што се сменило во патувањето и кому треба известување.
// Чиста логика (без Firebase) — за да може да се тестира.

/** Името на патувањето: своето име, или градовите, или дестинацијата. */
function tripTitle(trip) {
  if (trip && typeof trip.name === "string" && trip.name.trim()) return trip.name.trim();
  const stops = Array.isArray(trip && trip.stops) ? trip.stops : [];
  const names = stops.map((s) => s && s.place && s.place.name).filter(Boolean);
  if (names.length > 1) return names.join(" → ");
  return (trip && trip.destination && trip.destination.name) || "Tripdrobe";
}

function firstName(name) {
  if (typeof name !== "string") return "";
  return name.trim().split(/\s+/)[0] || "";
}

/**
 * Настани за известување.
 * @param before податоците пред промената
 * @param after  податоците по промената
 * @param actorUID кој ја направи промената (null = непознато → нема известувања)
 * @returns [{ uid, type, actor, item }]
 *   type: added | joined | assigned | took | tookFromYou
 */
function computeEvents(before, after, actorUID) {
  if (!before || !after || !actorUID) return [];
  const companions = Array.isArray(after.companions) ? after.companions : [];
  const byId = new Map(companions.filter((c) => c && c.id).map((c) => [c.id, c]));
  const actor = companions.find((c) => c && c.uid === actorUID);
  const actorName = firstName(actor && actor.name);
  if (!actorName) return [];

  const beforeMembers = new Set(Array.isArray(before.memberUIDs) ? before.memberUIDs : []);
  const afterMembers = Array.isArray(after.memberUIDs) ? after.memberUIDs : [];
  const events = [];

  // Нов член што го додал некој друг → „Ана те додаде во патувањето“
  for (const uid of afterMembers) {
    if (!beforeMembers.has(uid) && uid !== actorUID) {
      events.push({ uid, type: "added", actor: actorName });
    }
  }

  // Самиот се приклучил (прифатил покана) → другите членови: „Ана се приклучи“
  if (!beforeMembers.has(actorUID) && afterMembers.includes(actorUID)) {
    for (const uid of afterMembers) {
      if (uid !== actorUID && beforeMembers.has(uid)) {
        events.push({ uid, type: "joined", actor: actorName });
      }
    }
  }

  // Заеднички работи: кој носи
  const was = (before.together && typeof before.together === "object") ? before.together : {};
  const now = (after.together && typeof after.together === "object") ? after.together : {};
  for (const [id, item] of Object.entries(now)) {
    if (!item || !item.assignee) continue;
    const old = was[id];
    if (old && old.assignee === item.assignee) continue;
    const itemName = (typeof item.name === "string" && item.name.trim()) || "";
    if (!itemName) continue;
    const holder = byId.get(item.assignee);
    if (!holder) continue;

    if (holder.uid === actorUID) {
      // Ана сама зеде: од некој друг → нему; од „никој“ → на сите други
      const previous = old && old.assignee ? byId.get(old.assignee) : null;
      if (previous && previous.uid && previous.uid !== actorUID) {
        events.push({ uid: previous.uid, type: "tookFromYou", actor: actorName, item: itemName });
      } else if (old && !previous) {
        for (const uid of afterMembers) {
          if (uid !== actorUID) events.push({ uid, type: "took", actor: actorName, item: itemName });
        }
      }
    } else if (holder.uid) {
      // Ана означи некој друг (со акаунт) да носи
      events.push({ uid: holder.uid, type: "assigned", actor: actorName, item: itemName });
    }
  }
  return events;
}

/** По примач; ако некој добива повеќе од 2 исти (пр. 5 работи одеднаш) — една збирна порака. */
function groupEvents(events) {
  const byUser = new Map();
  for (const ev of events) {
    if (!byUser.has(ev.uid)) byUser.set(ev.uid, []);
    byUser.get(ev.uid).push(ev);
  }
  const result = new Map();
  for (const [uid, list] of byUser) {
    const out = [];
    const byType = new Map();
    for (const ev of list) {
      const key = `${ev.type}|${ev.actor}`;
      if (!byType.has(key)) byType.set(key, []);
      byType.get(key).push(ev);
    }
    for (const group of byType.values()) {
      if (group.length > 2 && group[0].item) {
        out.push({ ...group[0], item: undefined, count: group.length });
      } else {
        out.push(...group);
      }
    }
    result.set(uid, out);
  }
  return result;
}

const TEXTS = {
  added: {
    mk: (e) => `${e.actor} те додаде во патувањето.`,
    en: (e) => `${e.actor} added you to the trip.`
  },
  joined: {
    mk: (e) => `${e.actor} се приклучи на патувањето.`,
    en: (e) => `${e.actor} joined the trip.`
  },
  assigned: {
    mk: (e) => e.count ? `${e.actor} те означи да носиш ${e.count} заеднички работи.` : `${e.actor} те означи да носиш: ${e.item}.`,
    en: (e) => e.count ? `${e.actor} asked you to bring ${e.count} shared items.` : `${e.actor} asked you to bring: ${e.item}.`
  },
  took: {
    mk: (e) => e.count ? `${e.actor} ќе носи ${e.count} заеднички работи.` : `${e.actor} ќе носи: ${e.item}.`,
    en: (e) => e.count ? `${e.actor} will bring ${e.count} shared items.` : `${e.actor} will bring: ${e.item}.`
  },
  tookFromYou: {
    mk: (e) => e.count ? `${e.actor} ќе носи ${e.count} работи наместо тебе.` : `${e.actor} ќе носи наместо тебе: ${e.item}.`,
    en: (e) => e.count ? `${e.actor} will bring ${e.count} items instead of you.` : `${e.actor} will bring ${e.item} instead of you.`
  }
};

function render(event, lang) {
  const texts = TEXTS[event.type];
  if (!texts) return "";
  return (lang === "en" ? texts.en : texts.mk)(event);
}

module.exports = { tripTitle, firstName, computeEvents, groupEvents, render };
