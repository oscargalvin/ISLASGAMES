// Isla GPT's brain: a Vercel function that answers chat messages with Claude.
// Needs the ANTHROPIC_API_KEY environment variable set in the Vercel project.
import Anthropic from "@anthropic-ai/sdk";

const MAX_MESSAGES = 40;
const MAX_CHARS = 2000;
const MAX_TOOL_ROUNDS = 4;

const SYSTEM_PROMPT = `You are Isla GPT, a friendly, helpful assistant inside the Isla GPT app. Children and families use you, so you are kind, patient and safe.

How to answer:
- Answer exactly what was asked. Stay on topic and make sure every answer clearly connects to the question.
- Be accurate. If you are not sure, say so honestly instead of guessing, and never make up facts.
- Use clear, simple words and keep answers short unless the person asks for more detail. Short paragraphs or a few bullet points work best.
- Be warm and encouraging. Light use of emoji is fine.

Weather:
- For any question about the weather, call the get_weather tool. Never invent weather.
- With no place named, get_weather uses the person's shared area. If they have not shared it, kindly tell them to tap the location button at the top of the app, or to tell you their town.

Staying safe:
- Keep everything age-appropriate. Do not produce violent, scary, sexual, hateful or otherwise grown-up content, and do not help with anything dangerous or harmful.
- Never ask for personal details such as full name, home address, school, phone number, passwords or photos. If someone shares them, gently tell them not to share that online.
- Never suggest meeting anyone, and never pretend to be a real person.
- If someone seems upset, scared, hurt or in danger, respond with kindness and encourage them to talk to a parent, teacher or another trusted adult right away. In an emergency, tell them to call their local emergency number.
- For medical, legal or money worries, share simple general information and suggest asking a trusted adult or professional.`;

const WEATHER_TOOL = {
  name: "get_weather",
  description:
    "Get the current weather and today's forecast. Leave `place` out to use the person's shared area, or give a town or city name.",
  input_schema: {
    type: "object",
    properties: {
      place: {
        type: "string",
        description: "Town or city, e.g. 'Paris' or 'Leeds'. Leave out to use the person's shared area.",
      },
    },
    additionalProperties: false,
  },
};

const WEATHER_CODES = {
  0: "clear sky", 1: "mainly clear", 2: "partly cloudy", 3: "cloudy",
  45: "fog", 48: "freezing fog",
  51: "light drizzle", 53: "drizzle", 55: "heavy drizzle",
  56: "freezing drizzle", 57: "freezing drizzle",
  61: "light rain", 63: "rain", 65: "heavy rain",
  66: "freezing rain", 67: "freezing rain",
  71: "light snow", 73: "snow", 75: "heavy snow", 77: "snow grains",
  80: "light showers", 81: "showers", 82: "heavy showers",
  85: "snow showers", 86: "heavy snow showers",
  95: "thunderstorm", 96: "thunderstorm with hail", 99: "thunderstorm with hail",
};

// Rounds to one decimal place (about 11 km), so only the rough area is used.
export function roundToArea(value) {
  return Math.round(value * 10) / 10;
}

export function cleanArea(area) {
  if (!area || typeof area !== "object") return null;
  const lat = Number(area.lat);
  const lon = Number(area.lon);
  if (!Number.isFinite(lat) || !Number.isFinite(lon)) return null;
  if (Math.abs(lat) > 90 || Math.abs(lon) > 180) return null;
  return { lat: roundToArea(lat), lon: roundToArea(lon) };
}

// Turns the app's chat history into Claude messages, or returns an error string.
export function cleanMessages(messages) {
  if (!Array.isArray(messages) || messages.length === 0) return "Please ask a question.";
  const recent = messages.slice(-MAX_MESSAGES);
  const out = [];
  for (const m of recent) {
    const role = m?.role === "assistant" ? "assistant" : m?.role === "user" ? "user" : null;
    const text = typeof m?.text === "string" ? m.text.trim().slice(0, MAX_CHARS) : "";
    if (!role || !text) continue;
    // Merge back-to-back messages from the same side so roles alternate.
    if (out.length && out[out.length - 1].role === role) {
      out[out.length - 1].content += `\n\n${text}`;
    } else {
      out.push({ role, content: text });
    }
  }
  while (out.length && out[0].role !== "user") out.shift();
  if (!out.length || out[out.length - 1].role !== "user") return "Please ask a question.";
  return out;
}

async function getJson(url) {
  const res = await fetch(url, { headers: { "User-Agent": "IslaGPT/1.0" } });
  if (!res.ok) throw new Error(`HTTP ${res.status}`);
  return res.json();
}

async function areaName({ lat, lon }) {
  try {
    const data = await getJson(
      `https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lon}&localityLanguage=en`,
    );
    return [data.city || data.locality, data.countryName].filter(Boolean).join(", ") || null;
  } catch {
    return null;
  }
}

export async function getWeather(input, area) {
  let spot;
  if (input?.place) {
    const found = await getJson(
      `https://geocoding-api.open-meteo.com/v1/search?count=1&language=en&name=${encodeURIComponent(input.place)}`,
    );
    const r = found.results?.[0];
    if (!r) return `I couldn't find a place called "${input.place}".`;
    spot = { lat: r.latitude, lon: r.longitude, name: [r.name, r.country].filter(Boolean).join(", ") };
  } else if (area) {
    spot = { ...area, name: (await areaName(area)) ?? "the person's area" };
  } else {
    return "The person hasn't shared their area. Ask them to tap the location button at the top of the app, or to tell you their town.";
  }

  const w = await getJson(
    `https://api.open-meteo.com/v1/forecast?latitude=${spot.lat}&longitude=${spot.lon}` +
      "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation" +
      "&daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code" +
      "&forecast_days=1&timezone=auto",
  );
  const c = w.current;
  const d = w.daily;
  return JSON.stringify({
    place: spot.name,
    local_time: c.time,
    now: {
      conditions: WEATHER_CODES[c.weather_code] ?? "unknown",
      temperature_c: c.temperature_2m,
      feels_like_c: c.apparent_temperature,
      wind_kmh: c.wind_speed_10m,
      precipitation_mm: c.precipitation,
    },
    today: {
      conditions: WEATHER_CODES[d.weather_code?.[0]] ?? "unknown",
      high_c: d.temperature_2m_max?.[0],
      low_c: d.temperature_2m_min?.[0],
      chance_of_rain_percent: d.precipitation_probability_max?.[0],
    },
  });
}

let client;

export default async function handler(req, res) {
  if (req.method !== "POST") {
    res.setHeader("Allow", "POST");
    return res.status(405).json({ error: "Use POST." });
  }
  if (!process.env.ANTHROPIC_API_KEY) {
    return res.status(500).json({
      error: "Isla GPT isn't switched on yet. Add ANTHROPIC_API_KEY in the Vercel project settings.",
    });
  }

  const body = typeof req.body === "string" ? safeParse(req.body) : req.body ?? {};
  const messages = cleanMessages(body.messages);
  if (typeof messages === "string") return res.status(400).json({ error: messages });
  const area = cleanArea(body.area);

  client ??= new Anthropic();
  const today = new Date().toDateString();
  const system = `${SYSTEM_PROMPT}\n\nToday is ${today}. ${
    area ? "The person has shared their rough area." : "The person has not shared their area."
  }`;

  try {
    for (let round = 0; round <= MAX_TOOL_ROUNDS; round++) {
      const response = await client.beta.messages.create({
        model: "claude-opus-5-5",
        max_tokens: 4000,
        output_config: { effort: "low" },
        betas: ["server-side-fallback-2026-07-01"],
        fallbacks: "default",
        system,
        tools: [WEATHER_TOOL],
        messages,
      });

      if (response.stop_reason === "refusal") {
        return res.status(200).json({
          reply: "That's not something I can help with. Is there something else you'd like to ask? 😊",
        });
      }

      const toolUses = response.content.filter((b) => b.type === "tool_use");
      if (response.stop_reason !== "tool_use" || toolUses.length === 0 || round === MAX_TOOL_ROUNDS) {
        const reply = response.content
          .filter((b) => b.type === "text")
          .map((b) => b.text)
          .join("")
          .trim();
        return res.status(200).json({ reply: reply || "Hmm, I'm not sure. Could you ask that another way?" });
      }

      messages.push({ role: "assistant", content: response.content });
      const results = [];
      for (const tool of toolUses) {
        let content;
        let isError = false;
        try {
          content = tool.name === "get_weather" ? await getWeather(tool.input, area) : "Unknown tool.";
        } catch (e) {
          content = `The weather service didn't answer (${e.message}). Tell the person to try again soon.`;
          isError = true;
        }
        results.push({ type: "tool_result", tool_use_id: tool.id, content, is_error: isError });
      }
      messages.push({ role: "user", content: results });
    }
  } catch (e) {
    console.error("Isla GPT error", e);
    const busy = e instanceof Anthropic.RateLimitError || (e instanceof Anthropic.APIError && e.status >= 500);
    return res.status(busy ? 503 : 500).json({
      error: busy
        ? "Isla GPT is very busy right now. Please try again in a minute."
        : "Something went wrong. Please try again.",
    });
  }
}

function safeParse(text) {
  try {
    return JSON.parse(text);
  } catch {
    return {};
  }
}
