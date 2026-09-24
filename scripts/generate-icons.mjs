// Renders assets/icon.svg to the PNG icons in public/.
// Usage: node scripts/generate-icons.mjs
import { chromium } from "@playwright/test";
import { readFile } from "node:fs/promises";

const svg = await readFile(new URL("../assets/icon.svg", import.meta.url), "utf8");
const icons = [
  ["icon-192.png", 192],
  ["icon-512.png", 512],
  ["apple-touch-icon.png", 180],
];

const browser = await chromium.launch();
for (const [name, size] of icons) {
  const page = await browser.newPage({ viewport: { width: size, height: size } });
  await page.setContent(
    `<style>html,body{margin:0}svg{display:block;width:${size}px;height:${size}px}</style>${svg}`,
  );
  await page.screenshot({ path: new URL(`../public/${name}`, import.meta.url).pathname });
  await page.close();
}
await browser.close();
