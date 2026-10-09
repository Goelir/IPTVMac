// Renders the hero poster (real app screenshot in a macOS title strip) and encodes AVIF/WebP/JPEG at three widths.
// Needs: node, playwright-core (set PLAYWRIGHT_CORE to its index.mjs), Chrome (set CHROME), ffmpeg (libsvtav1), cwebp.
// Usage: PLAYWRIGHT_CORE=/path/to/playwright-core/index.mjs node scripts/site/make-posters.mjs
import { execFileSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import path from "node:path";
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const { chromium } = await import(process.env.PLAYWRIGHT_CORE || "playwright-core");
const chrome = process.env.CHROME || "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const tmp = process.env.TMPDIR || "/tmp";
const png = path.join(tmp, "iptvmac-hero-window.png");
const b = await chromium.launch({ headless: true, executablePath: chrome });
const p = await (await b.newContext({ viewport: { width: 1800, height: 1186 }, deviceScaleFactor: 1 })).newPage();
await p.goto("file://" + path.join(here, "poster/hero-window.html"));
await p.waitForTimeout(300);
await p.screenshot({ path: png });
await b.close();
for (const w of [900, 1400, 1800]) {
  const out = path.join(root, "docs/assets", `hero-window-${w}`);
  execFileSync("ffmpeg", ["-loglevel", "error", "-y", "-i", png, "-vf", `scale=${w}:-2:flags=lanczos`, "-c:v", "libsvtav1", "-crf", "34", "-preset", "4", "-pix_fmt", "yuv420p", out + ".avif"]);
  execFileSync("ffmpeg", ["-loglevel", "error", "-y", "-i", png, "-vf", `scale=${w}:-2:flags=lanczos`, "-q:v", "4", out + ".jpg"]);
  execFileSync("cwebp", ["-quiet", "-q", "80", "-m", "6", "-resize", String(w), "0", png, "-o", out + ".webp"]);
}
console.log("posters written");
