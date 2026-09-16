// ==============================================================
// tests/unit/example.test.ts
// Teste de exemplo que demonstra o uso dos helpers de setup
// e padrões recomendados: Arrange-Act-Assert, mocks de bindings
// Cloudflare, validação Zod, e testes negativos.
// ==============================================================

import { describe, it, expect, vi } from 'vitest';
import { z } from 'zod';
import {
  mockDB,
  mockKV,
  mockR2,
  mockAI,
  mockPlatform,
  mockRequestEvent,
  formData,
  readJson
} from '../setup';

// ==============================================================
// 1. Validação com Zod (padrão: valide todo input)
// ==============================================================

describe('validação de input com Zod', () => {
  const CreateUserSchema = z.object({
    email: z.string().email(),
    name: z.string().min(1).max(100),
    age: z.number().int().min(0).max(150).optional()
  });

  it('aceita payload válido', () => {
    const result = CreateUserSchema.parse({
      email: 'user@example.com',
      name: 'Alice'
    });
    expect(result.email).toBe('user@example.com');
    expect(result.name).toBe('Alice');
  });

  it('rejeita email inválido', () => {
    expect(() =>
      CreateUserSchema.parse({ email: 'not-an-email', name: 'Bob' })
    ).toThrow();
  });

  it('rejeita nome vazio', () => {
    expect(() =>
      CreateUserSchema.parse({ email: 'user@example.com', name: '' })
    ).toThrow();
  });

  it('aplica defaults e campos opcionais', () => {
    const result = CreateUserSchema.parse({
      email: 'user@example.com',
      name: 'Carol',
      age: 30
    });
    expect(result.age).toBe(30);
  });
});

// ==============================================================
// 2. Mock de D1 — padrão de uso com .bind()
// ==============================================================

describe('D1 — padrão de uso', () => {
  it('executa query com bind e retorna resultado', async () => {
    const db = mockDB();
    db._statement.first.mockResolvedValue({ id: '1', email: 'user@example.com' });

    const stmt = db.prepare('SELECT * FROM users WHERE id = ?').bind('1');
    const row = await stmt.first();

    expect(db.prepare).toHaveBeenCalledWith(
      'SELECT * FROM users WHERE id = ?'
    );
    expect(db._statement.bind).toHaveBeenCalledWith('1');
    expect(row).toEqual({ id: '1', email: 'user@example.com' });
  });

  it('rejeita SQL concatenado (regra de ouro)', () => {
    const db = mockDB();
    const userId = "1' OR '1'='1";

    // Padrão PROIBIDO:
    const badQuery = `SELECT * FROM users WHERE id = '${userId}'`;

    // Padrão CORRETO:
    const goodQuery = 'SELECT * FROM users WHERE id = ?';

    expect(badQuery).toContain(userId); // demonstra o risco
    expect(goodQuery).not.toContain(userId); // seguro
  });
});

// ==============================================================
// 3. Mock de KV — TTL explícito obrigatório
// ==============================================================

describe('KV — TTL explícito', () => {
  it('armazena com expirationTtl', async () => {
    const kv = mockKV();

    await kv.put('cache:user:1', JSON.stringify({ id: '1' }), {
      expirationTtl: 300
    });

    expect(kv.put).toHaveBeenCalledWith(
      'cache:user:1',
      expect.any(String),
      expect.objectContaining({ expirationTtl: 300 })
    );
  });

  it('retorna null em cache miss', async () => {
    const kv = mockKV();
    const value = await kv.get('cache:missing');
    expect(value).toBeNull();
  });
});

// ==============================================================
// 4. Mock de R2 — bucket privado + signed URL
// ==============================================================

describe('R2 — padrão de uso', () => {
  it('faz upload com content-type explícito', async () => {
    const r2 = mockR2();
    const stream = new Blob(['hello']).stream();

    await r2.put('tenant/2026/09/uuid.png', stream, {
      httpMetadata: { contentType: 'image/png' }
    });

    expect(r2.put).toHaveBeenCalledWith(
      'tenant/2026/09/uuid.png',
      expect.anything(),
      expect.objectContaining({
        httpMetadata: { contentType: 'image/png' }
      })
    );
  });
});

// ==============================================================
// 5. Mock de AI Gateway — sempre via gateway, nunca direto
// ==============================================================

describe('AI Gateway — regra de provider', () => {
  it('mock de AI binding funciona', async () => {
    const ai = mockAI();
    ai.run.mockResolvedValueOnce({ response: 'olá' });

    const result = await ai.run('@cf/meta/llama-3-8b', {
      messages: [{ role: 'user', content: 'oi' }]
    });

    expect(result).toEqual({ response: 'olá' });
    expect(ai.run).toHaveBeenCalledOnce();
  });

  it('URL de gateway está presente no env', () => {
    const { env } = mockPlatform();
    expect(env.AI_GATEWAY_URL).toMatch(/gateway\.ai\.cloudflare\.com/);
  });
});

// ==============================================================
// 6. RequestEvent mockado — simula form action
// ==============================================================

describe('RequestEvent — form action', () => {
  it('lê FormData corretamente', async () => {
    const fd = formData({ email: 'user@example.com', name: 'Alice' });

    const event = mockRequestEvent({
      method: 'POST',
      url: 'http://localhost/register',
      body: fd
    });

    const parsed = await event.request.formData();
    expect(parsed.get('email')).toBe('user@example.com');
    expect(parsed.get('name')).toBe('Alice');
  });

  it('expõe env via platform', () => {
    const event = mockRequestEvent();
    expect(event.platform.env.DB).toBeDefined();
    expect(event.platform.env.CACHE).toBeDefined();
    expect(event.platform.env.STORAGE).toBeDefined();
    expect(event.platform.env.AI).toBeDefined();
  });

  it('permite setar e ler cookies', () => {
    const event = mockRequestEvent({ cookies: { sid: 'abc' } });

    expect(event.cookies.get('sid')).toBe('abc');

    event.cookies.set('sid', 'xyz', { path: '/' });
    expect(event.cookies.get('sid')).toBe('xyz');

    event.cookies.delete('sid', { path: '/' });
    expect(event.cookies.get('sid')).toBeUndefined();
  });

  it('retorna IP do cliente', () => {
    const event = mockRequestEvent();
    expect(event.getClientAddress()).toBe('127.0.0.1');
  });
});

// ==============================================================
// 7. Leitura de Response JSON
// ==============================================================

describe('utilitário readJson', () => {
  it('lê JSON de um Response', async () => {
    const res = new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { 'content-type': 'application/json' }
    });

    const data = await readJson<{ ok: boolean }>(res);
    expect(data.ok).toBe(true);
  });
});

// ==============================================================
// 8. Padrão de spy/mock de função
// ==============================================================

describe('spies e mocks', () => {
  it('verifica chamadas com mock', () => {
    const fn = vi.fn().mockReturnValue(42);
    const result = fn('a', 'b');

    expect(result).toBe(42);
    expect(fn).toHaveBeenCalledOnce();
    expect(fn).toHaveBeenCalledWith('a', 'b');
  });

  it('mock de módulo com vi.mock (documentação)', () => {
    // Exemplo (não executado): 
    // vi.mock('$server/session', () => ({
    //   validateSession: vi.fn().mockResolvedValue({ user: { id: '1' } })
    // }));
    expect(true).toBe(true);
  });
});
