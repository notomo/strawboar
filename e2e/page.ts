import { expect, type Page } from "@playwright/test";

// `failFirstLoad` makes the first `GET /api/chores` fail, like when the Access session has expired.
export async function openPage({ page, failFirstLoad = false }: { page: Page; failFirstLoad?: boolean }) {
  if (failFirstLoad) {
    await page.route("**/api/chores", (route) => route.abort(), { times: 1 });
  }
  // Skip the transitions of panels and dialogs, which every action would wait for. Kept after reload.
  await page.addInitScript(() => {
    document.addEventListener("DOMContentLoaded", () => {
      const style = document.createElement("style");
      style.textContent =
        "*, *::before, *::after, ::backdrop { transition-duration: 0s !important; transition-delay: 0s !important; animation-duration: 0s !important; }";
      document.head.append(style);
    });
  });
  await page.goto("/");

  const editor = page.getByRole("dialog");
  const labelFilter = page.locator("#label-filter");
  const recent = page.locator("#recent");
  const undoToast = page.locator("#undo-toast");
  const confirmDialog = page.getByRole("alertdialog");

  const strawboarPage = {
    reload: async () => {
      await page.reload();
    },
    reloadPageAfterFailure: async () => {
      await page.getByRole("button", { name: "Reload page" }).click();
    },

    getToday: () => page.locator("#today"),
    getText: (text: string) => page.getByText(text),

    getSoonTab: () => page.locator("#soon-tab"),
    getSoonCaption: () => page.locator("#soon-caption"),
    getSoonRows: () => page.locator("#soon li"),
    getSoonRow: (title: string) => page.locator("#soon li", { hasText: title }),
    getLaterTab: () => page.locator("#later-tab"),
    getLaterRow: (title: string) => page.locator("#later li", { hasText: title }),
    getCurrentRow: () => page.locator('li[aria-current="true"]'),
    getDoneButton: (title: string) => page.getByRole("button", { name: `Done: ${title}` }),

    getRecent: () => recent,
    getRecentTab: () => page.locator("#recent-tab"),
    getRecentCaption: () => page.locator("#recent-caption"),
    getRecentRow: (title: string) => recent.locator("li", { hasText: title }),

    getUndoToast: () => undoToast,
    getUndoToastButton: () => undoToast.getByRole("button", { name: "Undo" }),

    getLabelFilter: () => labelFilter,
    getLabelFilterButtons: () => labelFilter.getByRole("button"),
    getLabelFilterButton: (name: string) => labelFilter.getByRole("button", { name }),
    getRowLabels: (title: string) =>
      page.locator("#soon li, #later li", { hasText: title }).locator('[data-slot="badge"]'),

    getAddButton: () => page.getByRole("button", { name: "+ Add" }),
    getEditor: () => editor,
    getEditorBackdrop: () => page.locator("#editor-backdrop"),
    getTitleInput: () => editor.getByLabel("Title"),
    getDescriptionInput: () => editor.getByLabel("Description"),
    getIntervalInput: () => editor.getByLabel("Every (days)"),
    getRepeatTab: (name: string) =>
      editor.getByRole("tablist", { name: "Repeat" }).getByRole("tab", { name, exact: true }),
    getMonthsInput: () => editor.getByLabel("Every (months)"),
    getDayInput: () => editor.getByLabel("Day of month"),
    getLeadDaysInput: () => editor.getByLabel("Soon from (days before)"),
    getLabelToggle: (name: string) =>
      editor.getByRole("group", { name: "Labels" }).getByRole("button", { name, exact: true }),
    getFirstDueInput: () => editor.getByLabel("First due"),
    getEditorError: () => editor.locator("#chore-editor-error"),
    getSaveButton: () => editor.getByRole("button", { name: "Save" }),
    getCloseButton: () => editor.getByRole("button", { name: "Close" }),
    getChoreMenuButton: () => editor.getByRole("button", { name: "Chore actions" }),

    getConfirmDialog: () => confirmDialog,
    getConfirmButton: (name: string) => confirmDialog.getByRole("button", { name, exact: true }),
    getConfirmCancelButton: () => confirmDialog.getByRole("button", { name: "Cancel" }),

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
      await strawboarPage.getRepeatTab("Monthly").click();
      await strawboarPage.getMonthsInput().fill("1");
      await strawboarPage.getLeadDaysInput().fill(leadDays);
      await strawboarPage.getFirstDueInput().fill(firstDue);
      await strawboarPage.getSaveButton().click();
      await expect(editor).toBeHidden();
    },

    openLabels: async () => {
      await strawboarPage.getMenuButton().click();
      await strawboarPage.getMenuItem("Labels").click();
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

    // Waits for the form to switch so that typing right after it is not overwritten by the re-render.
    selectLabel: async (name: string) => {
      const button = strawboarPage.getLabelListButton(name);
      const current = await button.getAttribute("aria-current");
      await button.click();
      await expect(button).toHaveAttribute("aria-current", current === "true" ? "false" : "true");
    },

    deleteLabel: async () => {
      await strawboarPage.getDeleteLabelButton().click();
      await strawboarPage.getConfirmButton("Delete").click();
    },

    openChore: async (title: string) => {
      await page.locator("#soon li, #later li", { hasText: title }).getByText(title).click();
    },

    // Soon is selected by default.
    openSoon: async () => {
      await strawboarPage.getSoonTab().click();
      await expect(strawboarPage.getSoonTab()).toHaveAttribute("aria-selected", "true");
    },

    openLater: async () => {
      await strawboarPage.getLaterTab().click();
      await expect(strawboarPage.getLaterTab()).toHaveAttribute("aria-selected", "true");
    },

    openRecent: async () => {
      await strawboarPage.getRecentTab().click();
      await expect(strawboarPage.getRecentTab()).toHaveAttribute("aria-selected", "true");
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

    // Asks to undo the latest completion of the chore in the panel.
    askUndoLastDone: async () => {
      await strawboarPage.openChoreMenuItem("Undo last done");
      await expect(confirmDialog).toBeVisible();
    },

    undoLastDone: async () => {
      await strawboarPage.askUndoLastDone();
      await strawboarPage.getConfirmButton("Undo").click();
      await expect(confirmDialog).toBeHidden();
    },

    toggleLabelFilter: async (name: string) => {
      await strawboarPage.getLabelFilterButton(name).click();
    },

    save: async () => {
      await strawboarPage.getSaveButton().click();
    },

    close: async () => {
      await strawboarPage.getCloseButton().click();
    },

    openChoreMenuItem: async (name: string) => {
      await strawboarPage.getChoreMenuButton().click();
      await strawboarPage.getMenuItem(name).click();
    },

    archive: async () => {
      await strawboarPage.openChoreMenuItem("Archive");
      await strawboarPage.getConfirmButton("Archive").click();
    },

    // Asks to archive the chore in the panel and cancels it.
    cancelArchive: async () => {
      await strawboarPage.openChoreMenuItem("Archive");
      await expect(confirmDialog).toBeVisible();
      await strawboarPage.getConfirmCancelButton().click();
      await expect(confirmDialog).toBeHidden();
    },

    // Asks to archive the chore in the panel and dismisses it by clicking outside of it.
    dismissArchive: async () => {
      await strawboarPage.openChoreMenuItem("Archive");
      await expect(confirmDialog).toBeVisible();
      await page.mouse.click(8, 8);
      await expect(confirmDialog).toBeHidden();
    },

    // The left edge is outside of the panel on every viewport.
    // On the sticky header or below it.
    tapOutsideEditor: async ({ hasTouch, onHeader = false }: { hasTouch: boolean; onHeader?: boolean }) => {
      const y = onHeader ? 8 : 300;
      if (hasTouch) {
        await page.touchscreen.tap(8, y);
      } else {
        await page.mouse.click(8, y);
      }
    },

    isNarrow: () => page.viewportSize()!.width < 640,

    getDefinitionsScroll: () =>
      strawboarPage.getDefinitionsInput().evaluate((textarea) => ({
        panel: textarea.closest("dialog")!.scrollTop,
        textarea: textarea.scrollTop,
      })),

    scrollToBottom: async () => {
      await page.locator("#dashboard").evaluate((element) => element.scrollTo(0, element.scrollHeight));
    },

    // Of the page and of the dashboard scrolled below the header.
    getOverflow: () =>
      page.evaluate(() =>
        [document.scrollingElement!, document.getElementById("dashboard")!]
          .map((element) => ({
            x: element.scrollWidth - element.clientWidth,
            y: element.scrollHeight - element.clientHeight,
          }))
          .reduce((a, b) => ({ x: Math.max(a.x, b.x), y: Math.max(a.y, b.y) })),
      ),
  };

  return strawboarPage;
}
