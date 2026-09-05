const { test, expect } = require("@playwright/test")

test("loads the real Rails home page", async ({ page }) => {
  const response = await page.goto("/")

  expect(response).not.toBeNull()
  expect(response.status()).toBe(200)
  await expect(page).toHaveTitle(/CargaClick/i)
  await expect(page.locator("body")).toBeVisible()
})
