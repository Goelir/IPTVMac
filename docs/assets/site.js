/* IPTVMac site. Source: scripts/site/site.js, copied to docs/assets/site.js by scripts/site/build.py. No dependencies.
   Everything here is an enhancement: the page reads and works without it. Responsibilities:
   theme toggle, copy buttons, chapter scroll progress (CSS variables, plus IPTVDemo.setProgress), the static-fallback interactions
   (speed dial, draggable Picture in Picture window, counter, terminal), the tour dialog, and loading the optional fx/demo modules. */
(() => {
  "use strict";
  const d = document, root = d.documentElement, me = d.getElementById("site-js"), ds = me ? me.dataset : {};
  const lang = ds.lang === "he" ? "he" : "en";
  const rm = matchMedia("(prefers-reduced-motion: reduce)");
  const $ = (s, r) => (r || d).querySelector(s), $$ = (s, r) => [...(r || d).querySelectorAll(s)];
  const clamp = v => (v < 0 ? 0 : v > 1 ? 1 : v);
  const out3 = t => 1 - Math.pow(1 - t, 3);
  const store = { get(k) { try { return localStorage.getItem(k); } catch (e) { return null; } }, set(k, v) { try { localStorage.setItem(k, v); } catch (e) {} } };

  // ---- theme: follows the system until the visitor chooses ----
  const tb = $(".theme"), light = matchMedia("(prefers-color-scheme: light)");
  const mode = () => root.dataset.theme || (light.matches ? "light" : "dark");
  const syncTheme = () => { if (tb) tb.dataset.mode = mode(); };
  if (tb) { syncTheme(); light.addEventListener("change", syncTheme); tb.addEventListener("click", () => { const n = mode() === "light" ? "dark" : "light"; root.dataset.theme = n; store.set("iptvmac-theme", n); syncTheme(); }); }

  // ---- copy buttons (install command, free playlist link) ----
  $$(".copy").forEach(b => {
    const box = b.closest(".cmd, .term, .m3u"), code = $("code", box), say = $("[role=status]", box), lbl = $(".lbl", b), orig = lbl.textContent;
    let t;
    const done = () => { b.classList.add("done"); lbl.textContent = b.dataset.done; if (say) say.textContent = b.dataset.done; clearTimeout(t); t = setTimeout(() => { b.classList.remove("done"); lbl.textContent = orig; if (say) say.textContent = ""; }, 2000); };
    const fallback = () => { const r = d.createRange(); r.selectNodeContents(code); const s = getSelection(); s.removeAllRanges(); s.addRange(r); try { if (d.execCommand("copy")) done(); } catch (e) {} };
    b.addEventListener("click", () => { if (navigator.clipboard && isSecureContext) navigator.clipboard.writeText(code.textContent).then(done, fallback); else fallback(); });
  });

  $$(".hint[hidden]").forEach(h => (h.hidden = false));

  // ---- header, chapter rail ----
  const top = $(".top"), rail = $(".rail"), hero = $(".hero"), finale = $(".finale");
  const onTop = () => top && top.classList.toggle("scrolled", scrollY > 8);
  if (rail && hero && "IntersectionObserver" in window) {
    let past = false, end = false;
    const set = () => rail.classList.toggle("on", past && !end);
    new IntersectionObserver(es => { past = !es[0].isIntersecting && es[0].boundingClientRect.top < 0; set(); }, { rootMargin: "-30% 0px 0px 0px" }).observe(hero);
    if (finale) new IntersectionObserver(es => { end = es[0].isIntersecting; set(); }, { rootMargin: "-20% 0px 0px 0px" }).observe(finale);
    const links = $$("a", rail), ids = links.map(a => a.getAttribute("href").slice(1));
    const act = new IntersectionObserver(es => es.forEach(en => { if (en.isIntersecting) links.forEach((a, i) => a.setAttribute("aria-current", ids[i] === en.target.id ? "true" : "false")); }), { rootMargin: "-45% 0px -45% 0px" });
    ids.forEach(id => { const s = d.getElementById(id); if (s) act.observe(s); });
  }

  // ---- static-fallback interactions ----
  // speed dial: scroll drives it until the visitor touches it
  const chapPlayer = $("#player"), dial = $("#spd");
  let dialTouched = false;
  const setSpeed = v => {
    const s = Math.round(v * 20) / 20, txt = (s % 1 === 0 ? s : +s.toFixed(2)) + "x";
    if (dial) dial.value = s;
    const o = $("#spd-out"), p = $("#spd-pill");
    if (o) o.textContent = txt; if (p) p.textContent = txt;
    if (chapPlayer) chapPlayer.style.setProperty("--spd", s);
  };
  if (dial) { dial.addEventListener("input", () => { dialTouched = true; setSpeed(+dial.value); }); }

  // counter runs to the real number once, when it scrolls into view
  const cn = $("[data-count]");
  if (cn && !rm.matches && "IntersectionObserver" in window) {
    const target = +cn.dataset.count; cn.textContent = "0";
    const io = new IntersectionObserver(es => { if (!es[0].isIntersecting) return; io.disconnect(); const t0 = performance.now(); const tick = now => { const k = clamp((now - t0) / 1700); cn.textContent = Math.round(target * (k < 1 ? 1 - Math.pow(2, -10 * k) : 1)).toLocaleString("en-US"); if (k < 1) requestAnimationFrame(tick); }; requestAnimationFrame(tick); }, { threshold: .6 });
    io.observe(cn);
  }

  // the install terminal types its command when it comes into view
  const term = $("#term");
  if (term && "IntersectionObserver" in window) { const io = new IntersectionObserver(es => { if (es[0].isIntersecting) { term.classList.add("in"); io.disconnect(); } }, { threshold: .4 }); io.observe(term); }

  // Picture in Picture window: drag it, or focus it and use the arrow keys; it stays inside the window frame
  $$("[data-drag]").forEach(el => {
    const wrap = el.closest(".win-wrap"); let x = 0, y = 0, sx = 0, sy = 0, ox = 0, oy = 0, rx = [0, 0], ry = [0, 0];
    const put = () => { el.style.setProperty("--dx", x + "px"); el.style.setProperty("--dy", y + "px"); el.dataset.moved = "1"; };
    const bounds = () => { const w = wrap.getBoundingClientRect(), p = el.getBoundingClientRect(); rx = [w.left - (p.left - x), w.right - p.width - (p.left - x)]; ry = [w.top - (p.top - y), w.bottom - p.height - (p.top - y)]; };
    const lim = (v, r) => Math.min(r[1], Math.max(r[0], v));
    el.addEventListener("pointerdown", ev => { el.setPointerCapture(ev.pointerId); sx = ev.clientX; sy = ev.clientY; ox = x; oy = y; bounds(); el.classList.add("dragging"); });
    el.addEventListener("pointermove", ev => { if (!el.classList.contains("dragging")) return; x = lim(ox + ev.clientX - sx, rx); y = lim(oy + ev.clientY - sy, ry); put(); });
    const end = () => el.classList.remove("dragging");
    el.addEventListener("pointerup", end); el.addEventListener("pointercancel", end);
    el.addEventListener("keydown", ev => {
      const k = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[ev.key]; if (!k) return;
      ev.preventDefault(); bounds(); const s = ev.shiftKey ? 72 : 24; x = lim(x + k[0] * s, rx); y = lim(y + k[1] * s, ry); put();
    });
  });

  // ---- tour video in a native dialog ----
  const tl = $(".tour-link"), dlg = $("#tour");
  if (tl && dlg && dlg.showModal) {
    const v = $("video", dlg);
    tl.addEventListener("click", ev => { ev.preventDefault(); if (!v.poster) v.poster = v.dataset.poster; dlg.showModal(); v.play().catch(() => {}); });
    dlg.addEventListener("close", () => v.pause());
    $(".x", dlg).addEventListener("click", () => dlg.close());
    dlg.addEventListener("click", ev => { if (ev.target === dlg) dlg.close(); });
  }

  // ---- optional modules: fx (motion layer) and demo (interactive app mock). The page is complete without them. ----
  const load = (js, css) => new Promise(res => {
    if (css) { const l = d.createElement("link"); l.rel = "stylesheet"; l.href = css; d.head.appendChild(l); }
    const s = d.createElement("script"); s.src = js; s.async = true; s.onload = () => res(true); s.onerror = () => res(false); d.head.appendChild(s);
  });
  const later = f => { const go = () => (window.requestIdleCallback || setTimeout)(f); d.readyState === "complete" ? go() : addEventListener("load", go); };
  if (ds.fxJs) later(() => load(ds.fxJs, ds.fxCss).then(ok => { if (ok && window.IPTVFX) try { window.IPTVFX.init({ hero, canvas: $("[data-fx-canvas]"), reducedMotion: rm.matches }); } catch (e) {} }));

  const demos = [];
  const mount = (el, host) => {
    try {
      const inst = window.IPTVDemo.mount(el, { lang, reducedMotion: rm.matches, scene: el.dataset.scene });
      if (!inst) return false;
      if (inst.setScene) inst.setScene(el.dataset.scene);
      demos.push({ inst, scene: el.dataset.scene, host });
      if (el.dataset.scene === "languages") wireWall(inst);
      return true;
    } catch (e) { return false; } // the static composition stays
  };
  const mountHost = host => {
    host.classList.add("pending");
    const ok = $$("[data-iptvdemo-mount]", host).map(el => mount(el, host)).some(Boolean);
    host.classList.remove("pending"); if (ok) { host.classList.add("is-live"); tick(); }
  };
  const pushProgress = (dm, p) => { if (dm.inst.setProgress) dm.inst.setProgress(dm.scene, p); else if (window.IPTVDemo && window.IPTVDemo.setProgress) window.IPTVDemo.setProgress(dm.scene, p); };
  if (ds.demoJs) later(() => load(ds.demoJs, ds.demoCss).then(ok => {
    if (!ok || !window.IPTVDemo || !window.IPTVDemo.mount) return;
    const io = new IntersectionObserver(es => es.forEach(en => { if (en.isIntersecting) { io.unobserve(en.target); mountHost(en.target); } }), { rootMargin: "120% 0px" });
    new Set($$("[data-iptvdemo-mount]").map(el => el.closest(".chap, .langs"))).forEach(h => io.observe(h));
  }));

  // language wall: hovering or focusing a language switches the demo's interface language
  function wireWall(inst) {
    if (!inst.setLang) return;
    $$(".wall [data-lang]").forEach(sp => {
      const b = d.createElement("button"); b.type = "button"; b.setAttribute("aria-pressed", "false");
      sp.replaceWith(b); b.appendChild(sp);
      const go = () => { inst.setLang(sp.dataset.lang); $$(".wall .on").forEach(o => o.classList.remove("on")); b.parentNode.classList.add("on"); };
      b.addEventListener("mouseenter", go); b.addEventListener("focus", go); b.addEventListener("click", go);
    });
  }

  // ---- chapter progress: --ch (0..1) on each chapter, --e on the Picture in Picture chapter, IPTVDemo.setProgress ----
  const chaps = $$("[data-chapter], .langs");
  const pin = matchMedia("(min-width: 1280px) and (min-height: 760px)");
  const progress = el => {
    const r = el.getBoundingClientRect(), vh = innerHeight;
    return pin.matches && !rm.matches && el.dataset.chapter ? clamp(-r.top / Math.max(1, r.height - vh)) : clamp((vh - r.top) / (vh + r.height));
  };
  const last = new Map();
  let raf = 0;
  function tick() {
    raf = 0; onTop();
    chaps.forEach(el => {
      const r = el.getBoundingClientRect(); if (r.bottom < -innerHeight || r.top > innerHeight * 2) return;
      const p = progress(el); if (Math.abs((last.get(el) ?? -1) - p) < .002) return; last.set(el, p);
      if (!rm.matches) {
        el.style.setProperty("--ch", p.toFixed(3));
        if (el.id === "pip") el.style.setProperty("--e", out3(clamp(p / .5)).toFixed(3));
        if (el.id === "player" && !dialTouched) setSpeed(Math.pow(2, -2 + 4 * clamp((p - .12) / .76)));
      }
      demos.forEach(dm => { if (dm.host === el) pushProgress(dm, p); });
    });
  }
  const kick = () => { if (!raf) raf = requestAnimationFrame(tick); };
  addEventListener("scroll", kick, { passive: true }); addEventListener("resize", kick); pin.addEventListener("change", () => { last.clear(); kick(); });
  tick();
})();
