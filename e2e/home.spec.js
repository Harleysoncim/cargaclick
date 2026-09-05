const { test, expect } = require("@playwright/test")

test("loads the real Rails home page", async ({ page }) => {
  const response = await page.goto("/")

  expect(response).not.toBeNull()
  if (response.status() !== 200) {
    const body = (await page.locator("body").innerText()).slice(0, 4000)
    throw new Error(`Rails returned HTTP ${response.status()} for /:\n${body}`)
  }
  await expect(page).toHaveTitle(/CargaClick/i)
  await expect(page.locator("body")).toBeVisible()
})
