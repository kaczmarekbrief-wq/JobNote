/**
 * Dashboard Tour — Playwright headed script
 * Navigates localhost:7373, screenshots each page/section.
 * Output: /tmp/dashboard-tour/*.png
 * Run: . ~/.nvm/nvm.sh && nvm use 20 --silent && node this_file.js
 */
const { chromium } = require('/Users/marcinszostak/AI_REMOTE/tele/ui/node_modules/playwright-core');
const fs = require('fs');
const path = require('path');

const OUT = '/tmp/dashboard-tour';
const BASE = 'http://localhost:7373';

async function shot(page, name, opts = {}) {
  const file = path.join(OUT, name);
  await page.screenshot({ path: file, fullPage: opts.fullPage ?? false, ...opts });
  console.log('📸', name);
}

(async () => {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch({ headless: false, slowMo: 400 });
  const page = await browser.newPage();
  await page.setViewportSize({ width: 1440, height: 900 });

  // ── Page 1: Command ──────────────────────────────────────────
  console.log('\n→ Command page');
  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  await shot(page, '01-command-full.png', { fullPage: true });

  // Top strip (live sessions + cache + emergency)
  await shot(page, '02-command-top.png', {
    clip: { x: 0, y: 0, width: 1440, height: 400 }
  });

  // Task board area
  await shot(page, '03-command-taskboard.png', {
    clip: { x: 0, y: 380, width: 1440, height: 500 }
  });

  // ── Page 2: Activity ─────────────────────────────────────────
  console.log('\n→ Activity page');
  await page.getByRole('button', { name: /activity/i }).click();
  await page.waitForTimeout(2000);
  await shot(page, '04-activity-full.png', { fullPage: true });

  // ── Page 3: Skills ───────────────────────────────────────────
  console.log('\n→ Skills page');
  await page.getByRole('button', { name: /skills/i }).click();
  await page.waitForTimeout(2000);
  await shot(page, '05-skills-full.png', { fullPage: true });

  await browser.close();
  console.log(`\n✅ Done — screenshots in ${OUT}`);
  console.log(fs.readdirSync(OUT).map(f => `  ${f}`).join('\n'));
})().catch(err => {
  console.error('❌', err.message);
  process.exit(1);
});
