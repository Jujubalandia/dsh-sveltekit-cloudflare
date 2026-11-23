// ==============================================================
// tests/e2e/shadcn.spec.ts — prova de que o shadcn-svelte está integrado
//
// Cobre os oito componentes que o kit entrega: button, card, input, label,
// dialog, dropdown-menu, table e sonner. Se um deles parar de montar, de
// hidratar ou de responder a interação, este arquivo falha.
//
// Convenções do projeto: getByRole/getByLabel, zero waitForTimeout.
// ==============================================================

import { test, expect } from '@playwright/test';

test.describe('shadcn-svelte', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
  });

  test('renderiza a página de prova', async ({ page }) => {
    await expect(
      page.getByRole('heading', { level: 1, name: /Página de prova dos componentes/i })
    ).toBeVisible();
  });

  test('Card e CardHeader montam', async ({ page }) => {
    // Os cards têm data-slot, gerado pelos componentes do shadcn.
    await expect(page.locator('[data-slot="card"]')).toHaveCount(3);
    await expect(page.getByText('Formulário', { exact: true })).toBeVisible();
    await expect(page.getByText('Overlays', { exact: true })).toBeVisible();
    await expect(page.getByText('Tabela', { exact: true })).toBeVisible();
  });

  test('Label e Input são associados e aceitam digitação', async ({ page }) => {
    const email = page.getByLabel('E-mail');
    await expect(email).toBeVisible();
    await email.fill('user@example.com');
    await expect(email).toHaveValue('user@example.com');
  });

  test('Button dispara ação e valida com Zod', async ({ page }) => {
    await page.getByLabel('E-mail').fill('nao-e-email');
    await page.getByRole('button', { name: 'Enviar' }).click();

    // Gate 2: o schema recusa e o toast de erro aparece.
    await expect(page.getByText('E-mail inválido.')).toBeVisible();
  });

  test('Button aceita entrada válida', async ({ page }) => {
    await page.getByLabel('E-mail').fill('  User@Example.COM ');
    await page.getByRole('button', { name: 'Enviar' }).click();

    // O schema normaliza antes de usar.
    await expect(page.getByText(/user@example\.com/)).toBeVisible();
  });

  test('Dialog abre, mostra conteúdo e fecha', async ({ page }) => {
    await page.getByRole('button', { name: 'Abrir dialog' }).click();

    const dialog = page.getByRole('dialog');
    await expect(dialog).toBeVisible();
    await expect(dialog.getByText('Confirmar operação')).toBeVisible();

    await dialog.getByRole('button', { name: 'Confirmar' }).click();
    await expect(dialog).toBeHidden();
  });

  test('DropdownMenu abre e lista itens', async ({ page }) => {
    await page.getByRole('button', { name: 'Abrir menu' }).click();

    const menu = page.getByRole('menu');
    await expect(menu).toBeVisible();
    await expect(menu.getByRole('menuitem', { name: 'Documentação' })).toBeVisible();
    await expect(menu.getByRole('menuitem', { name: 'Repositório' })).toBeVisible();
  });

  test('Table renderiza header, body e caption', async ({ page }) => {
    const table = page.locator('[data-slot="table"]');
    await expect(table).toBeVisible();
    await expect(page.getByRole('columnheader', { name: 'Binding' })).toBeVisible();
    await expect(page.getByRole('cell', { name: 'env.DB' })).toBeVisible();
    await expect(page.getByText('Bindings do Cloudflare que o harness cobre.')).toBeVisible();
  });

  test('Sonner dispara toast', async ({ page }) => {
    await page.getByRole('button', { name: 'Disparar toast' }).click();
    await expect(page.getByText('Toast de exemplo')).toBeVisible();
  });

  test('toggle de tema alterna a classe dark', async ({ page }) => {
    const html = page.locator('html');
    const wasDark = await html.evaluate((el) => el.classList.contains('dark'));

    await page.getByRole('button', { name: /Alternar entre tema claro e escuro/i }).click();

    await expect
      .poll(async () => html.evaluate((el) => el.classList.contains('dark')))
      .toBe(!wasDark);
  });

  test('CSS do Tailwind foi aplicado', async ({ page }) => {
    // Se o Tailwind não tivesse compilado, o body não teria as custom
    // properties do tema do shadcn.
    const bg = await page.evaluate(() =>
      getComputedStyle(document.body).getPropertyValue('background-color')
    );
    expect(bg).not.toBe('');
    expect(bg).not.toBe('rgba(0, 0, 0, 0)');
  });
});
