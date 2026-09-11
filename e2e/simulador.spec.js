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

  test("renderiza a home com saudação", async ({ page }) => {
    await page.goto("/")

    // Verifica que a página carrega e tem o título correto
    await expect(page).toHaveTitle(/CargaClick/)

    // Verifica se há conteúdo "Bem-vindo" na página
    await expect(page.locator("text=/Bem-vindo/")).toBeVisible()
  })
})