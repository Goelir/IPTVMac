/*! IPTVFX 1.0: motion and graphics layer for the IPTVMac site. No dependencies, no network.
    Exposes window.IPTVFX only: init({hero, canvas, reducedMotion, onScene, quality}), destroy(), scan(root), seek(t), state().
    Markup hooks: [data-fx-tilt] [data-depth] [data-fx-magnetic] [data-fx-split] [data-fx-morph] [data-fx-scene] [data-fx-cursor]. */
(() => {
'use strict';
if (window.IPTVFX) return;

const D = document, H = D.documentElement;
const clamp = (v, a = 0, b = 1) => (v < a ? a : v > b ? b : v);
const spring = (s, to, dt, w) => { // critically damped, so it eases in and out without overshoot
  s.v += (w * w * (to - s.x) - 2 * w * s.v) * dt;
  s.x += s.v * dt;
  return Math.abs(to - s.x) > 5e-4 || Math.abs(s.v) > 5e-4;
};
const EASE_OUT = 'cubic-bezier(.16,1,.3,1)', EASE_IN = 'cubic-bezier(.7,0,.84,0)';
const SEL_LINK = 'a,button,[role="button"],summary,label,select,[data-fx-hover]';
const SEL_TEXT = 'textarea,[contenteditable=""],[contenteditable="true"],input:not([type=button],[type=submit],[type=checkbox],[type=radio],[type=range])';
// letters of these scripts are safe to split into characters; Arabic, Hebrew, Indic etc. join or reorder, so they stay whole words
const SAFE_CHARS = /^[\p{Script=Latin}\p{Script=Greek}\p{Script=Cyrillic}\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Hangul}\p{M}\p{N}\p{P}\p{S}]+$/u;
const RTL_SCRIPT = /[֐-ࣿיִ-﷿ﹰ-﻿]/;
const segmenter = typeof Intl !== 'undefined' && Intl.Segmenter ? new Intl.Segmenter(undefined, { granularity: 'grapheme' }) : null;
const graphemes = (s) => (segmenter ? Array.from(segmenter.segment(s), (g) => g.segment) : Array.from(s));

/* ---------------------------------------------------------------- atmosphere shader
   A projector beam through haze, aimed at the hero object: soft volumetric shafts with hairline
   contour filaments (iso-lines of the same noise, kept one pixel wide with fwidth), a backlit bloom,
   a faint reflection pool, two depths of dust, a barely-there anamorphic streak and film grain.
   Output is premultiplied alpha so the page background shows through and the bottom dissolves into it. */
const FRAG = `
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
uniform vec2 uRes, uPtr, uFocus;
uniform float uT, uScroll, uIntro, uLight, uPtrOn, uSide, uInt;

float hs(vec2 p){ vec3 q = fract(vec3(p.xyx) * .1031); q += dot(q, q.yzx + 33.33); return fract((q.x + q.y) * q.z); }
float vn(vec2 p){ vec2 i = floor(p), f = fract(p); f = f*f*(3. - 2.*f);
  return mix(mix(hs(i), hs(i + vec2(1., 0.)), f.x), mix(hs(i + vec2(0., 1.)), hs(i + 1.), f.x), f.y); }
float fbm(vec2 p){ return vn(p)*.55 + vn(p*2.07 + 7.1)*.3 + vn(p*4.3 + 3.7)*.15; }
float ln(float v, float lv, float w){ return 1. - smoothstep(0., w, abs(v - lv)); }

void main(){
  vec2 uv = vec2(gl_FragCoord.x, uRes.y - gl_FragCoord.y) / uRes;
  float asp = uRes.x / uRes.y, t = uT;
  vec2 pt = uPtr * uPtrOn;

  vec2 foc = uFocus + vec2(pt.x*.02, pt.y*.012);
  foc.y -= uScroll*.2;
  vec2 q = (uv - foc) * vec2(asp, 1.);

  // the throw: off-axis source above the frame, aimed at the focus
  vec2 src = vec2(uSide*.42 + pt.x*.06, -.72);
  vec2 dv = normalize(-src);
  vec2 d = q - src;
  float r = length(d);
  float ang = atan(dv.x*d.y - dv.y*d.x, dot(d, dv));
  float a2 = ang + .035*sin(r*2.3 + ang*9. + t*.13) + .02*sin(r*5.1 - t*.09);
  float spread = .27 + .04*sin(t*.09);
  float k1 = a2/spread, k2 = (a2 - .16*sin(t*.05 + 1.)) / (spread*1.7);
  float cone = exp(-k1*k1), cone2 = exp(-k2*k2);

  float rv = vn(vec2(a2*22. + r*.30, t*.06))*.6 + vn(vec2(a2*47. - r*.2, 3. - t*.05))*.4;
  float rs = smoothstep(.22, .95, rv);
  float aw = fwidth(rv)*1.15 + 1e-4;
  float thr = ln(rv, .50, aw)*.45 + ln(rv, .635, aw) + ln(rv, .77, aw)*.7;

  float haze  = fbm(vec2(q.x*1.2 + t*.02, q.y*.9 - t*.035));
  float haze2 = fbm(vec2(q.x*2.6 - t*.03, q.y*1.7 - t*.06) + 11.);
  float fall = 1. / (1. + r*1.1);
  float beam = (cone + cone2*.35) * (.22 + .78*rs) * (.5 + .9*haze) * fall * smoothstep(0., .5, r);
  float fil  = thr * cone * (.3 + .7*haze) * fall * smoothstep(0., .6, r);

  // backlight: the screen is the source, so it blooms around its own silhouette
  vec2 hp = q * vec2(.62, 1.15);
  float hr = dot(hp, hp);
  float halo = (exp(-hr*3.)*.75 + exp(-sqrt(hr)*3.6)*.32) * (.72 + .56*haze2);

  // reflection pool: a dark glass floor catching the beam
  vec2 gp = vec2(q.x*.55, (q.y - .36)*2.8);
  float refl = exp(-dot(gp, gp)*1.2) * (.25 + .75*smoothstep(.2, .8, vn(vec2(q.x*7. + t*.02, q.y*1.5) + 4.)));

  float streak = exp(-abs(q.y - .02)*38.) * exp(-abs(q.x)*1.6) * (.6 + .4*haze);

  // dust at two depths of field, parallaxing against the pointer
  float dust = 0.;
  for (int i = 0; i < 2; i++) {
    float fi = float(i);
    vec2 g = vec2(uv.x*asp, uv.y)*(16. + fi*7.) + vec2(t*.01*(1. + fi) + pt.x*.4*(fi - .5), t*(.09 + .05*fi) + pt.y*.2*(fi - .5));
    vec2 id = floor(g), f = fract(g) - .5;
    float rr = hs(id + fi*13.7);
    vec2 off = (vec2(hs(id + 3.1), hs(id + 8.4)) - .5)*.55;
    float dd = length(f - off);
    float sz = mix(.045, .12, fi), soft = mix(.025, .08, fi);
    dust += (1. - smoothstep(sz - soft*.9, sz + soft, dd)) * step(.84 + fi*.05, rr) * (.55 + .45*sin(t*(.5 + rr*1.1) + rr*40.)) * mix(.6, .28, fi);
  }
  dust *= cone*.9 + halo*.7;

  vec2 pp = (uv - (vec2(.5) + pt*.5)) * vec2(asp, 1.);
  float lens = exp(-dot(pp, pp)*9.) * uPtrOn;

  float vig = 1. - smoothstep(.2, 1.25, length((uv - vec2(.5, .42)) * vec2(.95, 1.2)));
  float fadeB = mix(.2, 1., 1. - smoothstep(.45, 1., uv.y));
  float mask = vig * fadeB * uIntro * uInt * (1. - uScroll*.9);

  float Lf = fil*.5*mask;
  float Ls = (beam*.55 + halo*.36 + refl*.2 + streak*.1 + dust*.55 + lens*.1) * mask;
  float L = Ls + Lf;

  // palette: indigo, logo violet, lilac, pearl, with the icon's blue-to-purple drift
  float hue = clamp(.5 + q.x*.5 + q.y*.2, 0., 1.);
  vec3 c0 = vec3(.045, .035, .17);
  vec3 c1 = mix(vec3(.33, .40, .93), vec3(.50, .30, .89), hue);
  vec3 c2 = mix(vec3(.58, .62, 1.), vec3(.68, .55, 1.), hue);
  vec3 c3 = vec3(.93, .92, 1.);
  float x = clamp(L*1.1, 0., 1.5);
  vec3 col = mix(c0, c1, smoothstep(0., .6, x));
  col = mix(col, c2, smoothstep(.5, 1., x));
  col = mix(col, c3, smoothstep(1.05, 1.5, x));
  col *= smoothstep(0., .1, x) * x * .84;

  // film grain at ~12 fps; it also dithers the dark gradients so they never band
  float gt = floor(t*12.);
  vec2 gc = gl_FragCoord.xy;
  float g = hs(gc + gt*vec2(37.7, 91.3)) + hs(gc*1.37 + gt*vec2(11.1, 53.9)) - 1.;
  float lum = max(col.r, max(col.g, col.b));
  vec3 dc = max(col + g*(.006 + .03*lum), 0.);
  float da = clamp(max(dc.r, max(dc.g, dc.b)), 0., 1.);

  // light theme: violet ink wash with hairlines
  float la = clamp(Ls*.5 + Lf*1.1, 0., .8);
  vec3 lc = mix(vec3(.62, .56, 1.), vec3(.28, .18, .78), smoothstep(.15, .8, L)) * la;
  la = clamp(la + max(g*.012, 0.), 0., 1.);

  vec3 oc = mix(dc, lc, uLight);
  float oa = mix(da, la, uLight);
  gl_FragColor = vec4(min(oc, vec3(oa)), oa);
}`;

const QL = [1, .8, .64, .5, .4]; // resolution scale ladder for adaptive quality
const MAX_PIXELS = 2.4e6;
const STILL_T = 11.5; // the frame shown under reduced motion

let C = null; // live context (null when not initialised)

function init(o = {}) {
  destroy();
  const off = [], drivers = [], onRM = [];
  const rmq = matchMedia('(prefers-reduced-motion: reduce)');
  const fineq = matchMedia('(hover: hover) and (pointer: fine)');
  const lightq = matchMedia('(prefers-color-scheme: light)');
  const x = (C = {
    dead: false, raf: 0, last: 0, sd: true, mode: 'off', off, seen: new WeakSet(),
    rm: !!o.reducedMotion || rmq.matches, fine: fineq.matches,
    ptr: { x: 0, y: 0, has: false, dirty: false },
    state: () => ({ mode: x.mode }),
  });
  const on = (t, ev, fn, opt) => { t.addEventListener(ev, fn, opt); off.push(() => t.removeEventListener(ev, fn, opt)); };
  const watch = (Ctor, cb, opt) => { const w = new Ctor(cb, opt); off.push(() => w.disconnect()); return w; };
  const setMode = (m) => { x.mode = m; H.setAttribute('data-fx', m); };
  const setVar = (el, k, v) => el.style.setProperty(k, v);
  const tidy = (el) => { for (const a of ['class', 'style']) if (el.getAttribute(a) === '') el.removeAttribute(a); }; // leave no empty attributes behind

  /* ------------------------------------------------ frame loop: all reads, then all writes, only while something moves */
  const wake = (x.wake = () => { if (!x.raf && !x.dead) x.raf = requestAnimationFrame(tick); });
  function tick(now) {
    x.raf = 0;
    if (x.dead) return;
    const dt = x.last ? Math.min((now - x.last) / 1000, .05) : .016;
    x.last = now;
    for (const d of drivers) d.read && d.read(now, dt);
    for (const d of drivers) d.write && d.write(now, dt);
    x.ptr.dirty = x.sd = false;
    if (drivers.some((d) => d.busy)) x.raf = requestAnimationFrame(tick);
    else x.last = 0;
  }
  off.push(() => cancelAnimationFrame(x.raf));

  const ptr = x.ptr;
  on(window, 'pointermove', (e) => {
    if (e.pointerType === 'touch') return;
    ptr.x = e.clientX; ptr.y = e.clientY; ptr.has = ptr.dirty = true; wake();
  }, { passive: true });
  const gone = () => { ptr.has = false; ptr.dirty = true; wake(); };
  on(H, 'pointerleave', gone);
  on(window, 'blur', gone);
  on(window, 'scroll', () => { x.sd = true; wake(); }, { passive: true });
  on(window, 'resize', () => { x.sd = x.rs = true; wake(); });
  const setRM = () => {
    x.rm = !!o.reducedMotion || rmq.matches;
    H.classList.toggle('fx-rm', x.rm);
    onRM.forEach((f) => f());
    wake();
  };
  H.classList.toggle('fx-rm', x.rm);
  on(rmq, 'change', setRM);
  on(fineq, 'change', () => { x.fine = fineq.matches; onRM.forEach((f) => f()); wake(); });

  /* ------------------------------------------------ hero atmosphere */
  function atmosphere() {
    const hero = o.hero || (o.canvas && o.canvas.parentElement);
    if (!hero) return setMode('off');
    let cv = o.canvas;
    const own = !cv, heroPos = hero.style.position;
    if (own) { cv = D.createElement('canvas'); hero.insertBefore(cv, hero.firstChild); }
    const prevHidden = cv.getAttribute('aria-hidden');
    cv.classList.add('fx-canvas');
    cv.setAttribute('aria-hidden', 'true');
    hero.setAttribute('data-fx-hero', '');
    if (own && getComputedStyle(hero).position === 'static') hero.style.position = 'relative';
    let fb = null; // CSS-painted stand-in, used while WebGL is unavailable (a lost-context canvas would paint an opaque placeholder)
    const css = () => {
      if (!fb) { fb = D.createElement('div'); fb.className = 'fx-canvas fx-css'; fb.setAttribute('aria-hidden', 'true'); cv.after(fb); }
      cv.hidden = true; setMode('css');
    };
    const webgl = () => { if (fb) fb.remove(); fb = null; cv.hidden = false; setMode('webgl'); };
    off.push(() => {
      if (fb) fb.remove();
      cv.hidden = false; cv.removeAttribute('hidden');
      hero.removeAttribute('data-fx-hero'); hero.style.position = heroPos; tidy(hero);
      cv.classList.remove('fx-canvas', 'fx-ready');
      if (prevHidden === null) cv.removeAttribute('aria-hidden'); else cv.setAttribute('aria-hidden', prevHidden);
      tidy(cv);
      if (own) { gl && gl.getExtension('WEBGL_lose_context') && gl.getExtension('WEBGL_lose_context').loseContext(); cv.remove(); }
    });

    let gl, prog, buf, u, lost = false, software = false;
    const attrs = { alpha: true, premultipliedAlpha: true, antialias: false, depth: false, stencil: false, powerPreference: 'low-power' };
    const build = () => {
      gl = cv.getContext('webgl', attrs) || cv.getContext('experimental-webgl', attrs);
      if (!gl || gl.isContextLost()) return false;
      const dx = gl.getExtension('OES_standard_derivatives');
      const sh = (type, src) => { const s = gl.createShader(type); gl.shaderSource(s, src); gl.compileShader(s); return s; };
      const vs = sh(gl.VERTEX_SHADER, 'attribute vec2 a;void main(){gl_Position=vec4(a,0.,1.);}');
      const fs = sh(gl.FRAGMENT_SHADER, (dx ? '#extension GL_OES_standard_derivatives : enable\n' : '#define fwidth(v) .02\n') + FRAG);
      prog = gl.createProgram();
      gl.attachShader(prog, vs); gl.attachShader(prog, fs); gl.linkProgram(prog);
      gl.deleteShader(vs); gl.deleteShader(fs);
      if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) return false;
      gl.useProgram(prog);
      buf = gl.createBuffer();
      gl.bindBuffer(gl.ARRAY_BUFFER, buf);
      gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 3, -1, -1, 3]), gl.STATIC_DRAW); // one full-screen triangle
      const a = gl.getAttribLocation(prog, 'a');
      gl.enableVertexAttribArray(a); gl.vertexAttribPointer(a, 2, gl.FLOAT, false, 0, 0);
      u = {};
      for (const n of ['uRes', 'uPtr', 'uFocus', 'uT', 'uScroll', 'uIntro', 'uLight', 'uPtrOn', 'uSide', 'uInt']) u[n] = gl.getUniformLocation(prog, n);
      try {
        const soft = /swiftshader|llvmpipe|software|softpipe/i;
        const ri = navigator.userAgentData && gl.getExtension('WEBGL_debug_renderer_info'); // Chromium only: other engines expose the name directly and warn about the extension
        software = soft.test(gl.getParameter(gl.RENDERER)) || (!!ri && soft.test(gl.getParameter(ri.UNMASKED_RENDERER_WEBGL)));
      } catch (e) { /* renderer string is optional */ }
      return true;
    };
    off.push(() => {
      if (!gl || gl.isContextLost()) return;
      gl.deleteBuffer(buf); gl.deleteProgram(prog);
    });
    if (!build()) return css();
    setMode('webgl');

    // adaptive quality: resolution ladder, driven by measured frame pacing
    let q = Number.isInteger(o.quality) ? clamp(o.quality, 0, QL.length - 1) : software ? 3 : matchMedia('(pointer: coarse)').matches ? 1 : 0;
    const fails = QL.map(() => 0);
    let cw = cv.clientWidth, ch = cv.clientHeight, W = 2, Hh = 2, scale = 1, sizeDirty = true;
    let heroVis = true, ready = false, still = x.rm, dirty = true, hold = false;
    let T = 0, introT = 0, lastDraw = 0, ema = 0, frames = 0, good = 0, rect = null;
    let fx = .5, fy = .42, focusDirty = true, sp = 0;
    const px = { x: 0, v: 0 }, py = { x: 0, v: 0 }, pon = { x: 0, v: 0 }, lt = { x: 0, v: 0 };
    const theme = () => { const t = H.getAttribute('data-theme'); return t === 'light' ? 1 : t === 'dark' ? 0 : lightq.matches ? 1 : 0; };
    let ltTarget = theme();
    lt.x = ltTarget;
    const inten = parseFloat(hero.dataset.fxIntensity) || 1;
    const sideAttr = parseFloat(hero.dataset.fxBeam);
    const side = () => (isNaN(sideAttr) ? (getComputedStyle(hero).direction === 'rtl' ? 1 : -1) : clamp(sideAttr, -1, 1));
    let sideV = side();

    const mo = watch(MutationObserver, () => { ltTarget = theme(); dirty = true; wake(); });
    mo.observe(H, { attributes: true, attributeFilter: ['data-theme'] });
    on(lightq, 'change', () => { ltTarget = theme(); dirty = true; wake(); });
    watch(ResizeObserver, (es) => {
      const r = es[es.length - 1].contentRect; cw = r.width; ch = r.height; sizeDirty = focusDirty = true; sideV = side(); wake();
    }).observe(cv);
    watch(IntersectionObserver, (es) => {
      heroVis = es[es.length - 1].isIntersecting; lastDraw = 0; frames = Math.min(frames, 30); focusDirty = true; wake();
    }, { rootMargin: '80px' }).observe(hero);
    on(D, 'visibilitychange', () => { lastDraw = 0; wake(); });
    on(cv, 'webglcontextlost', (e) => { e.preventDefault(); lost = true; css(); });
    on(cv, 'webglcontextrestored', () => {
      lost = false; lastDraw = 0; frames = 0; ema = 0;
      if (build()) { webgl(); sizeDirty = dirty = true; wake(); } else { lost = true; css(); }
    });
    if (D.fonts && D.fonts.ready) D.fonts.ready.then(() => { focusDirty = true; wake(); });
    on(window, 'load', () => { focusDirty = true; wake(); });
    onRM.push(() => { still = x.rm; dirty = true; if (x.rm) { T = STILL_T; introT = 9; } });

    const resize = () => {
      let s = Math.min(devicePixelRatio || 1, 1.5) * QL[q]; // DPR capped at 1.5
      const n = cw * ch * s * s;
      if (n > MAX_PIXELS) s *= Math.sqrt(MAX_PIXELS / n);
      W = Math.max(2, Math.round(cw * s)); Hh = Math.max(2, Math.round(ch * s)); scale = s;
      if (cv.width !== W) cv.width = W;
      if (cv.height !== Hh) cv.height = Hh;
      gl.viewport(0, 0, W, Hh);
      sizeDirty = false; dirty = true;
    };
    const setQ = (n) => { q = n; frames = 0; ema = 0; good = 0; sizeDirty = true; };
    const findFocus = () => {
      const hr = hero.getBoundingClientRect(), obj = hero.querySelector('[data-fx-tilt]');
      if (obj && hr.width) {
        const r = obj.getBoundingClientRect();
        fx = clamp((r.left + r.width / 2 - hr.left) / hr.width); fy = clamp((r.top + r.height * .42 - hr.top) / hr.height);
      } else if (hero.dataset.fxFocus) {
        const f = hero.dataset.fxFocus.split(/[\s,]+/).map(parseFloat);
        fx = clamp(f[0]); fy = clamp(f[1]);
      }
      focusDirty = false;
    };
    const draw = () => {
      gl.uniform2f(u.uRes, W, Hh); gl.uniform1f(u.uT, T);
      gl.uniform2f(u.uPtr, px.x, py.x); gl.uniform2f(u.uFocus, fx, fy);
      gl.uniform1f(u.uScroll, sp); gl.uniform1f(u.uIntro, 1 - Math.pow(1 - clamp(introT / 2.6), 3));
      gl.uniform1f(u.uLight, lt.x); gl.uniform1f(u.uPtrOn, clamp(pon.x)); gl.uniform1f(u.uSide, sideV); gl.uniform1f(u.uInt, inten);
      gl.drawArrays(gl.TRIANGLES, 0, 3);
      dirty = false;
      if (!ready) { ready = true; cv.classList.add('fx-ready'); }
    };
    const perf = () => { // measured over drawn frames, so the 60 fps cap and slow displays are not mistaken for load
      if (++frames < 45) return;
      if (ema > 24) {
        if (q < QL.length - 1) { fails[q]++; setQ(q + 1); } else if (ema > 42) still = true; // last resort: a single frame
      } else if (ema < 18 && q > 0 && fails[q - 1] < 2) { if (++good > 400) setQ(q - 1); } else good = 0;
    };
    x.seek = (t, h = true) => { T = t; hold = h; introT = 9; dirty = true; wake(); };
    x.state = () => ({
      mode: x.mode, quality: q, scale: +scale.toFixed(3), dpr: Math.min(devicePixelRatio || 1, 1.5), width: W, height: Hh,
      fps: ema ? Math.round(1000 / ema) : 0, running: !still && heroVis && !D.hidden && !lost, still, reducedMotion: x.rm,
      software, theme: lt.x > .5 ? 'light' : 'dark', lost,
    });
    if (x.rm) { T = STILL_T; introT = 9; }

    drivers.push({
      busy: false,
      read() {
        if (lost || (still && !dirty && !sizeDirty && !focusDirty)) return;
        if (!heroVis || D.hidden || !cw) return;
        rect = hero.getBoundingClientRect();
        if (focusDirty) findFocus();
      },
      write(now) {
        const d = this;
        d.busy = false;
        if (lost || !heroVis || D.hidden || !cw || !rect) return;
        if (sizeDirty) resize();
        if (still) { // reduced motion / last-resort: draw only when something changed
          if (dirty || Math.abs(lt.x - ltTarget) > .002) { lt.x = ltTarget; draw(); }
          return;
        }
        if (now - lastDraw < 9) { d.busy = true; return; } // cap at ~110 fps (120 Hz screens render every other frame)
        const dd = lastDraw ? now - lastDraw : 0;
        const ds = clamp(dd / 1000 || .016, 0, .1);
        lastDraw = now;
        if (dd) { ema = ema ? ema + (dd - ema) * .08 : dd; perf(); }
        if (!hold) T += ds;
        introT += ds;
        sp = clamp(-rect.top / Math.max(rect.height * .9, 1));
        let tx = 0, ty = 0, tOn = 0;
        if (x.fine && ptr.has) {
          tx = clamp((ptr.x - rect.left) / rect.width * 2 - 1, -1, 1); ty = clamp((ptr.y - rect.top) / rect.height * 2 - 1, -1, 1);
          tOn = Math.abs((ptr.x - rect.left) / rect.width * 2 - 1) < 1.1 && Math.abs((ptr.y - rect.top) / rect.height * 2 - 1) < 1.1 ? 1 : 0;
        } else if (!x.fine) { // touch: a slow autonomous drift instead of a pointer
          tx = Math.sin(T * .09) * .55; ty = Math.cos(T * .07) * .35; tOn = .7;
        }
        spring(px, tx, ds, 3); spring(py, ty, ds, 3); spring(pon, tOn, ds, 2.4);
        lt.x += (ltTarget - lt.x) * (1 - Math.exp(-ds * 5));
        draw();
        d.busy = true;
      },
    });
    wake();
  }
  atmosphere();

  /* ------------------------------------------------ tilt + parallax (fine pointers; gentle drift on touch) */
  function tilt(el) {
    const max = parseFloat(el.getAttribute('data-fx-tilt')) || 7;
    const e = { el, vis: false, tx: 0, ty: 0, sx: { x: 0, v: 0 }, sy: { x: 0, v: 0 }, ph: (x.n = (x.n || 0) + 2.1), busy: false, on: false };
    for (const l of el.querySelectorAll('[data-depth]')) setVar(l, '--d', parseFloat(l.getAttribute('data-depth')) || 0);
    const set = (mx, my) => {
      setVar(el, '--fx-mx', mx.toFixed(4)); setVar(el, '--fx-my', my.toFixed(4));
      setVar(el, '--fx-rx', (-my * max * .8).toFixed(3) + 'deg'); setVar(el, '--fx-ry', (mx * max).toFixed(3) + 'deg');
      setVar(el, '--fx-a', clamp(Math.hypot(mx, my)).toFixed(3));
      setVar(el, '--fx-lx', (50 + mx * 50).toFixed(1) + '%'); setVar(el, '--fx-ly', (50 + my * 50).toFixed(1) + '%');
    };
    const reset = () => { e.sx.x = e.sx.y = e.sx.v = e.sy.v = e.tx = e.ty = 0; ['--fx-mx', '--fx-my', '--fx-rx', '--fx-ry', '--fx-a', '--fx-lx', '--fx-ly'].forEach((k) => el.style.removeProperty(k)); };
    onRM.push(() => { if (x.rm) reset(); });
    off.push(() => { reset(); el.classList.remove('fx-live'); tidy(el); for (const l of el.querySelectorAll('[data-depth]')) { l.style.removeProperty('--d'); tidy(l); } });
    const io = watch(IntersectionObserver, (es) => { e.vis = es[es.length - 1].isIntersecting; el.classList.toggle('fx-live', e.vis && !x.rm); wake(); });
    io.observe(el);
    drivers.push({
      busy: false,
      read(now) {
        if (!e.vis || x.rm) return;
        if (x.fine) {
          if (ptr.dirty || x.sd) {
            if (!ptr.has) { e.tx = e.ty = 0; return; }
            const r = el.getBoundingClientRect();
            if (!r.width) return;
            const k = Math.max(r.width, 420);
            e.tx = Math.tanh((ptr.x - r.left - r.width / 2) / k * 1.5); e.ty = Math.tanh((ptr.y - r.top - r.height / 2) / (k * .75) * 1.5);
          }
        } else { e.tx = Math.sin(now / 1000 * .33 + e.ph) * .55; e.ty = Math.cos(now / 1000 * .26 + e.ph) * .35; }
      },
      write(now, dt) {
        const d = this;
        if (!e.vis || x.rm) { d.busy = false; return; }
        const m = spring(e.sx, e.tx, dt, 9), n = spring(e.sy, e.ty, dt, 9);
        set(e.sx.x, e.sy.x);
        d.busy = m || n || !x.fine;
      },
    });
    wake();
  }

  /* ------------------------------------------------ magnetic buttons */
  function magnetic(el) {
    const k = parseFloat(el.getAttribute('data-fx-magnetic')) || .32;
    const e = { vis: false, tx: 0, ty: 0, sx: { x: 0, v: 0 }, sy: { x: 0, v: 0 } };
    const reset = () => { e.sx.x = e.sx.v = e.sy.x = e.sy.v = e.tx = e.ty = 0; el.style.removeProperty('--fx-tx'); el.style.removeProperty('--fx-ty'); };
    onRM.push(() => { if (x.rm || !x.fine) reset(); });
    off.push(() => { reset(); tidy(el); });
    watch(IntersectionObserver, (es) => { e.vis = es[es.length - 1].isIntersecting; }).observe(el);
    drivers.push({
      busy: false,
      read() {
        if (!e.vis || x.rm || !x.fine) return;
        if (!ptr.has) { e.tx = e.ty = 0; return; }
        if (!ptr.dirty && !x.sd) return;
        const r = el.getBoundingClientRect(); // includes our own offset, so take it back out
        const cx = r.left + r.width / 2 - e.sx.x, cy = r.top + r.height / 2 - e.sy.x;
        const dx = ptr.x - cx, dy = ptr.y - cy, reach = Math.max(r.width, r.height) * .5 + 56;
        if (Math.hypot(dx, dy) < reach) { e.tx = clamp(dx * k, -24, 24); e.ty = clamp(dy * k, -24, 24); } else e.tx = e.ty = 0;
      },
      write(now, dt) {
        const d = this;
        if (!e.vis || x.rm || !x.fine) { d.busy = false; return; }
        const m = spring(e.sx, e.tx, dt, 11), n = spring(e.sy, e.ty, dt, 11);
        if (m || n || e.on) { setVar(el, '--fx-tx', e.sx.x.toFixed(2) + 'px'); setVar(el, '--fx-ty', e.sy.x.toFixed(2) + 'px'); }
        e.on = m || n;
        d.busy = m || n;
      },
    });
  }

  /* ------------------------------------------------ split text: accessible mask reveal */
  const revealIO = () => (revealIO.io ||= watch(IntersectionObserver, (es) => {
    for (const en of es) if (en.isIntersecting) { en.target.classList.add('fx-in'); revealIO.io.unobserve(en.target); }
  }, { rootMargin: '0px 0px -8% 0px' }));
  function split(el) {
    const mode = ({ chars: 'chars', lines: 'lines' })[el.getAttribute('data-fx-split')] || 'words';
    const saved = el.innerHTML, prevLabel = el.getAttribute('aria-label');
    const label = el.textContent.replace(/\s+/g, ' ').trim();
    const dir = getComputedStyle(el).direction;
    const units = [];
    let n = 0;
    const unit = (child) => {
      const w = D.createElement('span'), i = D.createElement('span');
      w.className = 'fx-w'; i.className = 'fx-wi'; i.dir = 'auto'; w.append(i); // each unit takes its own direction from its text
      i.append(child); setVar(w, '--i', n++); units.push(w);
      return w;
    };
    const word = (s, whole) => {
      if (mode === 'chars' && !whole && SAFE_CHARS.test(s)) {
        const wd = D.createElement('span');
        wd.className = 'fx-wd'; wd.dir = 'ltr'; wd.setAttribute('aria-hidden', 'true'); // these scripts are all left-to-right
        for (const g of graphemes(s)) wd.append(unit(g));
        return wd;
      }
      const w = unit(s);
      w.setAttribute('aria-hidden', 'true');
      return w;
    };
    const text = (data) => {
      const f = D.createDocumentFragment();
      // a run in the other direction (Hebrew inside an English heading and vice versa) stays one unit so bidi order is untouched
      if (RTL_SCRIPT.test(data) !== (dir === 'rtl')) {
        const m = data.match(/^(\s*)([\s\S]*?)(\s*)$/);
        if (m[1]) f.append(m[1]);
        if (m[2]) f.append(word(m[2], true));
        if (m[3]) f.append(m[3]);
        return f;
      }
      for (const part of data.split(/(\s+)/)) if (part) f.append(/^\s+$/.test(part) ? D.createTextNode(part) : word(part));
      return f;
    };
    const walk = (node) => {
      for (const c of Array.from(node.childNodes)) {
        if (c.nodeType === 3) { if (c.data.trim()) c.replaceWith(text(c.data)); }
        else if (c.nodeType === 1) {
          if (c.hasAttribute('data-fx-morph') || c.hasAttribute('data-fx-keep')) { // keep intact, but reveal with its neighbours
            const w = unit(D.createDocumentFragment());
            c.replaceWith(w); w.firstChild.append(c); w.setAttribute('aria-hidden', 'true');
          } else if (!/^(BR|SVG|IMG|SCRIPT|STYLE|CANVAS|VIDEO)$/i.test(c.tagName)) walk(c);
        }
      }
    };
    walk(el);
    // headings, links and buttons take their name from aria-label; other elements get a visually hidden copy
    const named = /^(H[1-6]|A|BUTTON)$/.test(el.tagName) || el.hasAttribute('role');
    if (named) { if (prevLabel === null) el.setAttribute('aria-label', label); }
    else { const sr = D.createElement('span'); sr.className = 'fx-sr'; sr.textContent = label; el.prepend(sr); }
    const step = { chars: 24, lines: 120, words: 55 }[mode];
    setVar(el, '--fx-step', (parseFloat(el.getAttribute('data-fx-step')) || step) + 'ms');
    if (el.hasAttribute('data-fx-delay')) setVar(el, '--fx-delay', parseFloat(el.getAttribute('data-fx-delay')) + 'ms');
    const lines = () => { // line index per unit, for 'lines' mode; re-measured when the width changes
      let top = null, li = -1;
      for (const u of units) { const t = u.offsetTop; if (top === null || Math.abs(t - top) > 2) { li++; top = t; } setVar(u, '--i', li); }
    };
    el.classList.add('fx-split-ready'); // before any layout read, so the units never get a style without the hidden state (that would start a transition)
    if (mode === 'lines') {
      lines();
      let wd = el.offsetWidth;
      watch(ResizeObserver, () => { if (el.offsetWidth !== wd) { wd = el.offsetWidth; lines(); } }).observe(el);
      D.fonts && D.fonts.ready.then(() => !x.dead && lines());
    }
    revealIO().observe(el);
    off.push(() => {
      el.innerHTML = saved;
      el.classList.remove('fx-split-ready', 'fx-in');
      for (const k of ['--fx-step', '--fx-delay']) el.style.removeProperty(k);
      if (prevLabel === null) el.removeAttribute('aria-label');
      tidy(el);
    });
  }

  /* ------------------------------------------------ language-morphing word */
  function morph(el) {
    let words;
    try { words = JSON.parse(el.getAttribute('data-words')); } catch (e) { return; }
    if (!Array.isArray(words) || words.length < 2) return;
    words = words.map((w) => (Array.isArray(w) ? w : [String(w), '']));
    const saved = el.innerHTML, first = el.textContent.trim();
    const interval = parseFloat(el.getAttribute('data-interval')) || 2400;
    const loops = el.hasAttribute('data-loops') ? parseInt(el.getAttribute('data-loops'), 10) : 2; // 0 = never stop
    const layer = (txt, lang) => {
      const l = D.createElement('span');
      l.className = 'fx-ml'; l.dir = RTL_SCRIPT.test(txt) ? 'rtl' : 'ltr'; l.setAttribute('aria-hidden', 'true');
      if (lang) l.lang = lang;
      if (SAFE_CHARS.test(txt) && txt.length < 28) for (const g of graphemes(txt)) { const s = D.createElement('span'); s.className = 'fx-g'; s.textContent = g; l.append(s); }
      else { const s = D.createElement('span'); s.className = 'fx-g'; s.textContent = txt; l.append(s); }
      return l;
    };
    const sr = D.createElement('span');
    sr.className = 'fx-sr'; sr.textContent = first; // assistive tech keeps the original word
    let cur = layer(first, '');
    el.classList.add('fx-m'); el.textContent = ''; el.append(sr, cur);
    let idx = words.findIndex((w) => w[0] === first), laps = 0, timer = 0, vis = false, paused = false, busy = false, anims = [];
    const stopped = () => loops > 0 && laps >= loops;
    const can = () => !x.dead && !x.rm && vis && !paused && !busy && !D.hidden && !stopped();
    const sched = () => { clearTimeout(timer); if (can()) timer = setTimeout(step, interval); };
    const swap = (w) => new Promise((done) => {
      const old = cur, nl = layer(w[0], w[1]);
      const w0 = old.offsetWidth;
      el.append(nl);
      const w1 = nl.offsetWidth;
      busy = true; el.style.width = w0 + 'px'; old.classList.add('fx-out');
      anims = [];
      if (w0 !== w1) anims.push(el.animate({ width: [w0 + 'px', w1 + 'px'] }, { duration: 760, easing: EASE_OUT }));
      Array.from(old.children).forEach((g, i) => anims.push(g.animate(
        [{ transform: 'translateY(0)', opacity: 1 }, { transform: 'translateY(-125%)', opacity: 0 }],
        { duration: 380, delay: Math.min(i * 22, 220), easing: EASE_IN, fill: 'forwards' })));
      Array.from(nl.children).forEach((g, i) => anims.push(g.animate(
        [{ transform: 'translateY(125%)', opacity: 0 }, { transform: 'translateY(0)', opacity: 1 }],
        { duration: 760, delay: 150 + Math.min(i * 28, 280), easing: EASE_OUT, fill: 'both' })));
      Promise.all(anims.map((a) => a.finished)).then(() => {
        old.remove(); el.style.width = ''; cur = nl; busy = false; anims = [];
        done();
      }, () => done());
    });
    const step = () => {
      if (!can()) return;
      idx = (idx + 1) % words.length;
      if (idx === 0) laps++;
      swap(words[idx]).then(() => !x.dead && sched());
    };
    const scope = el.closest('[data-fx-morph-scope],h1,h2,h3,h4,h5,h6,p') || el;
    const hold = (v) => () => { paused = v; v ? clearTimeout(timer) : sched(); };
    on(scope, 'pointerenter', hold(true)); on(scope, 'pointerleave', hold(false));
    on(scope, 'focusin', hold(true)); on(scope, 'focusout', hold(false));
    on(D, 'visibilitychange', sched);
    onRM.push(sched);
    watch(IntersectionObserver, (es) => { vis = es[es.length - 1].isIntersecting; sched(); }).observe(el);
    off.push(() => {
      clearTimeout(timer); anims.forEach((a) => a.cancel());
      el.classList.remove('fx-m'); el.style.width = ''; el.innerHTML = saved; tidy(el);
    });
  }

  /* ------------------------------------------------ scenes: --p, --pin, --in per [data-fx-scene] */
  const scenes = new Map(), vis = new Set(), pend = new Set();
  let sceneIO;
  function scene(el) {
    scenes.set(el, { p: -1, pin: -1, inn: -1 });
    pend.add(el);
    (sceneIO ||= watch(IntersectionObserver, (es) => {
      for (const en of es) {
        const s = scenes.get(en.target), v = en.isIntersecting ? 1 : 0;
        v ? vis.add(en.target) : vis.delete(en.target);
        pend.add(en.target); // a final read when it leaves, so p lands exactly on 0 or 1
        if (s.inn !== v) { s.inn = v; setVar(en.target, '--in', v); }
      }
      x.sd = true; wake();
    })).observe(el);
    off.push(() => { for (const k of ['--p', '--pin', '--in']) el.style.removeProperty(k); tidy(el); scenes.delete(el); vis.delete(el); pend.delete(el); });
    wake();
  }
  const out = [];
  drivers.push({
    busy: false,
    read() {
      out.length = 0;
      if (!scenes.size || (!x.sd && !pend.size)) return;
      if (x.rs) { for (const el of scenes.keys()) pend.add(el); x.rs = false; } // geometry changed: measure everything once
      const vh = innerHeight, sy = scrollY;
      for (const [el, s] of scenes) {
        let top, h;
        if (vis.has(el) || pend.has(el)) { // on screen (or just left): the single layout read per scene
          const r = el.getBoundingClientRect();
          top = r.top; h = r.height; s.abs = top + sy; s.h = h;
        } else if (s.h !== undefined) { top = s.abs - sy; h = s.h; } // off screen: plain arithmetic on the last measured position
        else continue;
        const p = clamp((vh - top) / (vh + h));
        out.push([el, p, h > vh ? clamp(-top / (h - vh)) : p]);
      }
      pend.clear();
    },
    write() {
      const moved = (a, b) => Math.abs(a - b) > 5e-4 || (a !== b && (a === 0 || a === 1)); // always land exactly on 0 and 1
      for (const [el, p, pin] of out) {
        const s = scenes.get(el);
        if (!s) continue;
        const a = moved(p, s.p), b = moved(pin, s.pin);
        if (a) { s.p = p; setVar(el, '--p', p.toFixed(4)); }
        if (b) { s.pin = pin; setVar(el, '--pin', pin.toFixed(4)); }
        if ((a || b) && o.onScene) { try { o.onScene(el, { p: s.p, pin: s.pin, in: s.inn }); } catch (err) { console.error(err); } } // a throwing callback must not stop the loop
      }
    },
  });

  /* ------------------------------------------------ optional cursor follower */
  function cursor(host) {
    if (!x.fine) return;
    const root = D.createElement('div');
    root.className = 'fx-cursor'; root.setAttribute('aria-hidden', 'true');
    root.innerHTML = '<i class="fx-cursor-ring"></i><i class="fx-cursor-dot"></i>';
    D.body.append(root);
    const ring = root.firstChild, dot = root.lastChild;
    const replace = host.getAttribute('data-fx-cursor') === 'replace'; // opt-in: also hide the system cursor, while a mouse is in use
    const rx = { x: 0, v: 0 }, ry = { x: 0, v: 0 };
    let shown = false;
    const hide = () => { shown = false; H.classList.remove('fx-cursor-on', 'fx-cursor-hide'); };
    on(window, 'pointermove', (e) => {
      if (e.pointerType !== 'mouse') return hide();
      if (!shown) { shown = true; rx.x = e.clientX; ry.x = e.clientY; rx.v = ry.v = 0; H.classList.add('fx-cursor-on'); }
      if (replace) H.classList.add('fx-cursor-hide');
    }, { passive: true });
    on(D, 'pointerover', (e) => {
      const t = e.target;
      root.classList.toggle('is-link', !!(t.closest && t.closest(SEL_LINK)));
      root.classList.toggle('is-text', !!(t.closest && t.closest(SEL_TEXT)));
    });
    on(D, 'pointerdown', (e) => { if (e.pointerType !== 'mouse') hide(); root.classList.add('is-down'); });
    on(D, 'pointerup', () => root.classList.remove('is-down'));
    on(D, 'keydown', () => H.classList.remove('fx-cursor-hide')); // keyboard users always get the system cursor back
    on(H, 'pointerleave', hide);
    drivers.push({
      busy: false,
      write(now, dt) {
        if (!shown) { this.busy = false; return; }
        const m = spring(rx, ptr.x, dt, x.rm ? 60 : 17), n = spring(ry, ptr.y, dt, x.rm ? 60 : 17);
        dot.style.transform = `translate3d(${ptr.x}px,${ptr.y}px,0)`;
        ring.style.transform = `translate3d(${rx.x.toFixed(1)}px,${ry.x.toFixed(1)}px,0)`;
        this.busy = m || n || ptr.dirty;
      },
    });
    off.push(() => { hide(); root.remove(); });
  }

  /* ------------------------------------------------ scan: wire up everything in the DOM (also callable later) */
  const API = {
    scan(root = D) {
      const fresh = (sel, fn) => { for (const el of root.querySelectorAll(sel)) if (!x.seen.has(el)) { x.seen.add(el); fn(el); } };
      fresh('[data-fx-split]', split);
      fresh('[data-fx-morph]', morph);
      fresh('[data-fx-tilt]', tilt);
      fresh('[data-fx-magnetic]', magnetic);
      fresh('[data-fx-scene]', scene);
      if (!x.cursor && root.querySelector('[data-fx-cursor]')) { x.cursor = 1; cursor(root.querySelector('[data-fx-cursor]')); }
      H.classList.remove('fx-pending');
      wake();
    },
  };
  x.scan = API.scan;
  API.scan();
  return IPTVFX;
}

function destroy() {
  if (!C) return;
  const x = C;
  C = null;
  x.dead = true;
  cancelAnimationFrame(x.raf);
  for (const f of x.off.reverse()) { try { f(); } catch (e) { /* keep tearing down */ } }
  H.classList.remove('fx-rm', 'fx-pending', 'fx-cursor-on', 'fx-cursor-hide');
  if (H.getAttribute('class') === '') H.removeAttribute('class');
  H.setAttribute('data-fx', 'off');
}

const IPTVFX = Object.freeze({
  version: '1.0.0',
  init,
  destroy,
  scan: (root) => C && C.scan(root),
  seek: (t, hold) => C && C.seek && C.seek(t, hold), // show the atmosphere at time t (seconds), frozen unless hold === false
  state: () => (C ? C.state() : { mode: 'off' }),
});
window.IPTVFX = IPTVFX;
})();
