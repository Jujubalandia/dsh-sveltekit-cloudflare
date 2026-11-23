import { describe, expect, it } from 'vitest';
import { emailSchema, parseEmail } from './validation.js';

describe('emailSchema', () => {
  it('normaliza espaços e caixa alta', () => {
    expect(emailSchema.parse('  User@Example.COM  ')).toBe('user@example.com');
  });

  it('rejeita string vazia', () => {
    expect(emailSchema.safeParse('').success).toBe(false);
  });

  it('rejeita e-mail sem domínio', () => {
    expect(emailSchema.safeParse('nao-e-email').success).toBe(false);
  });
});

describe('parseEmail', () => {
  it('devolve ok com o valor normalizado', () => {
    const result = parseEmail('  Maria@Dominio.com ');
    expect(result).toEqual({ ok: true, value: 'maria@dominio.com' });
  });

  it('devolve a mensagem de campo vazio', () => {
    const result = parseEmail('');
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toBe('Informe um e-mail.');
  });

  it('devolve a mensagem de formato inválido', () => {
    const result = parseEmail('sem-arroba');
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toBe('E-mail inválido.');
  });

  it('rejeita e-mail acima de 254 caracteres', () => {
    const result = parseEmail(`${'a'.repeat(250)}@x.com`);
    expect(result.ok).toBe(false);
    if (!result.ok) expect(result.error).toBe('E-mail longo demais.');
  });
});
