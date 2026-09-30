import { expect, test, type TestInfo } from "@playwright/test";
import { openPage } from "./page";

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

  await strawboar.addChore(title, "7");

  await expect(strawboar.getDueRow(title)).toContainText("weekly · not done yet");
});

test("validates the title", async ({ page }) => {
  const strawboar = await openPage({ page });

  await strawboar.getAddButton().click();
  await strawboar.save();

  await expect(strawboar.getEditorError()).toHaveText("Title is required.");
});

test("marks a chore as done and undoes it", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Vacuum");
  const strawboar = await openPage({ page });
  await strawboar.addChore(title, "3");

  await strawboar.complete(title);

  await expect(strawboar.getUndoToast()).toContainText(`Done: ${title}`);
  await expect(strawboar.getDueRow(title)).toHaveCount(0);
  await expect(strawboar.getLaterSection(title)).toBeVisible();
  await expect(strawboar.getRecent()).toContainText(title);

  await strawboar.undoFromToast();

  await expect(strawboar.getUndoToast()).toBeHidden();
  await expect(strawboar.getDueRow(title)).toBeVisible();
  await expect(strawboar.getRecentRow(title)).toHaveCount(0);
});

test("highlights the chore open in the panel", async ({ page }, testInfo) => {
  const first = uniqueTitle(testInfo, "Clean bath");
  const second = uniqueTitle(testInfo, "Change toothbrush");
  const strawboar = await openPage({ page });
  await strawboar.addChore(first, "7");
  await strawboar.addChore(second, "30");
  const current = strawboar.getCurrentRow();
  await expect(current).toHaveCount(0);

  await strawboar.openChore(first);
  await expect(current).toHaveCount(1);
  await expect(current).toContainText(first);

  await strawboar.close();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(current).toHaveCount(0);
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

  await expect(strawboar.getLabelFilterButtons()).toHaveText(["All", "#bath", "#kitchen", "#weekly"]);
  await strawboar.filterByLabel("#kitchen");
  await expect(strawboar.getLabelFilterButton("#kitchen")).toHaveAttribute("aria-pressed", "true");
  await expect(strawboar.getDueRow(fan)).toBeVisible();
  await expect(strawboar.getDueRow(bath)).toHaveCount(0);

  await strawboar.filterByLabel("All");
  await expect(strawboar.getDueRow(bath)).toBeVisible();

  // Labels are kept after reload and can be edited.
  await strawboar.reload();
  await strawboar.openChore(fan);
  await expect(strawboar.getLabelToggle("kitchen")).toHaveAttribute("aria-pressed", "true");
  await expect(strawboar.getLabelToggle("bath")).toHaveAttribute("aria-pressed", "false");
  await strawboar.getLabelToggle("kitchen").click();
  await strawboar.save();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getRowLabels(fan)).toHaveCount(0);
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
  await expect(strawboar.getDueRow(title)).toBeVisible();
  await expect(badge).toHaveCount(0);
  await expect(strawboar.getLabelFilter()).toHaveCount(0);
});

test("undoes the latest completion from the recent list", async ({ page, request }, testInfo) => {
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
  await expect(strawboar.getRecentRow(title)).toHaveCount(2);
  await expect(strawboar.getRecentUndoButton(title)).toHaveCount(1);

  await strawboar.undoFromRecent(title);
  await expect(strawboar.getRecentRow(title)).toHaveCount(1);
  await expect(strawboar.getLaterRow(title)).toBeVisible();

  await strawboar.undoFromRecent(title);
  await expect(strawboar.getRecentRow(title)).toHaveCount(0);
  await expect(strawboar.getDueRow(title)).toBeVisible();

  await strawboar.reload();
  await expect(strawboar.getDueRow(title)).toContainText("not done yet");
  await expect(strawboar.getRecentRow(title)).toHaveCount(0);
});

test("closes the panel by tapping outside of it", async ({ page }, testInfo) => {
  const first = uniqueTitle(testInfo, "Clean bath");
  const second = uniqueTitle(testInfo, "Change toothbrush");
  const strawboar = await openPage({ page });
  await strawboar.addChore(first, "7");
  await strawboar.addChore(second, "30");

  await strawboar.openChore(first);
  await expect(strawboar.getTitleInput()).toHaveValue(first);

  await strawboar.tapOutsideEditor({ hasTouch: !!testInfo.project.use.hasTouch });
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getEditorBackdrop()).toHaveCount(0);

  await strawboar.openChore(second);
  await expect(strawboar.getTitleInput()).toHaveValue(second);
});

test("switches the panel to another chore while it is open", async ({ page }, testInfo) => {
  const first = uniqueTitle(testInfo, "Wipe windows");
  const second = uniqueTitle(testInfo, "Descale kettle");
  const strawboar = await openPage({ page });
  await strawboar.addChore(first, "7");
  await strawboar.addChore(second, "30");

  await strawboar.openChore(first);
  await expect(strawboar.getTitleInput()).toHaveValue(first);

  // The panel covers the whole screen on mobile.
  test.skip(strawboar.isNarrow(), "no chore is visible beside the panel");
  await strawboar.openChore(second);
  await expect(strawboar.getEditor()).toBeVisible();
  await expect(strawboar.getTitleInput()).toHaveValue(second);
  await expect(strawboar.getCurrentRow()).toContainText(second);
});

test("shows the history of a chore", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Water plants");
  const strawboar = await openPage({ page });
  await strawboar.addChore(title, "4");

  await strawboar.openChore(title);
  await expect(strawboar.getHistory()).toContainText("Not done yet.");
  await strawboar.close();
  await expect(strawboar.getEditor()).toBeHidden();

  await strawboar.complete(title);
  await strawboar.openChore(title);

  const [, month, day] = today().split("-");
  const label = `${month}/${day}`;
  await expect(strawboar.getHistory()).toHaveText(`History${label}`);
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
    "Chore #1: title, interval_days and labels are required.",
  );
  await strawboar.importDefinitions(JSON.stringify({ labels: [], chores: [{ ...exported.chores[0], labels: ["daily"] }] }));
  await expect(strawboar.getTransferError()).toHaveText("Chore #1: Unknown label: daily");

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
  await expect(strawboar.getDueRows()).toHaveCount(2);
});

test("opens import/export at the top of a long list", async ({ page, request }, testInfo) => {
  const labelIds: number[] = [];
  for (const name of ["a", "b"]) {
    const response = await request.post("/api/labels", { data: { name, color: "gray" } });
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

test("serves the web app manifest", async ({ request }) => {
  const response = await request.get("/manifest.webmanifest");
  expect(response.ok()).toBeTruthy();
  expect(await response.json()).toMatchObject({ name: "strawboar", display: "standalone" });
  expect((await request.get("/icon-192.png")).ok()).toBeTruthy();
});

function shortDate(offsetDays: number): string {
  const date = new Date(new Date(`${today()}T00:00:00Z`).getTime() + offsetDays * 86_400_000);
  const [, month, day] = date.toISOString().slice(0, 10).split("-");
  return `${month}/${day}`;
}

test("edits and archives a chore", async ({ page }, testInfo) => {
  const title = uniqueTitle(testInfo, "Wash sheets");
  const renamed = uniqueTitle(testInfo, "Wash all sheets");
  const strawboar = await openPage({ page });
  await strawboar.addChore(title, "30");

  await strawboar.complete(title);
  await expect(strawboar.getLaterRow(title)).toContainText(shortDate(30));

  // The due date follows the last completion, so a new interval applies right away.
  await strawboar.openChore(title);
  await expect(strawboar.getFirstDueInput()).toHaveCount(0);
  await strawboar.getTitleInput().fill(renamed);
  await strawboar.getIntervalInput().fill("20");
  await strawboar.save();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getLaterRow(renamed)).toContainText(shortDate(20));

  // Undo so that the completion does not stay in the recent list.
  await strawboar.reload();
  await strawboar.undoFromRecent(renamed);
  await expect(strawboar.getDueRow(renamed)).toBeVisible();

  await strawboar.openChore(renamed);
  await strawboar.archive();
  await expect(strawboar.getEditor()).toBeHidden();
  await expect(strawboar.getText(renamed)).toHaveCount(0);

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
  await expect(strawboar.getDueRows().first()).toBeVisible();

  expect(await strawboar.getOverflow()).toEqual({ x: 0, y: 0 });
});
