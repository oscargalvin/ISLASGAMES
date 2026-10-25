// Live settings for the games shelf: reads what the admin panel set (a message
// for everyone, seasonal themes, news, games being fixed) and shows it. Also
// opens the admin panel when the title is tapped 4 times quickly.
(() => {
  const API = '/api/admin';
  const POLL_MS = 15000;
  const SEEN_KEY = 'games-seen-message';
  const THEMES = {
    halloween: { fall: ['🎃', '🦇', '👻', '🕷️'], hello: 'Happy Halloween!', bg: ['#4a1d06', '#2a0b3a'] },
    christmas: { fall: ['❄️', '❄️', '⛄', '🎁'], hello: 'Merry Christmas!', bg: ['#0b3d2a', '#5c0f1c'] },
    easter: { fall: ['🥚', '🐣', '🌷', '🐰'], hello: 'Happy Easter!', bg: ['#3d6b4a', '#6b3d6b'] },
    summer: { fall: ['☀️', '🌴', '🍉', '🏖️'], hello: 'Happy Summer!', bg: ['#0a6b8a', '#b5651d'] },
    valentines: { fall: ['💖', '💕', '💘', '🌹'], hello: "Happy Valentine's!", bg: ['#6b0f3a', '#3a0b4a'] },
    bonfire: { fall: ['🎆', '🎇', '✨', '🔥'], hello: 'Happy Bonfire Night!', bg: ['#2a0b05', '#0b0b3a'] },
  };

  const $ = (sel) => document.querySelector(sel);
  const el = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  };
  const store = {
    get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } },
    set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} },
  };

  // ---------- secret: tap the title 4 times quickly ----------
  const title = $('header h1');
  let taps = [];
  if (title) {
    title.style.cursor = 'default';
    title.style.userSelect = 'none';
    title.addEventListener('click', () => {
      const now = Date.now();
      taps = taps.filter((t) => now - t < 1500).concat(now);
      if (taps.length >= 4) { taps = []; location.href = 'admin.html'; }
    });
  }

  // ---------- the parts we draw ----------
  const style = el('style');
  style.textContent = `
  #liveMsg { position: fixed; z-index: 300; left: 50%; top: calc(14px + env(safe-area-inset-top, 0px)); transform: translate(-50%, -160%); width: min(560px, calc(100% - 24px)); display: flex; gap: 12px; align-items: center; padding: 14px 14px 14px 18px; background: #fffaf0; color: #1d1b3a; border: 4px solid #000; border-radius: 22px; box-shadow: 0 8px 0 #000; font: 800 17px/1.3 Nunito, system-ui, sans-serif; transition: transform .35s cubic-bezier(.2,1.4,.4,1); }
  #liveMsg.show { transform: translate(-50%, 0); }
  #liveMsg .ico { font-size: 34px; line-height: 1; }
  #liveMsg .txt { flex: 1; overflow-wrap: anywhere; }
  #liveMsg .txt small { display: block; font-size: 12px; letter-spacing: .08em; text-transform: uppercase; color: #ff4f6d; }
  #liveMsg button { flex: none; padding: 10px 16px; border-radius: 999px; border: 3px solid #000; background: #ffd23f; color: #1d1b3a; font: 900 15px Nunito, system-ui, sans-serif; cursor: pointer; box-shadow: 0 3px 0 #000; }
  #liveFall { position: fixed; inset: 0; pointer-events: none; overflow: hidden; z-index: 3; }
  #liveFall span { position: absolute; top: -40px; animation: liveFall linear infinite; opacity: .75; }
  @keyframes liveFall { to { transform: translate(var(--dx), 110vh) rotate(var(--r)); } }
  main { position: relative; z-index: 2; }
  .liveHello { display: inline-block; margin-top: 14px; padding: 6px 16px; border-radius: 999px; background: #fffaf0; color: #1d1b3a; border: 3px solid #000; font-family: var(--display); font-size: 18px; box-shadow: 0 4px 0 #000; }
  #liveNews { display: grid; gap: 12px; margin: 0 0 22px; }
  #liveNews .news { display: flex; gap: 14px; align-items: center; padding: 14px 18px; border-radius: 20px; border: 4px solid #000; background: #fffaf0; color: #1d1b3a; box-shadow: 0 6px 0 #000; }
  #liveNews .news .ico { font-size: 32px; }
  #liveNews .news b { font-family: var(--display); font-weight: 400; font-size: 21px; display: block; }
  #liveNews .news span { font-size: 15px; }
  .game.fixing .art { filter: grayscale(.8) brightness(.6); }
  .game .fixTag { position: absolute; inset: auto 0 45% 0; margin: auto; width: max-content; max-width: 90%; padding: 8px 14px; border-radius: 14px; background: #ffd23f; color: #1d1b3a; border: 3px solid #000; font: 900 15px Nunito, system-ui, sans-serif; text-align: center; z-index: 2; }
  .badge.updated { background: #7cc8ff; }
  #liveToast { position: fixed; z-index: 310; left: 50%; bottom: calc(24px + env(safe-area-inset-bottom, 0px)); transform: translateX(-50%); padding: 12px 20px; border-radius: 999px; background: #000; color: #fff; font: 800 15px Nunito, system-ui, sans-serif; max-width: calc(100% - 24px); text-align: center; }
  @media (prefers-reduced-motion: reduce) { #liveFall { display: none; } #liveMsg { transition: none; } }
  `;
  document.head.appendChild(style);

  // The message for everyone sits above the games too, so players see it mid-game.
  const msg = el('div');
  msg.id = 'liveMsg';
  msg.setAttribute('role', 'status');
  msg.hidden = true;
  const msgIco = el('div', 'ico');
  const msgTxt = el('div', 'txt');
  const msgOk = el('button', '', 'OK!');
  msg.append(msgIco, msgTxt, msgOk);
  document.body.appendChild(msg);
  let shownMsgId = null;
  msgOk.addEventListener('click', () => {
    if (shownMsgId) store.set(SEEN_KEY, shownMsgId);
    hideMsg();
  });
  function hideMsg() {
    msg.classList.remove('show');
    setTimeout(() => { if (!msg.classList.contains('show')) msg.hidden = true; }, 400);
  }
  function showMessage(m) {
    if (!m) {
      if (shownMsgId) { shownMsgId = null; hideMsg(); }
      return;
    }
    if (shownMsgId === m.id || store.get(SEEN_KEY) === m.id) return;
    shownMsgId = m.id;
    msgIco.textContent = m.emoji || '📣';
    msgTxt.replaceChildren(el('small', '', 'Message from Isla & Oscar'), document.createTextNode(m.text));
    msg.hidden = false;
    requestAnimationFrame(() => requestAnimationFrame(() => msg.classList.add('show')));
    try { navigator.vibrate && navigator.vibrate(80); } catch (e) {}
  }

  let toastTimer;
  function toast(text) {
    let t = $('#liveToast');
    if (!t) { t = el('div'); t.id = 'liveToast'; document.body.appendChild(t); }
    t.textContent = text;
    t.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => { t.hidden = true; }, 2600);
  }

  // ---------- seasonal themes ----------
  const fall = el('div');
  fall.id = 'liveFall';
  fall.setAttribute('aria-hidden', 'true');
  document.body.prepend(fall);
  let themeKey = '';
  function showSeasons(seasons) {
    const key = seasons.map((s) => s.theme).sort().join(',');
    if (key === themeKey) return;
    themeKey = key;
    fall.replaceChildren();
    document.querySelectorAll('.liveHello').forEach((e) => e.remove());
    document.body.style.background = '';
    if (!seasons.length) return;
    const looks = seasons.map((s) => THEMES[s.theme]).filter(Boolean);
    if (!looks.length) return;
    const [a, b] = looks[0].bg;
    document.body.style.background = `radial-gradient(circle at 20% 0%, ${a} 0, transparent 50%), radial-gradient(circle at 90% 100%, ${b} 0, transparent 45%), var(--bg)`;
    const emojis = looks.flatMap((l) => l.fall);
    const count = window.innerWidth < 600 ? 12 : 26;
    for (let i = 0; i < count; i++) {
      const s = el('span', '', emojis[i % emojis.length]);
      s.style.left = Math.random() * 100 + '%';
      s.style.fontSize = 18 + Math.random() * 22 + 'px';
      s.style.animationDuration = 7 + Math.random() * 9 + 's';
      s.style.animationDelay = -Math.random() * 16 + 's';
      s.style.setProperty('--dx', (Math.random() * 120 - 60).toFixed(0) + 'px');
      s.style.setProperty('--r', (Math.random() * 720 - 360).toFixed(0) + 'deg');
      fall.appendChild(s);
    }
    const header = $('header');
    if (header) {
      const hello = el('div', 'liveHello', seasons.map((s) => `${s.emoji} ${THEMES[s.theme]?.hello || s.title}`).join('  '));
      header.appendChild(hello);
    }
  }

  // ---------- news ----------
  let newsBox = null;
  function showNews(news) {
    if (!newsBox) {
      newsBox = el('section');
      newsBox.id = 'liveNews';
      newsBox.setAttribute('aria-label', "What's new");
      const shelf = $('.shelf');
      if (shelf) shelf.before(newsBox);
    }
    newsBox.replaceChildren(...news.map((n) => {
      const card = el('div', 'news');
      const body = el('div');
      body.append(el('b', '', n.title));
      if (n.text) body.append(el('span', '', n.text));
      card.append(el('div', 'ico', n.emoji || '✨'), body);
      return card;
    }));
    newsBox.hidden = !news.length;
  }

  // ---------- game switches ----------
  const buttons = [...document.querySelectorAll('.game[data-src]')];
  const original = new Map(buttons.map((b) => {
    const badge = b.querySelector('.badge');
    return [b, { text: badge?.textContent, cls: badge?.className }];
  }));
  const gameStatus = new Map();
  function showGames(games) {
    for (const b of buttons) {
      const slug = b.dataset.src.replace(/\.html$/, '');
      const g = (games && games[slug]) || { status: 'live', badge: '' };
      gameStatus.set(b, g.status);
      b.hidden = g.status === 'hidden';
      b.classList.toggle('fixing', g.status === 'fixing');
      let tag = b.querySelector('.fixTag');
      if (g.status === 'fixing' && !tag) { tag = el('span', 'fixTag', '🔧 Getting an update!'); b.appendChild(tag); }
      if (g.status !== 'fixing' && tag) tag.remove();
      const badge = b.querySelector('.badge');
      const o = original.get(b);
      if (badge) {
        if (g.badge === 'new') { badge.textContent = 'New!'; badge.className = 'badge new'; }
        else if (g.badge === 'updated') { badge.textContent = 'Updated!'; badge.className = 'badge updated'; }
        else { badge.textContent = o.text; badge.className = o.cls; }
      }
    }
  }
  // Runs before the shelf's own click handler, so a game being fixed doesn't open.
  document.addEventListener('click', (e) => {
    const b = e.target.closest && e.target.closest('.game[data-src]');
    if (b && gameStatus.get(b) === 'fixing') {
      e.stopImmediatePropagation();
      e.preventDefault();
      toast('🔧 This game is getting an update. Come back soon!');
    }
  }, true);

  // ---------- reading the settings ----------
  async function check() {
    if (document.hidden) return;
    try {
      const res = await fetch(API, { cache: 'no-cache' });
      if (!res.ok) return;
      const s = await res.json();
      if (!s || !s.configured) return;
      const updates = Array.isArray(s.updates) ? s.updates : [];
      showSeasons(updates.filter((u) => u.kind === 'season'));
      showNews(updates.filter((u) => u.kind === 'news'));
      showGames(s.games);
      showMessage(s.message);
    } catch (e) { /* offline or no admin brain: the shelf works as normal */ }
  }
  check();
  setInterval(check, POLL_MS);
  document.addEventListener('visibilitychange', () => { if (!document.hidden) check(); });
  window.__live = { check, showMessage, showSeasons, showNews, showGames };
})();
