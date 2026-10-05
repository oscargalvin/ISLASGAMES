// Islas Chat server: real chats between friends, plus the Islas AI helper.
//
// Messages live in an Upstash Redis database connected to the Vercel project
// (it sets KV_REST_API_URL and KV_REST_API_TOKEN). The AI needs
// ANTHROPIC_API_KEY. Everything goes through one POST endpoint:
//   POST /api/chat  { action: '...', token, ... }
const crypto = require('crypto');

const DB_URL = process.env.KV_REST_API_URL || process.env.UPSTASH_REDIS_REST_URL;
const DB_TOKEN = process.env.KV_REST_API_TOKEN || process.env.UPSTASH_REDIS_REST_TOKEN;
const AI_KEY = process.env.ANTHROPIC_API_KEY;
const AI_MODEL = process.env.ISLAS_AI_MODEL || 'claude-haiku-4-5';

const KEEP_MESSAGES = 500;
const AI_PER_DAY = 100;

class Oops extends Error {
  constructor(status, code) {
    super(code);
    this.status = status;
    this.code = code;
  }
}

/** Runs Redis commands in one round trip and returns their results. */
async function db(...commands) {
  if (!DB_URL || !DB_TOKEN) throw new Oops(503, 'not_set_up');
  const r = await fetch(`${DB_URL}/pipeline`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${DB_TOKEN}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(commands),
  });
  if (!r.ok) throw new Oops(502, 'db_error');
  const out = await r.json();
  return out.map((x) => {
    if (x.error) throw new Oops(502, 'db_error');
    return x.result;
  });
}

const randomId = (bytes) => crypto.randomBytes(bytes).toString('hex');

// No passwords: a device keeps a signed token that proves who it is.
const sign = (id) =>
  crypto.createHmac('sha256', `islas-chat:${DB_TOKEN}`).update(id).digest('hex').slice(0, 32);
const tokenFor = (id) => `${id}.${sign(id)}`;

function whoIs(token) {
  const [id, sig] = String(token || '').split('.');
  if (!id || !sig || sig.length !== 32) throw new Oops(401, 'bad_token');
  const want = sign(id);
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(want))) throw new Oops(401, 'bad_token');
  return id;
}

const clean = (s, max) => String(s ?? '').replace(/\s+/g, ' ').trim().slice(0, max);
const cleanText = (s, max) => String(s ?? '').trim().slice(0, max);
// An emoji (or a couple of characters) for an avatar.
const cleanAvatar = (s) => [...String(s ?? '').trim()].slice(0, 4).join('') || '🙂';

/** Makes a short invite code, like K7P2QX, that's easy to read out. */
function inviteCode() {
  const letters = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  return Array.from(crypto.randomBytes(6), (b) => letters[b % letters.length]).join('');
}

async function profiles(ids) {
  if (ids.length === 0) return {};
  const got = await db(['MGET', ...ids.map((i) => `user:${i}`)]);
  const out = {};
  ids.forEach((id, n) => {
    out[id] = got[0][n] ? JSON.parse(got[0][n]) : { name: 'Someone', avatar: '🙂' };
  });
  return out;
}

async function chatInfo(chatId, me) {
  const [raw, members, seq, last] = await db(
    ['GET', `chat:${chatId}`],
    ['SMEMBERS', `members:${chatId}`],
    ['GET', `seq:${chatId}`],
    ['LRANGE', `msgs:${chatId}`, -1, -1],
  );
  if (!raw) return null;
  const chat = JSON.parse(raw);
  const people = await profiles(members);
  return {
    id: chatId,
    group: chat.group,
    name: chat.name,
    avatar: chat.avatar,
    invite: chat.invite,
    members: members.map((id) => ({ id, ...people[id], me: id === me })),
    seq: Number(seq || 0),
    last: last[0] ? JSON.parse(last[0]) : null,
  };
}

async function mustBeMember(chatId, me) {
  const [isIn] = await db(['SISMEMBER', `members:${chatId}`, me]);
  if (!isIn) throw new Oops(403, 'not_in_chat');
}

const actions = {
  /** Make an account: just a name and an emoji. */
  async register(b) {
    const name = clean(b.name, 30);
    if (!name) throw new Oops(400, 'need_name');
    const id = randomId(8);
    await db(['SET', `user:${id}`, JSON.stringify({ name, avatar: cleanAvatar(b.avatar) })]);
    return { id, token: tokenFor(id) };
  },

  async profile(b) {
    const me = whoIs(b.token);
    const name = clean(b.name, 30);
    if (!name) throw new Oops(400, 'need_name');
    await db(['SET', `user:${me}`, JSON.stringify({ name, avatar: cleanAvatar(b.avatar) })]);
    return { ok: true };
  },

  /** A new chat (or group) with an invite link for friends. */
  async create(b) {
    const me = whoIs(b.token);
    const id = randomId(8);
    const invite = inviteCode();
    const group = !!b.group;
    const chat = {
      group,
      name: group ? clean(b.name, 40) || 'My group' : null,
      avatar: group ? cleanAvatar(b.avatar || '👥') : null,
      invite,
      by: me,
    };
    await db(
      ['SET', `chat:${id}`, JSON.stringify(chat)],
      ['SET', `invite:${invite}`, id],
      ['SADD', `members:${id}`, me],
      ['SADD', `chats:${me}`, id],
    );
    return { chat: await chatInfo(id, me) };
  },

  /** Join a chat from an invite link or code. */
  async join(b) {
    const me = whoIs(b.token);
    const code = clean(b.code, 12).toUpperCase();
    const [chatId] = await db(['GET', `invite:${code}`]);
    if (!chatId) throw new Oops(404, 'no_such_invite');
    const [, , added, profile] = await db(
      ['SADD', `members:${chatId}`, me],
      ['SADD', `chats:${me}`, chatId],
      ['SCARD', `members:${chatId}`],
      ['GET', `user:${me}`],
    );
    if (added && profile) {
      const { name } = JSON.parse(profile);
      await post(chatId, 'system', `${name} joined 👋`);
    }
    return { chat: await chatInfo(chatId, me) };
  },

  async leave(b) {
    const me = whoIs(b.token);
    const chatId = clean(b.chatId, 40);
    const [profile] = await db(['GET', `user:${me}`]);
    await db(['SREM', `members:${chatId}`, me], ['SREM', `chats:${me}`, chatId]);
    if (profile) await post(chatId, 'system', `${JSON.parse(profile).name} left`);
    return { ok: true };
  },

  /** All my chats, with the last message in each. */
  async list(b) {
    const me = whoIs(b.token);
    const [ids] = await db(['SMEMBERS', `chats:${me}`]);
    const chats = (await Promise.all(ids.map((id) => chatInfo(id, me)))).filter(Boolean);
    return { chats };
  },

  async send(b) {
    const me = whoIs(b.token);
    const chatId = clean(b.chatId, 40);
    const text = cleanText(b.text, 2000);
    if (!text) throw new Oops(400, 'empty');
    await mustBeMember(chatId, me);
    return { message: await post(chatId, me, text) };
  },

  /** Messages newer than `after` (the last seq the app has). */
  async messages(b) {
    const me = whoIs(b.token);
    const chatId = clean(b.chatId, 40);
    const after = Number(b.after || 0);
    const [isIn, seq] = await db(['SISMEMBER', `members:${chatId}`, me], ['GET', `seq:${chatId}`]);
    if (!isIn) throw new Oops(403, 'not_in_chat');
    const latest = Number(seq || 0);
    if (latest <= after) return { messages: [], seq: latest };
    const want = Math.min(latest - after, KEEP_MESSAGES);
    const [raw] = await db(['LRANGE', `msgs:${chatId}`, -want, -1]);
    return { messages: raw.map((m) => JSON.parse(m)).filter((m) => m.seq > after), seq: latest };
  },

  /** Ask Islas AI. The app sends the recent conversation. */
  async ai(b) {
    const me = whoIs(b.token);
    if (!AI_KEY) throw new Oops(503, 'ai_not_set_up');
    const day = new Date().toISOString().slice(0, 10);
    const [used] = await db(['INCR', `ai:${me}:${day}`], ['EXPIRE', `ai:${me}:${day}`, 172800]);
    if (used > AI_PER_DAY) throw new Oops(429, 'ai_tired');

    const history = (Array.isArray(b.history) ? b.history : [])
      .slice(-20)
      .map((m) => ({ role: m.me ? 'user' : 'assistant', content: cleanText(m.text, 2000) }))
      .filter((m) => m.content);
    // The conversation must start with the user and take turns.
    const turns = [];
    for (const m of history) {
      if (turns.length === 0 && m.role !== 'user') continue;
      const prev = turns[turns.length - 1];
      if (prev && prev.role === m.role) prev.content += `\n${m.content}`;
      else turns.push({ ...m });
    }
    if (turns.length === 0 || turns[turns.length - 1].role !== 'user') throw new Oops(400, 'empty');

    const r = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': AI_KEY,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: AI_MODEL,
        max_tokens: 400,
        system:
          'You are Islas AI, a friendly helper inside Islas Chat, a messaging app on the Islas Games website. ' +
          'Many users are kids and families, so keep everything kind, safe and age-appropriate. ' +
          'Reply like a chat message: short (usually 1-3 sentences), warm, playful, with an emoji or two. ' +
          'Play along with imaginative messages (if someone says they are in space, chat about space). ' +
          'Help with questions, jokes, stories, ideas and homework explanations. ' +
          'Never ask for personal details like addresses, phone numbers, school names or passwords.',
        messages: turns,
      }),
    });
    if (!r.ok) throw new Oops(502, 'ai_error');
    const out = await r.json();
    const text = (out.content || [])
      .filter((c) => c.type === 'text')
      .map((c) => c.text)
      .join('')
      .trim();
    return { text: text || '🤔' };
  },
};

// Numbers and stores a message in one step, so two people sending at the
// same moment can't end up with messages out of order.
const POST_SCRIPT = `
local seq = redis.call('INCR', KEYS[1])
local msg = string.gsub(ARGV[1], '"seq":0', '"seq":' .. seq, 1)
redis.call('RPUSH', KEYS[2], msg)
redis.call('LTRIM', KEYS[2], -tonumber(ARGV[2]), -1)
return seq`;

async function post(chatId, from, text) {
  const message = { seq: 0, from, text, t: Date.now() };
  const [seq] = await db([
    'EVAL', POST_SCRIPT, 2, `seq:${chatId}`, `msgs:${chatId}`,
    JSON.stringify(message), KEEP_MESSAGES,
  ]);
  return { ...message, seq };
}

module.exports = async function handler(req, res) {
  res.setHeader('Cache-Control', 'no-store');
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'post_only' });
    return;
  }
  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body || '{}') : req.body || {};
    const action = actions[body.action];
    if (!action) throw new Oops(400, 'unknown_action');
    res.status(200).json(await action(body));
  } catch (e) {
    if (e instanceof Oops) {
      res.status(e.status).json({ error: e.code });
    } else {
      console.error(e);
      res.status(500).json({ error: 'server_error' });
    }
  }
};

module.exports.actions = actions;
