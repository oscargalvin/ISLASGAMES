// Run with: node --test api_test/*.test.mjs
import assert from "node:assert/strict";
import { test } from "node:test";

import Anthropic from "@anthropic-ai/sdk";

import handler, { cleanArea, cleanMessages, createWithFallback, explainError, usesFahrenheit } from "../api/chat.mjs";

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

test("Fahrenheit for the US, Celsius elsewhere", () => {
  assert.equal(usesFahrenheit("US"), true);
  assert.equal(usesFahrenheit("us"), true);
  assert.equal(usesFahrenheit("GB"), false);
  assert.equal(usesFahrenheit(undefined), false);
});

function apiError(status, message) {
  return Anthropic.APIError.generate(status, { type: "error", error: { type: "x", message } }, message, new Headers());
}

test("API failures say what to fix", () => {
  assert.match(explainError(apiError(401, "invalid x-api-key")).error, /AI key isn't working/);
  assert.match(
    explainError(apiError(400, "Your credit balance is too low to access the Anthropic API.")).error,
    /run out of credit/,
  );
  assert.equal(explainError(apiError(529, "Overloaded")).status, 503);
  assert.match(explainError(apiError(400, "bad thing")).error, /\(400: bad thing\)/);
});

test("a busy or unavailable model falls back to the next one", async () => {
  const tried = [];
  const fake = {
    messages: {
      create: async (p) => {
        tried.push(p.model);
        if (p.model === "a") throw apiError(429, "rate limited");
        if (p.model === "b") throw apiError(404, "model not found");
        return { model: p.model, effort: p.output_config?.effort };
      },
    },
  };
  const out = await createWithFallback(fake, { max_tokens: 10 }, [
    { model: "a", output_config: { effort: "low" } },
    { model: "b" },
    { model: "c" },
  ]);
  assert.deepEqual(tried, ["a", "b", "c"]);
  assert.deepEqual(out, { model: "c", effort: undefined });
});

test("a bad key does not try other models", async () => {
  const tried = [];
  const fake = { messages: { create: async (p) => { tried.push(p.model); throw apiError(401, "bad key"); } } };
  await assert.rejects(createWithFallback(fake, {}, [{ model: "a" }, { model: "b" }]));
  assert.deepEqual(tried, ["a"]);
});
