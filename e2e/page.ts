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

    getDueRows: () => page.locator("#due li"),
    getDueRow: (title: string) => page.locator("#due li", { hasText: title }),
    getLaterSection: (title: string) => page.locator("#later", { hasText: title }),
    getLaterRow: (title: string) => page.locator("#later li", { hasText: title }),
    getCurrentRow: () => page.locator('li[aria-current="true"]'),
    getDoneButton: (title: string) => page.getByRole("button", { name: `Done: ${title}` }),

    getRecent: () => recent,
    getRecentRow: (title: string) => recent.locator("li", { hasText: title }),
    getRecentUndoButton: (title: string) => recent.getByRole("button", { name: `Undo: ${title}` }),

    getUndoToast: () => undoToast,
    getUndoToastButton: () => undoToast.getByRole("button", { name: "Undo" }),

    getLabelFilter: () => labelFilter,
    getLabelFilterButtons: () => labelFilter.getByRole("button"),
    getLabelFilterButton: (name: string) => labelFilter.getByRole("button", { name }),
    getRowLabels: (title: string) =>
      page.locator("#due li, #later li", { hasText: title }).locator('[data-slot="badge"]'),

    getAddButton: () => page.getByRole("button", { name: "+ Add chore" }),
    getEditor: () => editor,
    getEditorBackdrop: () => page.locator("#editor-backdrop"),
    getTitleInput: () => editor.getByLabel("Title"),
    getIntervalInput: () => editor.getByLabel("Every (days)"),
    getLabelToggle: (name: string) =>
      editor.getByRole("group", { name: "Labels" }).getByRole("button", { name, exact: true }),
    getFirstDueInput: () => editor.getByLabel("First due"),
    getEditorError: () => editor.locator("#chore-editor-error"),
    getHistory: () => editor.locator("#chore-history"),
    getSaveButton: () => editor.getByRole("button", { name: "Save" }),
    getCloseButton: () => editor.getByRole("button", { name: "Close" }),
    getArchiveButton: () => editor.getByRole("button", { name: "Archive" }),

    getLabelsButton: () => editor.getByRole("button", { name: "Edit labels", exact: true }),
    getLabelList: () => editor.locator("#label-list"),
    getLabelListButton: (name: string) => editor.getByRole("button", { name: `Edit label: ${name}` }),
    getLabelNameInput: () => editor.getByLabel("Name"),
    getLabelColorButton: (color: string) =>
      editor.getByRole("group", { name: "Color" }).getByRole("button", { name: color, exact: true }),
    getAddLabelButton: () => editor.getByRole("button", { name: "Add label" }),
    getDeleteLabelButton: () => editor.getByRole("button", { name: "Delete" }),
    getLabelFormError: () => editor.locator("#label-form-error"),

    getTransferButton: () => page.getByRole("button", { name: "Import / Export" }),
    getDefinitionsInput: () => editor.getByLabel("Labels and chores (JSON)"),
    getImportButton: () => editor.getByRole("button", { name: "Import", exact: true }),
    getTransferError: () => editor.locator("#transfer-error"),

    openTransfer: async () => {
      await strawboarPage.getTransferButton().click();
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

    // Through the chore editor, which offers it even when there is no label yet.
    openLabels: async () => {
      await strawboarPage.getAddButton().click();
      await strawboarPage.getLabelsButton().click();
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
      await page.locator("#due li, #later li", { hasText: title }).getByText(title).click();
    },

    complete: async (title: string) => {
      await strawboarPage.getDoneButton(title).click();
    },

    undoFromToast: async () => {
      await strawboarPage.getUndoToastButton().click();
    },

    undoFromRecent: async (title: string) => {
      await strawboarPage.getRecentUndoButton(title).click();
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
