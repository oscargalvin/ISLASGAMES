# Isla GPT ✨

A friendly chat app, a bit like ChatGPT. Ask it anything and it answers the question you actually asked. It's built in Flutter and hosted on Vercel, the same setup as Islas Games.

## What it does

- **Ask anything.** Type a question or tap one of the suggestions. Answers come from Claude, Anthropic's AI, and stay on topic.
- **Weather where you are.** Ask "What's the weather today?" and Isla GPT gives the real weather for your area. You can also ask about any town by name.
- **Only your rough area.** Tap the 📍 button and the browser asks permission first. The location is rounded to about 10 km before it leaves your device, so Isla GPT knows your town but never your street. It's only kept while the page is open, and tapping the button again forgets it.
- **Safe for kids.** Answers are kept age-appropriate. Isla GPT never asks for personal details, and it points anyone who seems upset or in danger to a trusted adult.

## Putting it on Vercel (one time)

Isla GPT lives in the `isla-gpt/` folder of the ISLASGAMES repo and gets its own Vercel site:

1. In Vercel, choose **Add New → Project** and import the ISLASGAMES repo again.
2. Set **Root Directory** to `isla-gpt` and name the project `isla-gpt`.
3. Under **Environment Variables**, add `ANTHROPIC_API_KEY` with a key from https://console.anthropic.com.
4. Press **Deploy**.

Weather comes from Open-Meteo, and area names come from BigDataCloud. Neither needs a key.

## The secret admin panel (games site)

Tap **Isla & Oscar's Games** at the top of the games page 4 times quickly, then type the code (5522, or whatever `ADMIN_CODE` is set to in Vercel). From there you can message everyone on the site, switch seasonal themes and news on, off or put them away, close or hide a game while it's being fixed, and go back to any of the last 30 versions.

It saves its settings in a free Upstash Redis store. One time: in Vercel open the project, go to **Storage → Create Database → Upstash for Redis**, connect it to this project, then redeploy. Until then the games work as normal and the panel shows these steps.

## How it's put together

| Part | Where |
|---|---|
| Chat screen | `lib/screens/chat_screen.dart` |
| Sending questions, rounding the area | `lib/services/isla_client.dart` |
| Asking the browser for location | `lib/services/location_service.dart` |
| The AI and weather (Vercel function) | `api/chat.mjs` |
| Vercel build settings | `vercel.json` |
| Games admin brain (Vercel function) | `api/admin.mjs` |
| Admin panel page | `web/games/admin.html` |
| Live messages and themes on the games page | `web/games/live.js` |

## Running locally

```bash
flutter pub get
flutter run -d chrome --dart-define=ISLA_GPT_API=https://<your-vercel-site>/api/chat
```

Without `ISLA_GPT_API`, the app calls `/api/chat` on the site it's served from, which is the Vercel function.

## Tests

```bash
flutter test
npm install && node --test api_test/*.test.mjs
```
