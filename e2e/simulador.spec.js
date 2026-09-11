const { test, expect } = require("@playwright/test")

test.describe("simulador de frete", () => {
  test("mantém campos de carga editáveis e acessíveis", async ({ page }) => {
    await page.goto("/simular-frete")

    for (const id of ["origem", "destino", "peso", "volume"]) {
      const input = page.locator(`#${id}`)
      await expect(input).toBeEnabled()
      await expect(input).not.toHaveAttribute("readonly")
      await input.focus()
      await expect(input).toBeFocused()
    }

    await expect(page.locator('label[for="peso"]')).toHaveText("Peso (kg)")
    await expect(page.locator('label[for="volume"]')).toHaveText("Volume (m³)")
    await expect(page.locator("#peso")).toHaveAttribute("inputmode", "decimal")
    await expect(page.locator("#volume")).toHaveAttribute("inputmode", "decimal")
  })

  test("exibe a saudação na home", async ({ page }) => {
    await page.goto("/")
    await page.waitForLoadState("networkidle")

    // Verifica se o h2 com "Bem-vindo" existe
    const heading = page.locator("text=Bem-vindo ao CargaClick!")
    await expect(heading).toBeVisible()

    // Verifica se o emoji com aria-label existe
    const emoji = page.locator('[role="img"][aria-label="Caminhão de entregas"]')
    await expect(emoji).toBeVisible()
  })
})