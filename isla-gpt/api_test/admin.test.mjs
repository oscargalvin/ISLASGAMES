// Run with: node --test api_test/*.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import handler, { cleanState, cleanText, defaultState, isRude, publicView, useStoreForTests } from "../api/admin.mjs";

// A tiny stand-in for the Upstash store: just the commands admin.mjs uses.
function memoryStore() {
  const kv = new Map();
  return async (...commands) =>
    commands.map(([cmd, key, ...args]) => {
      switch (cmd) {
        case "GET": return kv.get(key) ?? null;
        case "SET": kv.set(key, args[0]); return "OK";
        case "INCR": kv.set(key, String(Number(kv.get(key) || 0) + 1)); return Number(kv.get(key));
        case "EXPIRE": return 1;
        case "LPUSH": kv.set(key, [args[0], ...(kv.get(key) || [])]); return kv.get(key).length;
        case "LTRIM": kv.set(key, (kv.get(key) || []).slice(args[0], args[1] + 1)); return "OK";
        case "LRANGE": return (kv.get(key) || []).slice(args[0], args[1] + 1);
        default: throw new Error(`unknown ${cmd}`);
      }
    });
}

function fakeRes() {
  return {
    headers: {},
    statusCode: 200,
    body: null,
    setHeader(k, v) { this.headers[k] = v; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
  };
}
const post = async (body, ip = "1.1.1.1") => {
  const res = fakeRes();
  await handler({ method: "POST", headers: { "x-forwarded-for": ip }, body }, res);
  return res;
};
const get = async () => {
  const res = fakeRes();
  await handler({ method: "GET", headers: {} }, res);
  return res;
};

test("rude words become hashes, everyday words stay", () => {
  assert.equal(cleanText("we are doing an update"), "we are doing an update");
  assert.equal(cleanText("what the sh!t"), "what the ####");
  assert.equal(cleanText("FUUUCKING thing"), "######### thing");
  assert.equal(cleanText("Scunthorpe class assassin pass hello cockpit"), "Scunthorpe class assassin pass hello cockpit");
  assert.ok(isRude("b1tch"));
  assert.ok(!isRude("glass"));
});

test("settings from the page are tidied", () => {
  const s = cleanState({
    message: { text: "  hi   there  ", emoji: "<script>", minutes: 99999999 },
    updates: [{ id: "x1", kind: "news", title: "New!", text: "a".repeat(999), status: "weird" }, { id: "bad id!", title: "x" }],
    games: { "pizza-panic": { status: "fixing", badge: "updated" }, "nope": { status: "hidden" } },
  }, 1000);
  assert.equal(s.message.text, "hi there");
  assert.equal(s.message.emoji, "📣");
  assert.equal(s.message.until, 1000 + 7 * 24 * 60 * 60000);
  assert.equal(s.updates[0].text.length, 240);
  assert.equal(s.updates[0].status, "off");
  assert.ok(!s.updates.some((u) => u.id === "bad id!"));
  assert.ok(s.updates.some((u) => u.id === "season-halloween"), "built-in themes always come back");
  assert.deepEqual(s.games["pizza-panic"], { status: "fixing", badge: "updated" });
  assert.ok(!("nope" in s.games));
});

test("visitors only see what's switched on and a message that hasn't finished", () => {
  const s = defaultState();
  s.updates[0].status = "on";
  s.updates[1].status = "away";
  s.message = { id: "m", text: "hi", emoji: "📣", until: 5 };
  const v = publicView(s, 10);
  assert.equal(v.updates.length, 1);
  assert.equal(v.message, null);
});

test("without a store the site still works and the panel explains the setup", async () => {
  useStoreForTests(null);
  const g = await get();
  assert.equal(g.body.configured, false);
  const p = await post({ code: "5522", action: "login" });
  assert.equal(p.statusCode, 503);
  assert.ok(p.body.needsStore);
});

test("the code is checked, saves make versions, and old versions come back", async () => {
  useStoreForTests(memoryStore());
  assert.equal((await post({ code: "1234", action: "login" })).statusCode, 401);

  const login = await post({ code: "5522", action: "login" });
  assert.equal(login.statusCode, 200);
  const s0 = login.body.state;
  assert.equal(s0.v, 0);

  const next = structuredClone(s0);
  next.message = { text: "We are doing an update, you shit", emoji: "🔧", minutes: 5 };
  next.updates.find((u) => u.theme === "halloween").status = "on";
  const saved = await post({ code: "5522", action: "save", v: 0, state: next, note: "Halloween on" });
  assert.equal(saved.statusCode, 200);
  assert.equal(saved.body.state.v, 1);
  assert.equal(saved.body.state.message.text, "We are doing an update, you ####");

  const pub = await get();
  assert.equal(pub.body.message.text, "We are doing an update, you ####");
  assert.equal(pub.body.updates.length, 1);
  assert.match(pub.headers["Cache-Control"], /s-maxage/);

  // An old page can't overwrite a newer change.
  assert.equal((await post({ code: "5522", action: "save", v: 0, state: next })).statusCode, 409);

  const off = structuredClone(saved.body.state);
  off.updates.find((u) => u.theme === "halloween").status = "away";
  off.message = null;
  const s2 = await post({ code: "5522", action: "save", v: 1, state: off, note: "Put away" });
  assert.equal(s2.body.state.v, 2);
  assert.equal((await get()).body.updates.length, 0);
  assert.deepEqual(s2.body.history.map((h) => h.v), [2, 1]);

  const back = await post({ code: "5522", action: "restore", to: 1 });
  assert.equal(back.statusCode, 200);
  assert.equal(back.body.state.v, 3);
  assert.equal(back.body.state.updates.find((u) => u.theme === "halloween").status, "on");
  assert.equal(back.body.history[0].note, "Went back to version 1");
});

test("too many wrong codes locks that visitor out for a while", async () => {
  useStoreForTests(memoryStore());
  for (let i = 0; i < 8; i++) assert.equal((await post({ code: "0000", action: "login" }, "9.9.9.9")).statusCode, 401);
  assert.equal((await post({ code: "5522", action: "login" }, "9.9.9.9")).statusCode, 429);
  assert.equal((await post({ code: "5522", action: "login" }, "8.8.8.8")).statusCode, 200);
});
