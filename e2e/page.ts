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

    getAddButton: () => page.getByRole("button", { name: "Add" }),
    getEditor: () => editor,
    getEditorBackdrop: () => page.locator("#editor-backdrop"),
    getTitleInput: () => editor.getByLabel("Title"),
    getIntervalInput: () => editor.getByLabel("Every (days)"),
    getLabelsInput: () => editor.getByLabel("Labels"),
    getFirstDueInput: () => editor.getByLabel("First due"),
    getEditorError: () => editor.locator("#chore-editor-error"),
    getHistory: () => editor.locator("#chore-history"),
    getSaveButton: () => editor.getByRole("button", { name: "Save" }),
    getCloseButton: () => editor.getByRole("button", { name: "Close" }),
    getArchiveButton: () => editor.getByRole("button", { name: "Archive" }),

    addChore: async (title: string, interval: string, labels = "") => {
      await strawboarPage.getAddButton().click();
      await strawboarPage.getTitleInput().fill(title);
      await strawboarPage.getIntervalInput().fill(interval);
      await strawboarPage.getLabelsInput().fill(labels);
      await strawboarPage.getSaveButton().click();
      await expect(editor).toBeHidden();
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
