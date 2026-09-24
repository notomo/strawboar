import { expect, test } from "@playwright/test";

test("shows the summary", async ({ page }) => {
  await page.goto("/");

  await expect(page.getByText("Signed in as dev@example.com")).toBeVisible();
  await expect(page.locator("#chore-count")).toHaveText(/^\d+ chores$/);
});

test("fits in the first view without scrolling", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("#chore-count")).toBeVisible();

  const overflow = await page.evaluate(() => {
    const root = document.scrollingElement!;
    return {
      x: root.scrollWidth - root.clientWidth,
      y: root.scrollHeight - root.clientHeight,
    };
  });
  expect(overflow).toEqual({ x: 0, y: 0 });
});
