// Run with: node --test api_test/*.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import handler, { cleanArea, cleanMessages } from "../api/chat.mjs";

test("areas are rounded to about 10 km", () => {
  assert.deepEqual(cleanArea({ lat: 51.50735, lon: -0.12776 }), { lat: 51.5, lon: -0.1 });
  assert.equal(cleanArea({ lat: "x", lon: 1 }), null);
  assert.equal(cleanArea({ lat: 200, lon: 1 }), null);
});

test("chat history is tidied into alternating turns ending with a question", () => {
  const out = cleanMessages([
    { role: "assistant", text: "hello" },
    { role: "user", text: "hi" },
    { role: "user", text: "weather?" },
  ]);
  assert.deepEqual(out, [{ role: "user", content: "hi\n\nweather?" }]);
  assert.equal(typeof cleanMessages([]), "string");
  assert.equal(typeof cleanMessages([{ role: "user", text: "a" }, { role: "assistant", text: "b" }]), "string");
  assert.equal(cleanMessages([{ role: "user", text: "x".repeat(5000) }])[0].content.length, 2000);
});

function fakeRes() {
  return {
    headers: {},
    setHeader(k, v) { this.headers[k] = v; },
    status(code) { this.code = code; return this; },
    json(body) { this.body = body; return this; },
  };
}

test("a missing API key gives a friendly setup message", async () => {
  const saved = process.env.ANTHROPIC_API_KEY;
  delete process.env.ANTHROPIC_API_KEY;
  const res = fakeRes();
  await handler({ method: "POST", body: { messages: [{ role: "user", text: "hi" }] } }, res);
  assert.equal(res.code, 500);
  assert.match(res.body.error, /ANTHROPIC_API_KEY/);
  if (saved) process.env.ANTHROPIC_API_KEY = saved;
});

test("only POST is allowed", async () => {
  const res = fakeRes();
  await handler({ method: "GET" }, res);
  assert.equal(res.code, 405);
});
