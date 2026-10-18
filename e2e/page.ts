import { expect, type Page } from "@playwright/test";

export async function openPage({ page }: { page: Page }) {
  await page.goto("/");

  const editor = page.getByRole("dialog");
  const labelFilter = page.locator("#label-filter");
  const recent = page.locator("#recent");
  const undoToast = page.locator("#undo-toast");

  const strawboarPage = {
    reload: async () => {
      await page.reload();
    },

    getToday: () => page.locator("#today"),
    getText: (text: string) => page.getByText(text),

    getDueTrigger: () => page.locator("#due-trigger"),
    getDueRows: () => page.locator("#due li"),
    getDueRow: (title: string) => page.locator("#due li", { hasText: title }),
    getSoonRow: (title: string) => page.locator("#soon li", { hasText: title }),
    getSoonTitle: () => page.locator("#soon-trigger"),
    getLaterTrigger: () => page.locator("#later-trigger"),
    getLaterRow: (title: string) => page.locator("#later li", { hasText: title }),
    getCurrentRow: () => page.locator('li[aria-current="true"]'),
    getDoneButton: (title: string) => page.getByRole("button", { name: `Done: ${title}` }),

    getRecent: () => recent,
    getRecentTrigger: () => page.locator("#recent-trigger"),
    getRecentRow: (title: string) => recent.locator("li", { hasText: title }),

    getUndoToast: () => undoToast,
    getUndoToastButton: () => undoToast.getByRole("button", { name: "Undo" }),

    getLabelFilter: () => labelFilter,
    getLabelFilterButtons: () => labelFilter.getByRole("button"),
    getLabelFilterButton: (name: string) => labelFilter.getByRole("button", { name }),
    getRowLabels: (title: string) =>
      page.locator("#due li, #soon li, #later li", { hasText: title }).locator('[data-slot="badge"]'),

    getAddButton: () => page.getByRole("button", { name: "+ Add" }),
    getEditor: () => editor,
    getEditorBackdrop: () => page.locator("#editor-backdrop"),
    getTitleInput: () => editor.getByLabel("Title"),
    getDescriptionInput: () => editor.getByLabel("Description"),
    getIntervalInput: () => editor.getByLabel("Every (days)"),
    getRepeatButton: (name: string) =>
      editor.getByRole("group", { name: "Repeat" }).getByRole("button", { name, exact: true }),
    getMonthsInput: () => editor.getByLabel("Every (months)"),
    getDayInput: () => editor.getByLabel("Day of month"),
    getLeadDaysInput: () => editor.getByLabel("Soon from (days before)"),
    getLabelToggle: (name: string) =>
      editor.getByRole("group", { name: "Labels" }).getByRole("button", { name, exact: true }),
    getFirstDueInput: () => editor.getByLabel("First due"),
    getEditorError: () => editor.locator("#chore-editor-error"),
    getHistory: () => editor.locator("#chore-history-text"),
    getHistoryUndoButton: () => editor.locator("#chore-history").getByRole("button", { name: /^Undo/ }),
    getSaveButton: () => editor.getByRole("button", { name: "Save" }),
    getCloseButton: () => editor.getByRole("button", { name: "Close" }),
    getArchiveButton: () => editor.getByRole("button", { name: "Archive" }),

    getMenuButton: () => page.getByRole("button", { name: "Menu" }),
    getMenuItem: (name: string) => page.getByRole("menuitem", { name }),
    getLabelList: () => editor.locator("#label-list"),
    getLabelListButton: (name: string) => editor.getByRole("button", { name: `Edit label: ${name}` }),
    getLabelNameInput: () => editor.getByLabel("Name"),
    getLabelColorButton: (color: string) =>
      editor.getByRole("group", { name: "Color" }).getByRole("button", { name: color, exact: true }),
    getAddLabelButton: () => editor.getByRole("button", { name: "Add label" }),
    getDeleteLabelButton: () => editor.getByRole("button", { name: "Delete" }),
    getLabelFormError: () => editor.locator("#label-form-error"),

    getDefinitionsInput: () => editor.getByLabel("Labels and chores (JSON)"),
    getImportButton: () => editor.getByRole("button", { name: "Import", exact: true }),
    getTransferError: () => editor.locator("#transfer-error"),

    openTransfer: async () => {
      await strawboarPage.getMenuButton().click();
      await strawboarPage.getMenuItem("Import / Export").click();
    },

    importDefinitions: async (text: string) => {
      await strawboarPage.getDefinitionsInput().fill(text);
      await strawboarPage.getImportButton().click();
    },

    addChore: async (title: string, interval: string, labels: string[] = []) => {
      await strawboarPage.getAddButton().click();
      await strawboarPage.getTitleInput().fill(title);
      await strawboarPage.getIntervalInput().fill(interval);
      for (const label of labels) {
        await strawboarPage.getLabelToggle(label).click();
      }
      await strawboarPage.getSaveButton().click();
      await expect(editor).toBeHidden();
    },

    addMonthlyChore: async (title: string, { firstDue, leadDays }: { firstDue: string; leadDays: string }) => {
      await strawboarPage.getAddButton().click();
      await strawboarPage.getTitleInput().fill(title);
      await strawboarPage.getRepeatButton("Monthly").click();
      await strawboarPage.getMonthsInput().fill("1");
      await strawboarPage.getLeadDaysInput().fill(leadDays);
      await strawboarPage.getFirstDueInput().fill(firstDue);
      await strawboarPage.getSaveButton().click();
      await expect(editor).toBeHidden();
    },

    openLabels: async () => {
      await strawboarPage.getMenuButton().click();
      await strawboarPage.getMenuItem("Edit labels").click();
      await expect(strawboarPage.getLabelNameInput()).toBeVisible();
    },

    // Adds a label in the open labels panel.
    addLabel: async (name: string, color?: string) => {
      await strawboarPage.getLabelNameInput().fill(name);
      if (color) {
        await strawboarPage.getLabelColorButton(color).click();
      }
      await strawboarPage.getAddLabelButton().click();
      await expect(strawboarPage.getLabelListButton(name)).toBeVisible();
    },

    selectLabel: async (name: string) => {
      await strawboarPage.getLabelListButton(name).click();
    },

    deleteLabel: async () => {
      await strawboarPage.getDeleteLabelButton().click();
    },

    openChore: async (title: string) => {
      await page.locator("#due li, #soon li, #later li", { hasText: title }).getByText(title).click();
    },

    // Later is collapsed by default.
    openLater: async () => {
      const trigger = strawboarPage.getLaterTrigger();
      if ((await trigger.getAttribute("aria-expanded")) !== "true") {
        await trigger.click();
      }
      await expect(trigger).toHaveAttribute("aria-expanded", "true");
    },

    // "Done" is collapsed by default.
    openRecent: async () => {
      const trigger = strawboarPage.getRecentTrigger();
      if ((await trigger.getAttribute("aria-expanded")) !== "true") {
        await trigger.click();
      }
      await expect(trigger).toHaveAttribute("aria-expanded", "true");
    },

    complete: async (title: string) => {
      await strawboarPage.getDoneButton(title).click();
    },

    undoFromToast: async () => {
      await strawboarPage.getUndoToastButton().click();
    },

    openRecentChore: async (title: string) => {
      await strawboarPage.openRecent();
      await strawboarPage.getRecentRow(title).first().getByText(title).click();
    },

    undoFromHistory: async () => {
      await strawboarPage.getHistoryUndoButton().click();
    },

    filterByLabel: async (name: string) => {
      await strawboarPage.getLabelFilterButton(name).click();
    },

    save: async () => {
      await strawboarPage.getSaveButton().click();
    },

    close: async () => {
      await strawboarPage.getCloseButton().click();
    },

    archive: async () => {
      await strawboarPage.getArchiveButton().click();
    },

    // The left edge is outside of the panel on every viewport.
    tapOutsideEditor: async ({ hasTouch }: { hasTouch: boolean }) => {
      if (hasTouch) {
        await page.touchscreen.tap(8, 300);
      } else {
        await page.mouse.click(8, 300);
      }
    },

    isNarrow: () => page.viewportSize()!.width < 640,

    getDefinitionsScroll: () =>
      strawboarPage.getDefinitionsInput().evaluate((textarea) => ({
        panel: textarea.closest("dialog")!.scrollTop,
        textarea: textarea.scrollTop,
      })),

    getOverflow: () =>
      page.evaluate(() => {
        const root = document.scrollingElement!;
        return {
          x: root.scrollWidth - root.clientWidth,
          y: root.scrollHeight - root.clientHeight,
        };
      }),
  };

  return strawboarPage;
}
