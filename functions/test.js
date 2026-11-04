"use strict";
// Брза проверка на логиката: node test.js
const assert = require("assert");
const { computeEvents, groupEvents, render, tripTitle } = require("./activity");

const ana = { id: "c-ana", name: "Ана Петрова", uid: "u-ana" };
const ivan = { id: "c-ivan", name: "Иван", uid: "u-ivan" };
const mila = { id: "c-mila", name: "Мила", uid: "u-mila" };
const guest = { id: "c-guest", name: "Гоце" }; // без акаунт

const base = {
  destination: { name: "Рим" },
  memberUIDs: ["u-ana", "u-ivan"],
  companions: [ana, ivan, guest],
  together: {
    umbrella: { name: "Чадор", assignee: null },
    hairdryer: { name: "Фен", assignee: "c-ivan" },
    towel: { name: "Пешкир", assignee: "c-ana" }
  }
};
const clone = (o) => JSON.parse(JSON.stringify(o));

// 1. Ана го додава Мила (постоечки акаунт)
let after = clone(base);
after.memberUIDs.push("u-mila");
after.companions.push(mila);
let ev = computeEvents(base, after, "u-ana");
assert.deepStrictEqual(ev, [{ uid: "u-mila", type: "added", actor: "Ана" }]);
assert.strictEqual(render(ev[0], "mk"), "Ана те додаде во патувањето.");

// 2. Мила самата се приклучува (прифаќа покана) → Ана и Иван
const before2 = clone(base); before2.companions.push({ id: "c-mila", name: "Мила", inviteKey: "p_x" });
after = clone(base);
after.memberUIDs.push("u-mila");
after.companions.push(mila);
ev = computeEvents(before2, after, "u-mila");
assert.deepStrictEqual(ev.map((e) => [e.uid, e.type]), [["u-ana", "joined"], ["u-ivan", "joined"]]);

// 3. Ана го означува Иван за чадорот → Иван
after = clone(base);
after.together.umbrella.assignee = "c-ivan";
ev = computeEvents(base, after, "u-ana");
assert.deepStrictEqual(ev, [{ uid: "u-ivan", type: "assigned", actor: "Ана", item: "Чадор" }]);
assert.strictEqual(render(ev[0], "mk"), "Ана те означи да носиш: Чадор.");
assert.strictEqual(render(ev[0], "en"), "Ана asked you to bring: Чадор.");

// 4. Ана самата го зема фенот (беше на Иван) → само Иван
after = clone(base);
after.together.hairdryer.assignee = "c-ana";
ev = computeEvents(base, after, "u-ana");
assert.deepStrictEqual(ev, [{ uid: "u-ivan", type: "tookFromYou", actor: "Ана", item: "Фен" }]);

// 5. Ана зема нешто што немаше никој → сите други
after = clone(base);
after.together.umbrella.assignee = "c-ana";
ev = computeEvents(base, after, "u-ana");
assert.deepStrictEqual(ev, [{ uid: "u-ivan", type: "took", actor: "Ана", item: "Чадор" }]);

// 6. Означен гостин без акаунт → ништо
after = clone(base);
after.together.umbrella.assignee = "c-guest";
assert.deepStrictEqual(computeEvents(base, after, "u-ana"), []);

// 7. Непознат автор → ништо
after = clone(base);
after.together.umbrella.assignee = "c-ivan";
assert.deepStrictEqual(computeEvents(base, after, null), []);

// 8. Ништо не се сменило (само спакувано) → ништо
after = clone(base);
after.together.towel.isPacked = true;
assert.deepStrictEqual(computeEvents(base, after, "u-ana"), []);

// 9. Ана означува 4 работи за Иван одеднаш → една збирна порака
const many = clone(base);
many.together = {};
const manyAfter = clone(base);
manyAfter.together = {};
for (let i = 0; i < 4; i++) {
  many.together["i" + i] = { name: "Работа " + i, assignee: null };
  manyAfter.together["i" + i] = { name: "Работа " + i, assignee: "c-ivan" };
}
const grouped = groupEvents(computeEvents(many, manyAfter, "u-ana"));
assert.strictEqual(grouped.get("u-ivan").length, 1);
assert.strictEqual(render(grouped.get("u-ivan")[0], "mk"), "Ана те означи да носиш 4 заеднички работи.");

// 10. Нова заедничка работа веднаш означена за Иван
after = clone(base);
after.together.adapter = { name: "Адаптер", assignee: "c-ivan" };
ev = computeEvents(base, after, "u-ana");
assert.deepStrictEqual(ev, [{ uid: "u-ivan", type: "assigned", actor: "Ана", item: "Адаптер" }]);

// Наслов
assert.strictEqual(tripTitle(base), "Рим");
assert.strictEqual(tripTitle({ name: "Грција со другарките", destination: { name: "Солун" } }), "Грција со другарките");
assert.strictEqual(tripTitle({ destination: { name: "Солун" }, stops: [{ place: { name: "Солун" } }, { place: { name: "Лефкада" } }] }), "Солун → Лефкада");

console.log("Сите проверки поминаа ✓");
