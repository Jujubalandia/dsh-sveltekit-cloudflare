import type { Handle } from '@sveltejs/kit';

/**
 * Headers de segurança aplicados a tudo que passa pelo Worker.
 *
 * Espelham `static/_headers`, que o Cloudflare Pages aplica a assets
 * estáticos. Manter os dois em sincronia evita que uma rota SSR saia sem
 * `nosniff` enquanto um arquivo estático sai com ele.
 *
 * CSP fica de fora de propósito: exige nonce (`kit.csp`) e reverificação do
 * dark mode, que depende de um script inline no `app.html`.
 */
const SECURITY_HEADERS = {
  'x-content-type-options': 'nosniff',
  'x-frame-options': 'DENY',
  'referrer-policy': 'strict-origin-when-cross-origin',
  'permissions-policy': 'camera=(), microphone=(), geolocation=(), payment=()',
  'strict-transport-security': 'max-age=31536000; includeSubDomains'
} as const;

export const handle: Handle = async ({ event, resolve }) => {
  const response = await resolve(event);

  for (const [name, value] of Object.entries(SECURITY_HEADERS)) {
    response.headers.set(name, value);
  }

  return response;
};
