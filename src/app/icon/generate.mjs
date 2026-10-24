// Renders icon.svg to the icons in ../public/ (PNG icons and a favicon with rounded corners).
// Usage: node src/app/icon/generate.mjs
import { chromium } from "@playwright/test";
import { readFile, writeFile } from "node:fs/promises";

const svg = await readFile(new URL("icon.svg", import.meta.url), "utf8");
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

// A favicon is shown as is, so round the full-bleed background.
if (!svg.includes("<rect ")) throw new Error("no <rect> to round in icon.svg");
const favicon = svg.replace(/\s*<!--.*?-->/gs, "").replace("<rect ", '<rect rx="128" ');
await writeFile(new URL("../public/favicon.svg", import.meta.url), favicon);
