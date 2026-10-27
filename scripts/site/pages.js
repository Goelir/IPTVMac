/* IPTVMac product pages (Download, Features, What's new): scroll reveals, count-up numbers, the device picker and the release filter.
   Everything here is progressive: without this file every section is already visible and every panel is shown. */
(() => {
  "use strict";
  const d = document, H = d.documentElement;
  const $ = (s, r = d) => r.querySelector(s), $$ = (s, r = d) => Array.from(r.querySelectorAll(s));
  const rm = matchMedia("(prefers-reduced-motion: reduce)");
  const lang = H.lang || "en";

  // ---- reveal on scroll: [data-rv] fades up once; siblings stagger through --i ----
  if ("IntersectionObserver" in window && !rm.matches) {
    const seen = new Map();
    $$("[data-rv]").forEach(el => { const p = el.parentElement, n = seen.get(p) || 0; seen.set(p, n + 1); el.style.setProperty("--i", Math.min(n, 7)); });
    H.classList.add("rv-on");
    const io = new IntersectionObserver(es => es.forEach(en => { if (en.isIntersecting) { en.target.classList.add("in"); io.unobserve(en.target); } }), { rootMargin: "0px 0px -7% 0px" });
    $$("[data-rv]").forEach(el => io.observe(el));
  }

  // ---- count-up: the final number is in the markup; it runs from 0 when it scrolls into view ----
  const fmt = new Intl.NumberFormat(lang === "he" ? "en" : lang);
  if ("IntersectionObserver" in window && !rm.matches) {
    const io = new IntersectionObserver(es => es.forEach(en => {
      if (!en.isIntersecting) return; io.unobserve(en.target);
      const el = en.target, to = +el.dataset.count, t0 = performance.now(), dur = 1300;
      const step = now => { const k = Math.min(1, (now - t0) / dur), e = 1 - Math.pow(1 - k, 4); el.textContent = fmt.format(Math.round(to * e)); if (k < 1) requestAnimationFrame(step); };
      el.textContent = "0"; requestAnimationFrame(step);
    }), { threshold: .6 });
    $$("[data-count]").forEach(el => io.observe(el));
  }

  // ---- hero download button and picker: choose by the visitor's device ----
  const ua = navigator.userAgent || "";
  const rec = /Android/i.test(ua) ? (/TV|AFT[A-Z]|BRAVIA|SHIELD|Fire/i.test(ua) ? "tv" : "android") : (/Macintosh|Mac OS X/i.test(ua) && !/iPhone|iPad/i.test(ua) ? "mac" : null);
  const main = $("#dl-main");
  if (main && rec && main.dataset[rec]) { const [href, label, meta] = JSON.parse(main.dataset[rec]); main.href = href; $(".lbl", main).textContent = label; const m = $("#dl-meta"); if (m) m.textContent = meta; }

  const nav = $(".pick-nav");
  if (nav) {
    const tabs = $$("a", nav), panels = tabs.map(a => $(a.getAttribute("href")));
    const show = (i, focus) => {
      tabs.forEach((a, k) => { const on = k === i; a.setAttribute("aria-selected", on); a.tabIndex = on ? 0 : -1; panels[k].hidden = !on; panels[k].classList.toggle("on", on); });
      if (focus) tabs[i].focus();
    };
    nav.setAttribute("role", "tablist");
    tabs.forEach((a, i) => {
      a.setAttribute("role", "tab"); a.id = "tab-" + panels[i].id; a.setAttribute("aria-controls", panels[i].id); panels[i].setAttribute("role", "tabpanel"); panels[i].setAttribute("aria-labelledby", a.id);
      a.addEventListener("click", ev => { ev.preventDefault(); show(i); });
      a.addEventListener("keydown", ev => {
        const k = { ArrowDown: 1, ArrowRight: 1, ArrowUp: -1, ArrowLeft: -1 }[ev.key]; if (!k) return;
        ev.preventDefault(); show((i + k + tabs.length) % tabs.length, true);
      });
    });
    H.classList.add("pick-on");
    const start = Math.max(0, tabs.findIndex(a => a.getAttribute("href") === "#" + rec));
    if (rec && tabs[start]) { const b = d.createElement("span"); b.className = "recbadge"; b.textContent = nav.dataset.rec; tabs[start].appendChild(b); }
    show(start);
    // a link such as /download/#tv opens that tab
    const fromHash = () => { const i = tabs.findIndex(a => a.getAttribute("href") === location.hash); if (i >= 0) show(i); };
    addEventListener("hashchange", fromHash); if (location.hash) fromHash();
  }

  // ---- release filter ----
  const flt = $(".flt");
  if (flt) {
    flt.hidden = false;
    flt.addEventListener("click", ev => {
      const b = ev.target.closest("button"); if (!b) return;
      $$("button", flt).forEach(x => x.setAttribute("aria-pressed", x === b));
      $$(".rel").forEach(r => { r.hidden = !!b.dataset.f && r.dataset.plat !== b.dataset.f; });
    });
  }
})();
