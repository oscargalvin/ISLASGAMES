// The games site's admin brain: a Vercel function that stores the site's live
// settings (the message for everyone, seasonal themes, news, game switches) and
// a history of every change so an older version can be brought back.
//
// GET  /api/admin            -> the public settings every visitor's page reads.
// POST /api/admin {code,...} -> admin actions. The code is checked here, never
//                               in the page, and is ADMIN_CODE (default 5522).
//
// Settings live in an Upstash Redis store. Connect one in Vercel (Storage tab ->
// Upstash Redis -> connect to this project) and it sets KV_REST_API_URL and
// KV_REST_API_TOKEN (or UPSTASH_REDIS_REST_URL / UPSTASH_REDIS_REST_TOKEN).

const STATE_KEY = "games:state";
const HISTORY_KEY = "games:history";
const MAX_HISTORY = 30;
const MAX_TRIES = 8; // wrong codes allowed per visitor every 10 minutes
const TRY_WINDOW_S = 600;

export const GAMES = [
  ["dont-look-back", "Don't Look Back"],
  ["yeet-the-human", "Yeet the Human"],
  ["night-shift", "Night Shift"],
  ["floor-is-doom", "Floor Is Doom"],
  ["road-rage-x", "Road Rage X"],
  ["teddy-exe", "Teddy.exe"],
  ["pizza-panic", "Pizza Panic"],
];

export const THEMES = {
  halloween: { title: "Halloween", emoji: "🎃" },
  christmas: { title: "Christmas", emoji: "🎄" },
  easter: { title: "Easter", emoji: "🐣" },
  summer: { title: "Summer", emoji: "☀️" },
  valentines: { title: "Valentine's", emoji: "💖" },
  bonfire: { title: "Bonfire Night", emoji: "🎆" },
};

export function defaultState() {
  return {
    v: 0,
    at: null,
    message: null,
    updates: Object.entries(THEMES).map(([theme, t]) => ({
      id: `season-${theme}`,
      kind: "season",
      theme,
      emoji: t.emoji,
      title: `${t.title} theme`,
      text: "",
      status: "off",
    })),
    games: Object.fromEntries(GAMES.map(([slug]) => [slug, { status: "live", badge: "" }])),
  };
}

// ---------- the word filter: rude words become ##### ----------

// Stored backwards so the file doesn't read as a list of rude words.
const RUDE = new Set(
  ["kcuf","kcf","kuf","ths","hctb","rekcuf","rekcufrehtom","tihs","tihsllub","hctib","ssa","elohssa","esra","elohesra","dratsab","tnuc",
   "kcid","daehkcid","kcoc","kcirp","yssup","tawt","knaw","reknaw","tuls","erohw","ssip","skcollob","dnelleb",
   "stit","seittit","sboob","sinep","anigav","nrop","xes","yxes","reggin","aggin","toggaf","gaf","drater",
   "citsaps","ekyd","knihc","cips","syk"].map((w) => [...w].reverse().join("")),
);
// Rude anywhere inside a word ("fuuuckin", "shitty"). Only stems that no
// everyday word contains, so "Scunthorpe", "cockpit" and "class" stay as they are.
const STEMS = ["kcuf", "kcf", "tihs", "hctib", "knaw", "tawt", "tuls", "erohw", "dratsab", "elohssa", "reggin", "toggaf"].map(
  (w) => [...w].reverse().join(""),
);
const ENDINGS = ["s", "es", "ed", "er", "ers", "ing", "in", "y", "ty"];
const LEET = { 0: "o", 1: "i", 3: "e", 4: "a", 5: "s", 7: "t", "@": "a", $: "s", "!": "i", "*": "" };

const norm = (word) => word.toLowerCase().replace(/[013457@$!*]/g, (c) => LEET[c]).replace(/[^a-z]/g, "");
const collapse = (s) => s.replace(/(.)\1+/g, "$1");
const RUDE_COLLAPSED = new Set([...RUDE].map(collapse).filter((w) => w.length >= 4));

export function isRude(word) {
  const s = norm(word);
  if (!s) return false;
  const forms = [s, ...ENDINGS.filter((e) => s.endsWith(e) && s.length > e.length + 2).map((e) => s.slice(0, -e.length))];
  if (forms.some((f) => RUDE.has(f) || RUDE_COLLAPSED.has(collapse(f)))) return true;
  const c = collapse(s);
  return STEMS.some((stem) => c.includes(collapse(stem)));
}

export function cleanText(text, max = 200) {
  const t = String(text ?? "")
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, max);
  return t.replace(/[\p{L}\p{N}@$!*]+/gu, (w) => (isRude(w) ? "#".repeat(w.length) : w));
}

// ---------- tidying what the admin page sends ----------

const ONE_EMOJI = /^[\p{Extended_Pictographic}\p{Emoji_Component}‍️]{1,16}$/u;
const cleanEmoji = (e, fallback) => (typeof e === "string" && ONE_EMOJI.test(e) ? e : fallback);

export function cleanState(input, now = Date.now()) {
  const base = defaultState();
  const s = input && typeof input === "object" ? input : {};
  const out = { v: 0, at: null, message: null, updates: [], games: base.games };

  const m = s.message;
  if (m && typeof m === "object" && cleanText(m.text)) {
    const mins = Math.min(Math.max(Number(m.minutes) || 10, 1), 7 * 24 * 60);
    out.message = {
      id: typeof m.id === "string" && /^[\w-]{1,40}$/.test(m.id) ? m.id : `m${now.toString(36)}`,
      text: cleanText(m.text, 200),
      emoji: cleanEmoji(m.emoji, "📣"),
      minutes: mins,
      until: Number(m.until) > 0 ? Math.min(Number(m.until), now + mins * 60000) : now + mins * 60000,
    };
  }

  const seen = new Set();
  for (const u of Array.isArray(s.updates) ? s.updates.slice(0, 60) : []) {
    if (!u || typeof u !== "object") continue;
    const kind = u.kind === "season" && THEMES[u.theme] ? "season" : "news";
    const id = typeof u.id === "string" && /^[\w-]{1,40}$/.test(u.id) ? u.id : null;
    if (!id || seen.has(id)) continue;
    const title = cleanText(u.title, 60);
    if (!title) continue;
    seen.add(id);
    out.updates.push({
      id,
      kind,
      ...(kind === "season" ? { theme: u.theme } : {}),
      emoji: cleanEmoji(u.emoji, kind === "season" ? THEMES[u.theme].emoji : "✨"),
      title,
      text: cleanText(u.text, 240),
      status: ["on", "off", "away"].includes(u.status) ? u.status : "off",
    });
  }
  // The built-in seasons always exist, so one can't be lost by accident.
  for (const d of base.updates) if (!seen.has(d.id)) out.updates.push(d);

  const g = s.games && typeof s.games === "object" ? s.games : {};
  for (const [slug] of GAMES) {
    const x = g[slug] && typeof g[slug] === "object" ? g[slug] : {};
    out.games[slug] = {
      status: ["live", "fixing", "hidden"].includes(x.status) ? x.status : "live",
      badge: ["", "new", "updated"].includes(x.badge) ? x.badge : "",
    };
  }
  return out;
}

// What visitors see: no paused or put-away updates, no finished message.
export function publicView(state, now = Date.now()) {
  return {
    configured: true,
    v: state.v,
    message: state.message && state.message.until > now ? state.message : null,
    updates: state.updates.filter((u) => u.status === "on"),
    games: state.games,
  };
}

// ---------- storage ----------

function redisFromEnv() {
  const url = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;
  return async (...commands) => {
    const res = await fetch(`${url.replace(/\/$/, "")}/pipeline`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify(commands),
    });
    if (!res.ok) throw new Error(`Store said HTTP ${res.status}`);
    const out = await res.json();
    const bad = out.find((r) => r.error);
    if (bad) throw new Error(`Store said ${bad.error}`);
    return out.map((r) => r.result);
  };
}

let redisOverride;
export function useStoreForTests(fn) {
  redisOverride = fn;
}
const redis = () => (redisOverride !== undefined ? redisOverride : redisFromEnv());

async function loadState(r) {
  const [raw] = await r(["GET", STATE_KEY]);
  if (!raw) return defaultState();
  try {
    const s = JSON.parse(raw);
    return { ...cleanState(s), v: Number(s.v) || 0, at: s.at || null };
  } catch {
    return defaultState();
  }
}

async function saveState(r, next, note, prevV, now = Date.now()) {
  const state = { ...next, v: prevV + 1, at: new Date(now).toISOString() };
  const entry = JSON.stringify({ v: state.v, at: state.at, note: cleanText(note, 80) || "Changed settings", state });
  await r(["SET", STATE_KEY, JSON.stringify(state)], ["LPUSH", HISTORY_KEY, entry], ["LTRIM", HISTORY_KEY, 0, MAX_HISTORY - 1]);
  return state;
}

async function loadHistory(r) {
  const [list] = await r(["LRANGE", HISTORY_KEY, 0, MAX_HISTORY - 1]);
  return (list || []).map((x) => {
    try {
      return JSON.parse(x);
    } catch {
      return null;
    }
  }).filter(Boolean);
}

// ---------- the code ----------

function sameCode(a, b) {
  a = String(a ?? "");
  b = String(b ?? "");
  let diff = a.length ^ b.length;
  for (let i = 0; i < Math.max(a.length, b.length); i++) diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  return diff === 0;
}

async function checkCode(r, req, code) {
  const ip = String(req.headers?.["x-forwarded-for"] || "anon").split(",")[0].trim().slice(0, 64);
  const key = `games:tries:${ip}`;
  const [tries] = await r(["GET", key]);
  if (Number(tries) >= MAX_TRIES) return "locked";
  if (sameCode(code, process.env.ADMIN_CODE || "5522")) return "ok";
  await r(["INCR", key], ["EXPIRE", key, TRY_WINDOW_S]);
  return "wrong";
}

// ---------- the handler ----------

const safeParse = (s) => {
  try {
    return JSON.parse(s);
  } catch {
    return {};
  }
};

export default async function handler(req, res) {
  const r = redis();

  if (req.method === "GET") {
    // Cached at Vercel's edge for a few seconds so lots of visitors only
    // cost one store read between them.
    res.setHeader("Cache-Control", "public, s-maxage=8, stale-while-revalidate=20");
    if (!r) return res.status(200).json({ ...publicView(defaultState()), configured: false });
    try {
      return res.status(200).json(publicView(await loadState(r)));
    } catch (e) {
      console.error("admin GET:", e);
      return res.status(200).json({ ...publicView(defaultState()), configured: true, error: "store" });
    }
  }

  if (req.method !== "POST") {
    res.setHeader("Allow", "GET, POST");
    return res.status(405).json({ error: "Use GET or POST." });
  }
  res.setHeader("Cache-Control", "no-store");
  if (!r) {
    return res.status(503).json({
      error: "The admin panel needs a store connected in Vercel first (Storage → Upstash Redis → connect to this project).",
      needsStore: true,
    });
  }

  const body = typeof req.body === "string" ? safeParse(req.body) : req.body ?? {};
  try {
    const ok = await checkCode(r, req, body.code);
    if (ok === "locked") return res.status(429).json({ error: "Too many wrong codes. Try again in 10 minutes." });
    if (ok === "wrong") return res.status(401).json({ error: "Wrong code." });

    const state = await loadState(r);
    const history = () => loadHistory(r).then((h) => h.map(({ v, at, note }) => ({ v, at, note })));

    switch (body.action) {
      case "login":
      case "get":
        return res.status(200).json({ state, history: await history() });

      case "save": {
        if (Number(body.v) !== state.v) {
          return res.status(409).json({ error: "Someone else changed the settings. Loading the latest.", state, history: await history() });
        }
        const next = await saveState(r, cleanState(body.state), body.note, state.v);
        return res.status(200).json({ state: next, history: await history() });
      }

      case "restore": {
        const found = (await loadHistory(r)).find((h) => h.v === Number(body.to));
        if (!found) return res.status(404).json({ error: "That version is too old and has gone." });
        // A finished message stays finished when an old version comes back.
        const old = cleanState(found.state);
        if (found.state.message && found.state.message.until <= Date.now()) old.message = null;
        else if (found.state.message) old.message = { ...old.message, until: found.state.message.until };
        const next = await saveState(r, old, `Went back to version ${found.v}`, state.v);
        return res.status(200).json({ state: next, history: await history() });
      }

      default:
        return res.status(400).json({ error: "Unknown action." });
    }
  } catch (e) {
    console.error("admin POST:", e);
    return res.status(502).json({ error: "Couldn't reach the store. Try again." });
  }
}
