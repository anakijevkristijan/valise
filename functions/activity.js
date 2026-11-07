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

// Текстовите на сите 13 јазици на апликацијата. {a} = кој, {i} = работа, {n} = колку работи.
// Клучот со „N“ е збирната порака (повеќе од 2 работи одеднаш).
const TEXTS = {
  mk: {
    added: "{a} те додаде во патувањето.",
    joined: "{a} се приклучи на патувањето.",
    assigned: "{a} те означи да носиш: {i}.",
    assignedN: "{a} те означи да носиш {n} заеднички работи.",
    took: "{a} ќе носи: {i}.",
    tookN: "{a} ќе носи {n} заеднички работи.",
    tookFromYou: "{a} ќе носи наместо тебе: {i}.",
    tookFromYouN: "{a} ќе носи {n} работи наместо тебе."
  },
  en: {
    added: "{a} added you to the trip.",
    joined: "{a} joined the trip.",
    assigned: "{a} asked you to bring: {i}.",
    assignedN: "{a} asked you to bring {n} shared items.",
    took: "{a} will bring: {i}.",
    tookN: "{a} will bring {n} shared items.",
    tookFromYou: "{a} will bring {i} instead of you.",
    tookFromYouN: "{a} will bring {n} items instead of you."
  },
  sq: {
    added: "{a} të shtoi në udhëtim.",
    joined: "{a} u bashkua me udhëtimin.",
    assigned: "{a} të kërkoi të marrësh: {i}.",
    assignedN: "{a} të kërkoi të marrësh {n} gjëra të përbashkëta.",
    took: "{a} do të marrë: {i}.",
    tookN: "{a} do të marrë {n} gjëra të përbashkëta.",
    tookFromYou: "{a} do të marrë në vendin tënd: {i}.",
    tookFromYouN: "{a} do të marrë {n} gjëra në vendin tënd."
  },
  sr: {
    added: "{a} te dodaje na putovanje.",
    joined: "{a} se pridružuje putovanju.",
    assigned: "{a} te moli da poneseš: {i}.",
    assignedN: "{a} te moli da poneseš {n} zajedničkih stvari.",
    took: "{a} nosi: {i}.",
    tookN: "{a} nosi {n} zajedničkih stvari.",
    tookFromYou: "{a} nosi umesto tebe: {i}.",
    tookFromYouN: "{a} nosi {n} stvari umesto tebe."
  },
  bg: {
    added: "{a} те добави към пътуването.",
    joined: "{a} се присъедини към пътуването.",
    assigned: "{a} те помоли да вземеш: {i}.",
    assignedN: "{a} те помоли да вземеш {n} общи неща.",
    took: "{a} ще вземе: {i}.",
    tookN: "{a} ще вземе {n} общи неща.",
    tookFromYou: "{a} ще вземе вместо теб: {i}.",
    tookFromYouN: "{a} ще вземе {n} неща вместо теб."
  },
  el: {
    added: "{a} σε πρόσθεσε στο ταξίδι.",
    joined: "{a} μπήκε στο ταξίδι.",
    assigned: "{a} σου ζήτησε να φέρεις: {i}.",
    assignedN: "{a} σου ζήτησε να φέρεις {n} κοινά πράγματα.",
    took: "{a} θα φέρει: {i}.",
    tookN: "{a} θα φέρει {n} κοινά πράγματα.",
    tookFromYou: "{a} θα φέρει αντί για σένα: {i}.",
    tookFromYouN: "{a} θα φέρει {n} πράγματα αντί για σένα."
  },
  tr: {
    added: "{a} seni seyahate ekledi.",
    joined: "{a} seyahate katıldı.",
    assigned: "{a} getirmeni istedi: {i}.",
    assignedN: "{a} {n} ortak şeyi getirmeni istedi.",
    took: "{a} getirecek: {i}.",
    tookN: "{a} {n} ortak şeyi getirecek.",
    tookFromYou: "{a} senin yerine getirecek: {i}.",
    tookFromYouN: "{a} senin yerine {n} şey getirecek."
  },
  de: {
    added: "{a} hat dich zur Reise hinzugefügt.",
    joined: "{a} ist der Reise beigetreten.",
    assigned: "{a} bittet dich mitzubringen: {i}.",
    assignedN: "{a} bittet dich, {n} gemeinsame Sachen mitzubringen.",
    took: "{a} bringt mit: {i}.",
    tookN: "{a} bringt {n} gemeinsame Sachen mit.",
    tookFromYou: "{a} bringt statt dir mit: {i}.",
    tookFromYouN: "{a} bringt {n} Sachen statt dir mit."
  },
  fr: {
    added: "{a} t'ajoute au voyage.",
    joined: "{a} a rejoint le voyage.",
    assigned: "{a} te demande d'apporter : {i}.",
    assignedN: "{a} te demande d'apporter {n} choses en commun.",
    took: "{a} apportera : {i}.",
    tookN: "{a} apportera {n} choses en commun.",
    tookFromYou: "{a} apportera à ta place : {i}.",
    tookFromYouN: "{a} apportera {n} choses à ta place."
  },
  es: {
    added: "{a} te ha añadido al viaje.",
    joined: "{a} se ha unido al viaje.",
    assigned: "{a} te pide que lleves: {i}.",
    assignedN: "{a} te pide que lleves {n} cosas compartidas.",
    took: "{a} llevará: {i}.",
    tookN: "{a} llevará {n} cosas compartidas.",
    tookFromYou: "{a} llevará en tu lugar: {i}.",
    tookFromYouN: "{a} llevará {n} cosas en tu lugar."
  },
  it: {
    added: "{a} ti ha aggiunto al viaggio.",
    joined: "{a} ora fa parte del viaggio.",
    assigned: "{a} ti chiede di portare: {i}.",
    assignedN: "{a} ti chiede di portare {n} cose in comune.",
    took: "{a} porterà: {i}.",
    tookN: "{a} porterà {n} cose in comune.",
    tookFromYou: "{a} porterà al posto tuo: {i}.",
    tookFromYouN: "{a} porterà {n} cose al posto tuo."
  },
  pl: {
    added: "{a} dodaje cię do podróży.",
    joined: "{a} dołącza do podróży.",
    assigned: "{a} prosi cię o zabranie: {i}.",
    assignedN: "{a} prosi cię o zabranie {n} wspólnych rzeczy.",
    took: "{a} zabierze: {i}.",
    tookN: "{a} zabierze {n} wspólnych rzeczy.",
    tookFromYou: "{a} zabierze zamiast ciebie: {i}.",
    tookFromYouN: "{a} zabierze {n} rzeczy zamiast ciebie."
  },
  pt: {
    added: "{a} te adicionou à viagem.",
    joined: "{a} entrou na viagem.",
    assigned: "{a} pediu para você levar: {i}.",
    assignedN: "{a} pediu para você levar {n} itens compartilhados.",
    took: "{a} vai levar: {i}.",
    tookN: "{a} vai levar {n} itens compartilhados.",
    tookFromYou: "{a} vai levar no seu lugar: {i}.",
    tookFromYouN: "{a} vai levar {n} itens no seu lugar."
  }
};

/** Јазикот на корисникот; непознат → англиски. */
function language(lang) {
  return (typeof lang === "string" && TEXTS[lang]) ? lang : "en";
}

function fill(template, values) {
  let out = template;
  for (const [key, value] of Object.entries(values)) {
    out = out.split(`{${key}}`).join(String(value));
  }
  return out;
}

function render(event, lang) {
  if (!event || !TEXTS.en[event.type]) return "";
  const key = event.count ? `${event.type}N` : event.type;
  const template = TEXTS[language(lang)][key] || TEXTS.en[key];
  return fill(template, { a: event.actor || "", i: event.item || "", n: event.count || 0 });
}

module.exports = { tripTitle, firstName, computeEvents, groupEvents, render, language };
