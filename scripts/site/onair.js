/* IPTVMac home page, "On air": the hero tunes in from analog snow and zaps between four screens of the app, the programme
   guide scrolls sideways, and the ON AIR sign lights up at the end. No dependencies. Everything is an enhancement: without
   this file the hero shows its first screen, the guide is a list and the sign is lit. Reduced motion: no snow, no pinning,
   no automatic zapping; the channel buttons still work. */
(() => {
  "use strict";
  const d = document, H = d.documentElement;
  const $ = (s, r = d) => r.querySelector(s), $$ = (s, r = d) => Array.from(r.querySelectorAll(s));
  const rm = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const pin = matchMedia("(min-width: 1100px) and (min-height: 720px)");
  const clamp = v => (v < 0 ? 0 : v > 1 ? 1 : v);

  // ---- analog snow: grey noise drawn at a low resolution and scaled up, the way a tuner shows no signal ----
  function snow(canvas, w = 160, h = 100) {
    canvas.width = w; canvas.height = h;
    const ctx = canvas.getContext("2d"), img = ctx.createImageData(w, h), px = new Uint32Array(img.data.buffer);
    return () => {
      const band = (performance.now() / 9) % h;   // a darker band rolls down, like a picture that has lost its hold
      for (let y = 0, i = 0; y < h; y++) {
        const dim = Math.abs(y - band) < 6 ? .45 : 1;
        for (let x = 0; x < w; x++, i++) { const v = (Math.random() * 235 * dim) | 0; px[i] = 0xff000000 | (v << 16) | (v << 8) | v; }
      }
      ctx.putImageData(img, 0, 0);
    };
  }
  // runs `draw` every frame while `opacity(t)` (t in ms since start) is above zero, then stops
  function play(canvas, draw, opacity, ms) {
    const t0 = performance.now();
    const step = now => {
      const t = now - t0;
      canvas.style.opacity = t >= ms ? 0 : opacity(t);
      if (t < ms) { draw(); requestAnimationFrame(step); }
    };
    requestAnimationFrame(step);
  }

  // ---- the hero ----
  const tv = $("[data-screen]");
  if (tv) {
    const chans = $$(".ch", tv), btns = $$(".tv-btn", tv), card = $(".tv-card", tv), tvSnow = $("[data-tv-snow]", tv);
    const drawTv = tvSnow && !rm ? snow(tvSnow, 120, 75) : null;
    let current = 0, touched = false;
    const load = () => chans.forEach(ch => { const im = $("img[data-src]", ch); if (im) { im.src = im.dataset.src; im.removeAttribute("data-src"); } });
    const show = i => {
      if (i === current) return;
      current = i;
      chans.forEach((c, k) => c.classList.toggle("on", k === i));
      btns.forEach((b, k) => b.setAttribute("aria-pressed", k === i));
      if (drawTv) play(tvSnow, drawTv, t => 1 - t / 260, 260);   // a short burst of snow between two channels
    };
    btns.forEach((b, k) => b.addEventListener("click", () => { touched = true; load(); show(k); }));

    // tune in once: snow over the page and the screen, the test card for a beat, then the picture locks
    const bg = $("[data-snow]");
    if (!rm) {
      if (bg) play(bg, snow(bg, 200, 120), t => .32 * (1 - t / 1200), 1200);
      if (drawTv) {
        play(tvSnow, drawTv, t => (t < 520 ? 1 : 1 - (t - 520) / 520), 1040);
        if (card) { card.style.opacity = 1; setTimeout(() => { card.style.transition = "opacity .28s"; card.style.opacity = 0; }, 760); }
      }
    }
    addEventListener("load", () => setTimeout(load, 300), { once: true });   // the other channels load after the page, never before the first screen

    // large screens: the hero is pinned and scrolling zaps; small screens: it zaps by itself while in view, until the visitor taps a channel
    const zap = $("#hero-zap");
    if (zap && !rm) {
      const onScroll = () => {
        if (!pin.matches || touched) return;
        const r = zap.getBoundingClientRect(), p = clamp(-r.top / Math.max(1, r.height - innerHeight));
        if (p > 0) load();
        show(Math.min(chans.length - 1, Math.floor(p * chans.length * .999)));
      };
      addEventListener("scroll", onScroll, { passive: true }); onScroll();
      let timer = 0;
      const io = new IntersectionObserver(es => {
        clearInterval(timer);
        if (es[0].isIntersecting && !pin.matches) timer = setInterval(() => { if (touched) return clearInterval(timer); load(); show((current + 1) % chans.length); }, 3200);
      }, { threshold: .5 });
      io.observe(tv);
    }
  }

  // ---- the programme guide: vertical scroll moves the evening sideways; the programme under the "now" line is live ----
  const guide = $(".guide"), track = $(".epg-track"), slots = $$(".slot");
  if (guide && track && !rm) {
    let raf = 0;
    const tick = () => {
      raf = 0;
      if (!pin.matches) { track.style.removeProperty("--x"); slots.forEach(s => s.classList.remove("live")); H.classList.remove("in-guide"); return; }
      const r = guide.getBoundingClientRect(), p = clamp(-r.top / Math.max(1, r.height - innerHeight));
      const travel = Math.abs(slots[slots.length - 1].offsetLeft - slots[0].offsetLeft);   // the last programme ends under the "now" line
      track.style.setProperty("--x", (p * travel).toFixed(1) + "px");
      H.classList.toggle("in-guide", r.top < innerHeight * .5 && r.bottom > innerHeight * .5);   // the chapter rail steps aside while the guide fills the screen
      const nr = $(".epg-now").getBoundingClientRect(), now = H.dir === "rtl" ? nr.right - 4 : nr.left + 4;
      slots.forEach(s => { const b = s.getBoundingClientRect(); s.classList.toggle("live", b.left <= now && b.right > now); });
    };
    const kick = () => { if (!raf) raf = requestAnimationFrame(tick); };
    addEventListener("scroll", kick, { passive: true }); addEventListener("resize", kick); tick();
  }

  // ---- the ON AIR sign lights up when the download buttons come into view ----
  const sign = $(".sign");
  if (sign) {
    if (!("IntersectionObserver" in window)) sign.classList.add("live");
    else new IntersectionObserver(es => sign.classList.toggle("live", es[0].isIntersecting), { threshold: .6 }).observe(sign);
  }
})();
