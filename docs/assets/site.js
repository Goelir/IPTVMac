/* IPTVMac site. Source: scripts/site/site.js, copied to docs/assets/site.js by scripts/site/build.py. No dependencies. */
(function () {
  // Copy-to-clipboard for the install command.
  document.querySelectorAll(".cmd").forEach(function (box) {
    var b = box.querySelector("button.copy"), code = box.querySelector("code"), say = box.querySelector("[role=status]");
    var lbl = b.querySelector(".lbl"), orig = lbl.textContent, timer;
    function done() {
      b.classList.add("done"); lbl.textContent = b.dataset.done; say.textContent = b.dataset.done;
      clearTimeout(timer);
      timer = setTimeout(function () { b.classList.remove("done"); lbl.textContent = orig; say.textContent = ""; }, 2000);
    }
    function fallback() {
      var r = document.createRange(); r.selectNodeContents(code);
      var s = getSelection(); s.removeAllRanges(); s.addRange(r);
      try { if (document.execCommand("copy")) done(); } catch (e) {}
    }
    b.addEventListener("click", function () {
      if (navigator.clipboard && window.isSecureContext) navigator.clipboard.writeText(code.textContent).then(done, fallback);
      else fallback();
    });
  });

  // Feature picker: on wide screens the four feature texts act as a switch for one screenshot.
  // On narrow screens (and without JavaScript) everything stays stacked and no buttons are added.
  var feats = document.querySelector(".feats");
  if (!feats || !window.matchMedia) return;
  var items = [].slice.call(feats.querySelectorAll(".feat")), wide = matchMedia("(min-width: 861px)");
  function select(it) {
    items.forEach(function (o) {
      var on = o === it, btn = o.querySelector(".feat-btn");
      if (on) o.setAttribute("data-on", ""); else o.removeAttribute("data-on");
      if (btn) btn.setAttribute("aria-pressed", on ? "true" : "false");
    });
    feats.classList.add("switched");
  }
  function build() {
    items.forEach(function (it) {
      var h = it.querySelector("h3"), btn = h.querySelector(".feat-btn");
      if (wide.matches && !btn) {
        btn = document.createElement("button"); btn.type = "button"; btn.className = "feat-btn";
        btn.setAttribute("aria-pressed", it.hasAttribute("data-on") ? "true" : "false");
        while (h.firstChild) btn.appendChild(h.firstChild);
        h.appendChild(btn);
        btn.addEventListener("click", function () { select(it); });
        it.querySelector(".feat-text").addEventListener("click", function (ev) { if (ev.target.closest("a") === null) select(it); });
      } else if (!wide.matches && btn) {
        while (btn.firstChild) h.insertBefore(btn.firstChild, btn);
        h.removeChild(btn);
      }
    });
  }
  build();
  (wide.addEventListener ? wide.addEventListener("change", build) : wide.addListener(build));
})();
