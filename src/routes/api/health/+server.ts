import { json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

/**
 * Health check para monitoramento e para o smoke test pós-deploy
 * (`scripts/smoke-test.sh`).
 *
 * Não expõe env, versão de runtime nem stack: só o estado. Qualquer
 * informação a mais aqui vira reconhecimento grátis para quem sonda.
 */
export const GET: RequestHandler = () =>
  json({ status: 'ok', timestamp: new Date().toISOString() });
