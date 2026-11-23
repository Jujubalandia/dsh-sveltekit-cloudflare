import { defineConfig, devices } from '@playwright/test';

const isCI = !!process.env.CI;
const baseURL = process.env.PLAYWRIGHT_BASE_URL ?? 'http://127.0.0.1:4173';

export default defineConfig({
  testDir: './tests/e2e',
  timeout: 30_000,
  expect: { timeout: 5_000 },
  fullyParallel: true,
  forbidOnly: isCI,
  retries: isCI ? 2 : 0,
  workers: isCI ? 2 : undefined,

  reporter: isCI
    ? [
        ['github'],
        ['html', { open: 'never', outputFolder: 'playwright-report' }],
        ['json', { outputFile: 'playwright-report/results.json' }]
      ]
    : [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],

  use: {
    baseURL,
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    actionTimeout: 10_000,
    navigationTimeout: 20_000,
    ignoreHTTPSErrors: false,
    extraHTTPHeaders: {
      'x-dsh-test': '1'
    }
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] }
    },
    {
      name: 'mobile',
      use: { ...devices['Pixel 7'] }
    }
  ],

  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        // Serve o BUILD de produção, não o dev server: o e2e precisa pegar
        // problemas de build (CSS do Tailwind, hidratação, chunk quebrado).
        // `wrangler pages dev` exigiria token da Cloudflare por causa do
        // binding de AI, então o preview do adapter é o alvo do teste.
        // `--host 127.0.0.1` é obrigatório: sem ele o Vite escuta em
        // `localhost`, que no runner do GitHub resolve para ::1, e a
        // verificação de saúde em http://127.0.0.1:4173 estoura o timeout.
        command: 'pnpm build && pnpm exec vite preview --host 127.0.0.1 --port 4173',
        url: 'http://127.0.0.1:4173',
        reuseExistingServer: !isCI,
        timeout: 180_000,
        stdout: 'pipe',
        stderr: 'pipe',
        // `env` SUBSTITUI o ambiente do processo filho (não faz merge). Sem
        // repassar process.env, o webServer roda sem HOME, PATH e XDG_*, e o
        // wrangler quebra ao tentar escrever em ~/.config/.wrangler.
        env: {
          ...(process.env as Record<string, string>),
          NODE_ENV: 'test',
          ENVIRONMENT: 'test'
        }
      },

  outputDir: 'test-results/'
});
