import { z } from 'zod';

/**
 * Schemas de validação compartilhados pelo app.
 *
 * Existem para que o Gate 2 (input validado com Zod) tenha onde morar: toda
 * entrada vinda do usuário é parseada aqui, nunca no componente, e nunca com
 * `as` ou `!` para calar o TypeScript.
 */

/** E-mail de formulário. Normaliza antes de validar para não duplicar caixa. */
export const emailSchema = z
  .string()
  .trim()
  .min(1, 'Informe um e-mail.')
  .max(254, 'E-mail longo demais.')
  .email('E-mail inválido.')
  .transform((value) => value.toLowerCase());

export type Email = z.infer<typeof emailSchema>;

/** Resultado discriminado de uma validação, sem lançar exceção. */
export type ParseResult<T> = { ok: true; value: T } | { ok: false; error: string };

/**
 * Valida um e-mail sem lançar.
 * @param raw - o valor cru do formulário.
 * @returns o e-mail normalizado, ou a primeira mensagem de erro.
 */
export function parseEmail(raw: string): ParseResult<Email> {
  const parsed = emailSchema.safeParse(raw);
  if (parsed.success) return { ok: true, value: parsed.data };
  return { ok: false, error: parsed.error.issues[0]?.message ?? 'E-mail inválido.' };
}
