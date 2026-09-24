import { expect, test, type Page, type TestInfo } from "@playwright/test";

// Start each test from an empty dashboard.
test.beforeEach(async ({ request }) => {
  const response = await request.get("/api/chores");
  const { chores } = (await response.json()) as { chores: { id: number }[] };
  for (const chore of chores) {
    expect((await request.delete(`/api/chores/${chore.id}`)).ok()).toBeTruthy();
  }
});

function uniqueTitle(testInfo: TestInfo, name: string): string {
  return `${name} ${testInfo.project.name} ${Date.now()}`;
}

function today(): string {
  // Same as the Worker: Asia/Tokyo
  return new Date(Date.now() + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

async function addChore(page: Page, title: string, interval: string) {
  await page.getByRole("button", { name: "Add" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByLabel("Title").fill(title);
  await dialog.getByLabel("Every (days)").fill(interval);
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(dialog).toBeHidden();
}

test("adds a chore that is due today", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Clean bath");
  await page.goto("/");

  await addChore(page, title, "7");

  const row = page.locator("#due li", { hasText: title });
  await expect(row).toContainText("weekly · not done yet");
});

test("validates the title", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "Add" }).click();
  const dialog = page.getByRole("dialog");
  await dialog.getByRole("button", { name: "Save" }).click();

  await expect(dialog.locator("#chore-editor-error")).toHaveText("Title is required.");
});

test("marks a chore as done and undoes it", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Vacuum");
  await page.goto("/");
  await addChore(page, title, "3");

  await page.getByRole("button", { name: `Done: ${title}` }).click();

  await expect(page.locator("#undo-toast")).toContainText(`Done: ${title}`);
  await expect(page.locator("#due li", { hasText: title })).toHaveCount(0);
  await expect(page.locator("#later", { hasText: title })).toBeVisible();
  await expect(page.locator("#recent")).toContainText(title);

  await page.locator("#undo-toast").getByRole("button", { name: "Undo" }).click();

  await expect(page.locator("#undo-toast")).toBeHidden();
  await expect(page.locator("#due li", { hasText: title })).toBeVisible();
  await expect(page.locator("#recent", { hasText: title })).toHaveCount(0);
});

test("shows the history of a chore", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Water plants");
  await page.goto("/");
  await addChore(page, title, "4");
  const dialog = page.getByRole("dialog");

  await page.locator("#due li", { hasText: title }).getByText(title).click();
  await expect(dialog.locator("#chore-history")).toContainText("Not done yet.");
  await dialog.getByRole("button", { name: "Close" }).click();
  await expect(dialog).toBeHidden();

  await page.getByRole("button", { name: `Done: ${title}` }).click();
  await page.locator("#later").getByText(title).click();

  const [, month, day] = today().split("-").map(Number);
  const label = `${new Date(2000, month - 1).toLocaleString("en-US", { month: "short" })} ${day}`;
  await expect(dialog.locator("#chore-history")).toHaveText(`History${label}`);
});

test("serves the web app manifest", async ({ request }) => {
  const response = await request.get("/manifest.webmanifest");
  expect(response.ok()).toBeTruthy();
  expect(await response.json()).toMatchObject({ name: "strawboar", display: "standalone" });
  expect((await request.get("/icon-192.png")).ok()).toBeTruthy();
});

test("postpones, edits and archives a chore", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Wash sheets");
  const renamed = uniqueTitle(testInfo, "Wash all sheets");
  await page.goto("/");
  await addChore(page, title, "30");
  const dialog = page.getByRole("dialog");

  await page.locator("#due li", { hasText: title }).getByText(title).click();
  await dialog.getByRole("button", { name: "+3d" }).click();
  await expect(dialog).toBeHidden();
  await expect(page.locator("#soon li", { hasText: title })).toContainText("due in 3 days");

  await page.locator("#soon li", { hasText: title }).getByText(title).click();
  await dialog.getByLabel("Title").fill(renamed);
  await dialog.getByRole("button", { name: "Save" }).click();
  await expect(dialog).toBeHidden();
  await expect(page.locator("#soon li", { hasText: renamed })).toBeVisible();

  await page.locator("#soon li", { hasText: renamed }).getByText(renamed).click();
  await dialog.getByRole("button", { name: "Archive" }).click();
  await expect(dialog).toBeHidden();
  await expect(page.getByText(renamed)).toHaveCount(0);

  await page.reload();
  await expect(page.locator("#today")).not.toBeEmpty();
  await expect(page.getByText(renamed)).toHaveCount(0);
});

test("fits in the first view without scrolling", async ({ page, request }, testInfo) => {
  const chores = [
    ["Change toothbrush", 30, -5],
    ["Water plants", 4, 0],
    ["Clean kitchen fan", 90, 9],
    ["Replace water filter", 60, 18],
    ["Clean the fridge", 30, 25],
    ["Wash the car", 30, 40],
  ] as const;
  const base = new Date(`${today()}T00:00:00Z`).getTime();
  for (const [name, interval, offset] of chores) {
    const next_due = new Date(base + offset * 86_400_000).toISOString().slice(0, 10);
    const response = await request.post("/api/chores", {
      data: { title: uniqueTitle(testInfo, name), interval_days: interval, next_due },
    });
    expect(response.ok()).toBeTruthy();
  }

  await page.goto("/");
  await expect(page.locator("#due li").first()).toBeVisible();

  const overflow = await page.evaluate(() => {
    const root = document.scrollingElement!;
    return {
      x: root.scrollWidth - root.clientWidth,
      y: root.scrollHeight - root.clientHeight,
    };
  });
  expect(overflow).toEqual({ x: 0, y: 0 });
});
