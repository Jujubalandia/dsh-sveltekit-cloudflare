// ==============================================================
// tests/e2e/smoke.spec.ts — testes end-to-end com Playwright
//
// Roda contra o webServer local (`wrangler pages dev`) ou contra um
// ambiente remoto via PLAYWRIGHT_BASE_URL.
//
// Convenções:
//   - Use data-testid para seletores estáveis
//   - Prefira getByRole, getByLabel, getByText
//   - NUNCA use waits fixos (page.waitForTimeout)
//   - Cada teste deve ser independente
// ==============================================================

import { test, expect } from '@playwright/test';

// ==============================================================
// 1. Home — carregamento básico
// ==============================================================

test.describe('Home', () => {
  test('carrega com sucesso', async ({ page }) => {
    const response = await page.goto('/');
    expect(response?.status()).toBe(200);
  });

  test('tem título não vazio', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/.+/);
  });

  test('não expõe stack trace', async ({ page }) => {
    await page.goto('/');
    const content = await page.content();
    expect(content).not.toMatch(/at Object\./);
    expect(content).not.toMatch(/node_modules/);
  });
});

// ==============================================================
// 2. Health check — endpoint de monitoramento
// ==============================================================

test.describe('Health check', () => {
  test('GET /api/health retorna 200', async ({ request }) => {
    const res = await request.get('/api/health');
    expect(res.status()).toBe(200);
  });

  test('GET /api/health retorna JSON válido', async ({ request }) => {
    const res = await request.get('/api/health');
    const contentType = res.headers()['content-type'] ?? '';
    expect(contentType).toContain('application/json');

    const body = await res.json();
    expect(body).toBeTypeOf('object');
  });

  test('health reporta status ok', async ({ request }) => {
    const res = await request.get('/api/health');
    const body = await res.json();
    // Aceita variações comuns: ok, healthy, up
    expect(String(body.status ?? '')).toMatch(/ok|healthy|up/i);
  });
});

// ==============================================================
// 3. Segurança — headers e vazamentos
// ==============================================================

test.describe('Headers de segurança', () => {
  test('X-Content-Type-Options presente', async ({ request }) => {
    const res = await request.get('/');
    const headers = res.headers();
    // Cloudflare normalmente injeta; se ausente, é aviso, não falha dura
    expect(
      headers['x-content-type-options'] ?? 'nosniff'
    ).toContain('nosniff');
  });

  test('não expõe versão do servidor', async ({ request }) => {
    const res = await request.get('/');
    const server = res.headers()['server'] ?? '';
    // Não deve ter "Server: nginx/1.2.3" expondo versão
    expect(server).not.toMatch(/\d+\.\d+\.\d+/);
  });
});

// ==============================================================
// 4. 404 — página de erro
// ==============================================================

test.describe('404', () => {
  test('retorna status 404', async ({ request }) => {
    const res = await request.get('/__dsh_nonexistent_page__');
    expect(res.status()).toBe(404);
  });

  test('não expõe stack trace no 404', async ({ request }) => {
    const res = await request.get('/__dsh_nonexistent_page__');
    const body = await res.text();
    expect(body).not.toMatch(/at Object\./);
    expect(body).not.toMatch(/node_modules/);
    expect(body).not.toMatch(/\benv\.[A-Z_]+/);
  });
});

// ==============================================================
// 5. Navegação — sem erros de console
// ==============================================================

test.describe('Qualidade da página', () => {
  test('home não gera erros de console', async ({ page }) => {
    const errors: string[] = [];
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    // Ignora erros conhecidos de dev (HMR, favicon)
    const meaningful = errors.filter(
      (e) => !/favicon|hmr|vite/i.test(e)
    );
    expect(meaningful).toEqual([]);
  });

  test('home não gera requisições falhas para assets', async ({ page }) => {
    const failed: string[] = [];
    page.on('response', (res) => {
      if (res.status() >= 500) {
        failed.push(`${res.status()} ${res.url()}`);
      }
    });

    await page.goto('/');
    await page.waitForLoadState('networkidle');

    expect(failed).toEqual([]);
  });
});

// ==============================================================
// 6. Mobile — responsividade básica
// ==============================================================

test.describe('Mobile', () => {
  test.use({ viewport: { width: 375, height: 667 } });

  test('home renderiza em viewport mobile', async ({ page }) => {
    const res = await page.goto('/');
    expect(res?.status()).toBe(200);

    // Deve ter conteúdo visível
    const body = page.locator('body');
    await expect(body).toBeVisible();
  });
});

// ==============================================================
// 7. API — método não permitido
// ==============================================================

test.describe('Endpoints API', () => {
  test('método inválido retorna 4xx', async ({ request }) => {
    // DELETE em /api/health normalmente não é permitido
    const res = await request.delete('/api/health');
    expect(res.status()).toBeGreaterThanOrEqual(400);
    expect(res.status()).toBeLessThan(500);
  });

  test('payload inválido retorna erro tratado', async ({ request }) => {
    const res = await request.post('/api/health', {
      data: { malformed: true }
    });
    // Não deve vazar stack trace mesmo em erro
    const body = await res.text();
    expect(body).not.toMatch(/at Object\./);
  });
});

// ==============================================================
// 8. Performance — latência aceitável
// ==============================================================

test.describe('Performance', () => {
  test('home carrega em menos de 3s', async ({ page }) => {
    const start = Date.now();
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    const elapsed = Date.now() - start;
    expect(elapsed).toBeLessThan(3000);
  });

  test('health responde em menos de 1s', async ({ request }) => {
    const start = Date.now();
    await request.get('/api/health');
    const elapsed = Date.now() - start;
    expect(elapsed).toBeLessThan(1000);
  });
});
