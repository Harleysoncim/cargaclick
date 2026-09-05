const { defineConfig, devices } = require("@playwright/test")

module.exports = defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: process.env.CI ? [["html", { open: "never" }], ["github"]] : "list",
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000",
    trace: "on-first-retry",
    screenshot: "only-on-failure"
  },
  projects: [{ name: "chromium", use: { ...devices["Desktop Chrome"] } }],
  webServer: process.env.CI ? undefined : {
    command: "bundle exec rails server -e test -b 127.0.0.1 -p 3000",
    url: "http://127.0.0.1:3000/",
    reuseExistingServer: true,
    timeout: 120_000
  }
})
