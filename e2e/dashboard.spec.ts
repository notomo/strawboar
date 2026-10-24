import { test as base, expect, type TestInfo } from "@playwright/test";
import { openPage } from "./page";

// The Worker rejects requests that change data without being same-origin,
// so API calls of the tests send the origin like a browser does.
const test = base.extend({
  request: async ({ playwright, baseURL }, use) => {
    const request = await playwright.request.newContext({ baseURL, extraHTTPHeaders: { origin: baseURL! } });
    await use(request);
    await request.dispose();
  },
});

// Start each test from an empty dashboard.
test.beforeEach(async ({ request }) => {
  const response = await request.get("/api/chores");
  const { chores, labels } = (await response.json()) as {
    chores: { id: number }[];
    labels: { id: number }[];
  };
  for (const chore of chores) {
    expect((await request.delete(`/api/chores/${chore.id}`)).ok()).toBeTruthy();
  }
  for (const label of labels) {
    expect((await request.delete(`/api/labels/${label.id}`)).ok()).toBeTruthy();
  }
});

function uniqueTitle(testInfo: TestInfo, name: string): string {
  return `${name} ${testInfo.project.name} ${Date.now()}`;
}

function today(): string {
  // Same as the Worker: Asia/Tokyo
  return new Date(Date.now() + 9 * 60 * 60 * 1000).toISOString().slice(0, 10);
}

test("adds a chore that is due today", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Clean bath");
  const strawboar = await openPage({ page });

  await strawboar.getAddButton().click();
  await strawboar.save();
  await expect(strawboar.getEditorError()).toHaveText("Title is required.");
  await strawboar.close();

  await strawboar.addChore(title, "7");

  await expect(strawboar.getSoonRow(title)).toContainText("weekly · not done yet");

  // Soon is selected by default.
  await expect(strawboar.getSoonTab()).toHaveAttribute("aria-selected", "true");
  await expect(strawboar.getSoonTab()).toHaveText("Soon 1");
  await expect(strawboar.getSoonCaption()).toHaveText(`Until ${shortDate(0)}`);
});

test("marks a chore as done and undoes it", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Vacuum");
  const strawboar = await openPage({ page });
  await strawboar.addChore(title, "3");

  await strawboar.complete(title);

  await expect(strawboar.getUndoToast()).toContainText(`Done: ${title}`);
  await expect(strawboar.getSoonRow(title)).toHaveCount(0);
  await expect(strawboar.getLaterTab()).toHaveText("Later 1");
  await expect(strawboar.getLaterRow(title)).toBeHidden();
  await strawboar.openLater();
  await expect(strawboar.getLaterRow(title)).toBeVisible();
  // Completions left by other tests are counted too.
  await expect(strawboar.getRecentTab()).toHaveText(/^Done \d+$/);
  await expect(strawboar.getRecentRow(title)).toBeHidden();
  await strawboar.openRecent();
  await expect(strawboar.getRecentRow(title)).toBeVisible();
  await expect(strawboar.getRecentCaption()).toHaveText(`${shortDate(-6)} – ${shortDate(0)}`);

  await strawboar.undoFromToast();

  await expect(strawboar.getUndoToast()).toBeHidden();
  await expect(strawboar.getRecentRow(title)).toHaveCount(0);
  await strawboar.openSoon();
  await expect(strawboar.getSoonRow(title)).toBeVisible();
});

test("opens and closes the panel", async ({ page }, testInfo) => {
  const first = uniqueTitle(testInfo, "Clean bath");
  const second = uniqueTitle(testInfo, "Change toothbrush");
  const strawboar = await openPage({ page });
  await strawboar.addChore(first, "7");
  await strawboar.addChore(second, "30");
  const current = strawboar.getCurrentRow();
  await expect(current).toHaveCount(0);

  // The chore open in the panel is highlighted.
  await strawboar.openChore(first);
  await expect(strawboar.getTitleInput()).toHaveValue(first);
  await expect(current).toHaveCount(1);
  await expect(current).toContainText(first);

  await strawboar.close();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(current).toHaveCount(0);

  await strawboar.openChore(second);
  await expect(strawboar.getTitleInput()).toHaveValue(second);
  await strawboar.tapOutsideEditor({ hasTouch: !!testInfo.project.use.hasTouch });
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getEditorBackdrop()).toHaveCount(0);

  // Nothing is left over the dashboard.
  await strawboar.openChore(first);
  await expect(strawboar.getTitleInput()).toHaveValue(first);
});

test("switches the panel and closes it by tapping the header", async ({ page }, testInfo) => {
  const first = uniqueTitle(testInfo, "Wipe windows");
  const second = uniqueTitle(testInfo, "Descale kettle");
  const strawboar = await openPage({ page });
  // The panel covers the whole screen on mobile.
  test.skip(strawboar.isNarrow(), "neither the chores nor the header are visible beside the panel");
  await strawboar.addChore(first, "7");
  await strawboar.addChore(second, "30");

  await strawboar.openChore(first);
  await expect(strawboar.getTitleInput()).toHaveValue(first);
  await strawboar.openChore(second);
  await expect(strawboar.getEditor()).toBeVisible();
  await expect(strawboar.getTitleInput()).toHaveValue(second);
  await expect(strawboar.getCurrentRow()).toContainText(second);

  await strawboar.tapOutsideEditor({ hasTouch: !!testInfo.project.use.hasTouch, onHeader: true });
  await expect(strawboar.getEditor()).toBeHidden();
});

test("filters chores by label", async ({ page }, testInfo) => {
  const bath = uniqueTitle(testInfo, "Clean bath");
  const fan = uniqueTitle(testInfo, "Clean kitchen fan");
  const strawboar = await openPage({ page });
  await expect(strawboar.getLabelFilter()).toHaveCount(0);
  await strawboar.openLabels();
  await strawboar.addLabel("weekly");
  await strawboar.addLabel("bath");
  await strawboar.addLabel("kitchen");
  await strawboar.close();
  await strawboar.addChore(bath, "7", ["bath", "weekly"]);
  await strawboar.addChore(fan, "90", ["kitchen"]);

  await expect(strawboar.getRowLabels(bath)).toHaveText(["bath", "weekly"]);

  await expect(strawboar.getLabelFilterButtons()).toHaveText(["bath", "kitchen", "weekly"]);
  await strawboar.toggleLabelFilter("kitchen");
  await expect(strawboar.getLabelFilterButton("kitchen")).toHaveAttribute("aria-pressed", "true");
  await expect(strawboar.getSoonRow(fan)).toBeVisible();
  await expect(strawboar.getSoonRow(bath)).toHaveCount(0);

  // Clicking the active label clears the filter.
  await strawboar.toggleLabelFilter("kitchen");
  await expect(strawboar.getLabelFilterButton("kitchen")).toHaveAttribute("aria-pressed", "false");
  await expect(strawboar.getSoonRow(bath)).toBeVisible();

  // Labels are kept after reload and can be edited.
  await strawboar.reload();
  await strawboar.openChore(fan);
  await expect(strawboar.getLabelToggle("kitchen")).toHaveAttribute("aria-pressed", "true");
  await expect(strawboar.getLabelToggle("bath")).toHaveAttribute("aria-pressed", "false");
  await strawboar.getLabelToggle("kitchen").click();
  await strawboar.save();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getRowLabels(fan)).toHaveCount(0);

  // Completions are filtered too.
  await strawboar.complete(bath);
  await strawboar.openRecent();
  await strawboar.toggleLabelFilter("weekly");
  await expect(strawboar.getRecentRow(bath)).toHaveCount(1);
  await strawboar.toggleLabelFilter("kitchen");
  await expect(strawboar.getRecentRow(bath)).toHaveCount(0);
});

test("manages labels with colors", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Clean bath");
  const strawboar = await openPage({ page });
  await strawboar.openLabels();
  await strawboar.addLabel("bath", "blue");
  await expect(strawboar.getLabelList()).toHaveText("bath");

  await strawboar.getLabelNameInput().fill(" bath ");
  await strawboar.getAddLabelButton().click();
  await expect(strawboar.getLabelFormError()).toHaveText("A label named bath already exists.");
  await strawboar.close();

  await strawboar.addChore(title, "7", ["bath"]);
  const badge = strawboar.getRowLabels(title);
  await expect(badge).toHaveText(["bath"]);
  await expect(badge).toHaveCSS("color", "rgb(96, 165, 250)");

  // Renaming and recoloring applies to every chore with the label.
  await strawboar.openLabels();
  await strawboar.selectLabel("bath");
  await expect(strawboar.getLabelNameInput()).toHaveValue("bath");
  await expect(strawboar.getLabelColorButton("blue")).toHaveAttribute("aria-pressed", "true");
  await strawboar.getLabelNameInput().fill("bathroom");
  await strawboar.getLabelColorButton("pink").click();
  await strawboar.save();
  await expect(strawboar.getLabelList()).toHaveText("bathroom");
  await expect(badge).toHaveText(["bathroom"]);
  await expect(badge).toHaveCSS("color", "rgb(244, 114, 182)");

  // Deleting removes it from the chores.
  await strawboar.selectLabel("bathroom");
  await strawboar.deleteLabel();
  await expect(strawboar.getLabelList()).toHaveCount(0);
  await expect(badge).toHaveCount(0);

  await strawboar.reload();
  await expect(strawboar.getSoonRow(title)).toBeVisible();
  await expect(badge).toHaveCount(0);
  await expect(strawboar.getLabelFilter()).toHaveCount(0);
});

test("undoes the latest completion from the panel", async ({ page, request }, testInfo) => {
  const title = uniqueTitle(testInfo, "Water plants");
  const created = await request.post("/api/chores", {
    data: { title, interval_days: 4, next_due: today(), labels: [] },
  });
  const { id } = (await created.json()) as { id: number };
  const completionIds: number[] = [];
  for (let i = 0; i < 2; i++) {
    const response = await request.post(`/api/chores/${id}/complete`);
    completionIds.push(((await response.json()) as { completion_id: number }).completion_id);
  }
  // Only the latest completion can be undone.
  expect((await request.delete(`/api/completions/${completionIds[0]}`)).status()).toBe(400);

  const strawboar = await openPage({ page });
  await strawboar.openRecent();
  await expect(strawboar.getRecentRow(title)).toHaveCount(2);
  await strawboar.openRecentChore(title);
  await strawboar.askUndoLastDone();
  await expect(strawboar.getConfirmDialog()).toContainText(`done on ${shortDate(0)}`);
  await strawboar.getConfirmCancelButton().click();
  await expect(strawboar.getRecentRow(title)).toHaveCount(2);

  await strawboar.undoLastDone();
  await expect(strawboar.getRecentRow(title)).toHaveCount(1);

  // The previous completion is the latest now, so it can be undone too.
  await strawboar.undoLastDone();
  await expect(strawboar.getRecentRow(title)).toHaveCount(0);
  await strawboar.askUndoLastDone();
  await expect(strawboar.getConfirmDialog()).toContainText("Nothing to undo");
  await strawboar.getConfirmButton("OK").click();
  await expect(strawboar.getConfirmDialog()).toBeHidden();
  await expect(strawboar.getEditor()).toBeVisible();
  await strawboar.close();
  await strawboar.openSoon();
  await expect(strawboar.getSoonRow(title)).toBeVisible();

  await strawboar.reload();
  await expect(strawboar.getSoonRow(title)).toContainText("not done yet");
  await strawboar.openRecent();
  await expect(strawboar.getRecentRow(title)).toHaveCount(0);
});

test("exports and imports definitions", async ({ page }, testInfo) => {
  const existing = uniqueTitle(testInfo, "Clean bath");
  const added = uniqueTitle(testInfo, "Descale kettle");
  const strawboar = await openPage({ page });
  await strawboar.openLabels();
  await strawboar.addLabel("bath", "blue");
  await strawboar.close();
  await strawboar.addChore(existing, "7", ["bath"]);

  await strawboar.openTransfer();
  const exported = JSON.parse(await strawboar.getDefinitionsInput().inputValue());
  expect(exported).toEqual({
    labels: [{ name: "bath", color: "blue" }],
    chores: [{ title: existing, interval_days: 7, labels: ["bath"], next_due: today() }],
  });

  await strawboar.importDefinitions(JSON.stringify({ labels: [], chores: [{}] }));
  await expect(strawboar.getTransferError()).toHaveText(
    "Chore #1: title, interval_days or monthly, and labels are required.",
  );

  // Matched by name and title: existing ones are updated and others are added.
  const definitions = {
    labels: [
      { name: "bath", color: "red" },
      { name: "daily", color: "green" },
      { name: "kitchen", color: "teal" },
    ],
    chores: [
      { ...exported.chores[0], interval_days: 1, labels: ["daily", "bath"] },
      { title: added, interval_days: 30, labels: ["kitchen"] },
    ],
  };
  await strawboar.importDefinitions(JSON.stringify(definitions));
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getRowLabels(existing)).toHaveText(["bath", "daily"]);
  await expect(strawboar.getRowLabels(existing).first()).toHaveCSS("color", "rgb(248, 113, 113)");
  await expect(strawboar.getRowLabels(added)).toHaveText(["kitchen"]);
  await expect(strawboar.getSoonRows()).toHaveCount(2);
});

test("opens import/export at the top of a long list", async ({ page, request }, testInfo) => {
  const labelIds: number[] = [];
  for (const name of ["a", "b"]) {
    const response = await request.post("/api/labels", { data: { name, color: "blue" } });
    labelIds.push(((await response.json()) as { id: number }).id);
  }
  for (let i = 0; i < 15; i++) {
    const response = await request.post("/api/chores", {
      data: { title: uniqueTitle(testInfo, `Chore ${i}`), interval_days: 7, next_due: today(), labels: labelIds },
    });
    expect(response.ok()).toBeTruthy();
  }
  const strawboar = await openPage({ page });

  await strawboar.openTransfer();

  await expect(strawboar.getImportButton()).toBeInViewport();
  expect(await strawboar.getDefinitionsScroll()).toEqual({ panel: 0, textarea: 0 });
});

test("keeps the tabs at the top while scrolling", async ({ page, request }, testInfo) => {
  for (let i = 0; i < 20; i++) {
    const response = await request.post("/api/chores", {
      data: { title: uniqueTitle(testInfo, `Chore ${i}`), interval_days: 7, next_due: today(), labels: [] },
    });
    expect(response.ok()).toBeTruthy();
  }
  const strawboar = await openPage({ page });
  await expect(strawboar.getSoonRows()).toHaveCount(20);

  await strawboar.scrollToBottom();
  await expect(strawboar.getSoonRows().first()).not.toBeInViewport();
  await expect(strawboar.getToday()).toBeInViewport();
  // The other tabs can be reached however long Soon is.
  await strawboar.openLater();
});

test("serves the web app manifest", async ({ request }) => {
  const response = await request.get("/manifest.webmanifest");
  expect(response.ok()).toBeTruthy();
  expect(await response.json()).toMatchObject({ name: "strawboar", display: "standalone" });
  expect((await request.get("/icon-192.png")).ok()).toBeTruthy();
});

test("reloads the page when loading fails", async ({ page }) => {
  const strawboar = await openPage({ page, failFirstLoad: true });
  await expect(strawboar.getText("Failed to load chores.")).toBeVisible();

  await strawboar.reloadPageAfterFailure();

  await expect(strawboar.getToday()).toBeVisible();
});

test("rejects changes from another site", async ({ playwright, baseURL }) => {
  const request = await playwright.request.newContext({ baseURL, extraHTTPHeaders: { origin: "https://example.com" } });
  expect((await request.post("/api/chores/import", { data: "{}" })).status()).toBe(403);
  expect((await request.get("/api/chores")).ok()).toBeTruthy();
  await request.dispose();
});

function shortDate(offsetDays: number): string {
  const date = new Date(new Date(`${today()}T00:00:00Z`).getTime() + offsetDays * 86_400_000);
  const [, month, day] = date.toISOString().slice(0, 10).split("-");
  return `${month}/${day}`;
}

function isoDate(offsetDays: number): string {
  return new Date(new Date(`${today()}T00:00:00Z`).getTime() + offsetDays * 86_400_000).toISOString().slice(0, 10);
}

// `MM/dd` of the same day in the next month, or its last day.
function nextMonthShortDate(iso: string): string {
  const [year, month, day] = iso.split("-").map(Number);
  const nextMonth = (month % 12) + 1;
  const nextYear = month === 12 ? year + 1 : year;
  const lastDay = new Date(Date.UTC(nextYear, nextMonth, 0)).getUTCDate();
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${pad(nextMonth)}/${pad(Math.min(day, lastDay))}`;
}

test("keeps a monthly chore on its day", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Pay rent");
  const firstDue = isoDate(10);
  const strawboar = await openPage({ page });

  await strawboar.addMonthlyChore(title, { firstDue, leadDays: "14" });
  await expect(strawboar.getSoonRow(title)).toContainText("monthly on the");
  await expect(strawboar.getSoonRow(title)).toContainText("not done yet · due in 10 days");
  await expect(strawboar.getSoonCaption()).toHaveText(`Until ${shortDate(10)}`);

  // Done early, it is due on the same day of the next month.
  await strawboar.complete(title);
  await strawboar.openLater();
  await expect(strawboar.getLaterRow(title)).toContainText(nextMonthShortDate(firstDue));
  await strawboar.undoFromToast();
  await strawboar.openSoon();
  await expect(strawboar.getSoonRow(title)).toBeVisible();

  await strawboar.openChore(title);
  await expect(strawboar.getRepeatTab("Monthly")).toHaveAttribute("aria-selected", "true");
  await expect(strawboar.getDayInput()).toHaveValue(String(Number(firstDue.slice(8))));
  await strawboar.getLeadDaysInput().fill("0");
  await strawboar.save();
  await expect(strawboar.getEditor()).toBeHidden();
  await strawboar.openLater();
  await expect(strawboar.getLaterRow(title)).toContainText(shortDate(10));
});

test("edits and archives a chore", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Wash sheets");
  const renamed = uniqueTitle(testInfo, "Wash all sheets");
  const description = "1. Strip the bed\n2. Wash them\n3. Dry them";
  const strawboar = await openPage({ page });
  await strawboar.addChore(title, "30");

  await strawboar.complete(title);
  await strawboar.openLater();
  await expect(strawboar.getLaterRow(title)).toContainText(shortDate(30));

  // The due date follows the last completion, so a new interval applies right away.
  await strawboar.openChore(title);
  await expect(strawboar.getFirstDueInput()).toHaveCount(0);
  await strawboar.getTitleInput().fill(renamed);
  await strawboar.getIntervalInput().fill("20");
  await expect(strawboar.getDescriptionInput()).toHaveValue("");
  await strawboar.getDescriptionInput().fill(description);
  await strawboar.save();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getLaterRow(renamed)).toContainText(shortDate(20));

  await strawboar.reload();
  await strawboar.openRecentChore(renamed);
  await expect(strawboar.getDescriptionInput()).toHaveValue(description);
  // Undo so that the completion does not stay in the recent list.
  await strawboar.undoLastDone();
  await strawboar.close();
  await strawboar.openSoon();
  await expect(strawboar.getSoonRow(renamed)).toBeVisible();

  await strawboar.openChore(renamed);
  await strawboar.cancelArchive();
  await expect(strawboar.getEditor()).toBeVisible();
  await strawboar.dismissArchive();
  await expect(strawboar.getEditor()).toBeVisible();
  await expect(strawboar.getSoonRow(renamed)).toBeVisible();

  await strawboar.archive();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getSoonRow(renamed)).toHaveCount(0);

  await strawboar.reload();
  await expect(strawboar.getToday()).not.toBeEmpty();
  await expect(strawboar.getText(renamed)).toHaveCount(0);
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
      data: { title: uniqueTitle(testInfo, name), interval_days: interval, next_due, labels: [] },
    });
    expect(response.ok()).toBeTruthy();
  }

  const strawboar = await openPage({ page });
  await expect(strawboar.getSoonRows().first()).toBeVisible();

  expect(await strawboar.getOverflow()).toEqual({ x: 0, y: 0 });
});
