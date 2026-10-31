// Smooth mode: keeps every 3D game running smoothly on slower screens.
// It watches the frame rate and, if the game is struggling, lowers the
// resolution and slows shadow updates. It also recovers if the graphics
// chip resets (WebGL context lost) instead of leaving a frozen screen.
(function () {
  if (window.SMOOTH) return;
  var KEY = 'oi-games-smooth-level';
  var store = { get: function () { try { return +localStorage.getItem(KEY) || 0; } catch (e) { return 0; } },
                set: function (v) { try { localStorage.setItem(KEY, String(v)); } catch (e) {} } };
  var MAX = 4;

  function toast(msg) {
    try {
      var d = document.createElement('div');
      d.textContent = msg;
      d.style.cssText = 'position:fixed;left:50%;top:10px;transform:translateX(-50%);z-index:99999;' +
        'background:rgba(0,0,0,.72);color:#fff;font:600 13px system-ui,sans-serif;padding:7px 14px;' +
        'border-radius:999px;pointer-events:none;transition:opacity .6s';
      document.body.appendChild(d);
      setTimeout(function () { d.style.opacity = '0'; }, 1800);
      setTimeout(function () { d.remove(); }, 2600);
    } catch (e) {}
  }

  function attach(renderer, opts) {
    opts = opts || {};
    if (!renderer || renderer.__smooth) return;
    renderer.__smooth = true;
    var base = renderer.getPixelRatio ? renderer.getPixelRatio() : (window.devicePixelRatio || 1);
    var hasShadows = !!(renderer.shadowMap && renderer.shadowMap.enabled);
    var level = Math.min(store.get(), MAX);
    var told = false, frame = 0;

    function ratioFor(l) {
      var steps = [base, Math.min(base, 1.25), Math.min(base, 1), Math.min(base, 0.85), Math.min(base, 0.7)];
      return steps[l];
    }
    function apply() {
      try {
        renderer.setPixelRatio(ratioFor(level));
        if (hasShadows) renderer.shadowMap.autoUpdate = level < 3;
        if (opts.onChange) opts.onChange(level, ratioFor(level));
      } catch (e) {}
    }
    apply();

    // Watch the frame rate with our own tiny loop.
    var last = 0, sum = 0, n = 0, settle = 1.5, good = 0;
    function tick(now) {
      requestAnimationFrame(tick);
      frame++;
      if (hasShadows && level >= 3 && frame % 4 === 0) renderer.shadowMap.needsUpdate = true;
      var dt = last ? (now - last) / 1000 : 0;
      last = now;
      if (!dt || dt > 0.25 || document.hidden) return; // paused or tab hidden: ignore
      if (settle > 0) { settle -= dt; return; }
      sum += dt; n++;
      if (sum < 2) return;
      var fps = n / sum;
      sum = 0; n = 0;
      if (fps < 42 && level < MAX) {
        level++; good = 0; settle = 1.5; apply(); store.set(level);
        if (!told && level >= 2) { told = true; toast('⚡ Smooth mode on'); }
      } else if (fps > 58 && level > 0) {
        if (++good >= 4) { level--; good = 0; settle = 1.5; apply(); store.set(level); }
      } else good = 0;
    }
    requestAnimationFrame(tick);

    // If the graphics chip resets, reload the game instead of freezing.
    var canvas = renderer.domElement;
    if (canvas && canvas.addEventListener) {
      var reloading = false;
      var reload = function () { if (reloading) return; reloading = true; location.reload(); };
      canvas.addEventListener('webglcontextlost', function (e) {
        e.preventDefault();
        level = Math.min(MAX, level + 1); store.set(level);
        toast('Fixing the graphics…');
        setTimeout(reload, 2500);
      }, false);
      canvas.addEventListener('webglcontextrestored', reload, false);
    }
  }

  window.SMOOTH = { attach: attach };
})();
