// ==============================================================
// tests/setup.ts — mocks e helpers compartilhados pelos testes
//
// Carregado automaticamente pelo Vitest (setupFiles em vitest.config.ts).
// Fornece mocks de bindings Cloudflare (D1, KV, R2, AI) e utilitários.
// ==============================================================

import { vi, beforeEach, afterEach } from 'vitest';

// ==============================================================
// Mocks de bindings Cloudflare
// ==============================================================

/**
 * Mock de D1 (Cloudflare SQL database).
 * Uso:
 *   const db = mockDB();
 *   db.first.mockResolvedValue({ id: '1' });
 */
export const mockDB = () => {
  const statement = {
    bind: vi.fn().mockReturnThis(),
    first: vi.fn(),
    all: vi.fn().mockResolvedValue({ results: [], success: true, meta: {} }),
    run: vi.fn().mockResolvedValue({ success: true, meta: { changes: 0 } }),
    raw: vi.fn().mockResolvedValue([])
  };

  return {
    prepare: vi.fn().mockReturnValue(statement),
    batch: vi.fn().mockResolvedValue([]),
    exec: vi.fn().mockResolvedValue({ count: 0, duration: 0 }),
    dump: vi.fn(),
    _statement: statement
  };
};

/**
 * Mock de KV (Cloudflare key-value store).
 */
export const mockKV = () => ({
  get: vi.fn().mockResolvedValue(null),
  getWithMetadata: vi.fn().mockResolvedValue({ value: null, metadata: null }),
  put: vi.fn().mockResolvedValue(undefined),
  delete: vi.fn().mockResolvedValue(undefined),
  list: vi.fn().mockResolvedValue({ keys: [], list_complete: true, cursor: '' })
});

/**
 * Mock de R2 (Cloudflare object storage).
 */
export const mockR2 = () => ({
  get: vi.fn().mockResolvedValue(null),
  put: vi.fn().mockResolvedValue({ key: 'test', size: 0, etag: 'etag' }),
  delete: vi.fn().mockResolvedValue(undefined),
  head: vi.fn().mockResolvedValue(null),
  list: vi.fn().mockResolvedValue({ objects: [], truncated: false })
});

/**
 * Mock de Workers AI binding.
 */
export const mockAI = () => ({
  run: vi.fn().mockResolvedValue({ response: 'mock response' })
});

// ==============================================================
// Mock de Platform (env + context do Worker)
// ==============================================================

/**
 * Cria um env completo de teste com todos os bindings.
 * Uso:
 *   const { env } = mockPlatform();
 *   env.DB.prepare('SELECT 1').bind().first();
 */
export const mockPlatform = (overrides: Partial<Record<string, unknown>> = {}) => {
  const env = {
    DB: mockDB(),
    CACHE: mockKV(),
    STORAGE: mockR2(),
    AI: mockAI(),
    ENVIRONMENT: 'test',
    LOG_LEVEL: 'silent',
    AI_GATEWAY_URL: 'https://gateway.ai.cloudflare.com/v1/test/gw/openai',
    ...overrides
  };

  const context = {
    waitUntil: vi.fn(),
    passThroughOnException: vi.fn()
  };

  return { env, context };
};

// ==============================================================
// Mock de event do SvelteKit (RequestEvent)
// ==============================================================

export interface MockEventOptions {
  method?: string;
  url?: string;
  body?: unknown;
  headers?: Record<string, string>;
  cookies?: Record<string, string>;
  locals?: Record<string, unknown>;
  params?: Record<string, string>;
  env?: Record<string, unknown>;
}

/**
 * Cria um RequestEvent mockado para testar load/hooks/actions.
 */
export const mockRequestEvent = (opts: MockEventOptions = {}) => {
  const {
    method = 'GET',
    url = 'http://localhost/',
    body = undefined,
    headers = {},
    cookies = {},
    locals = {},
    params = {},
    env = {}
  } = opts;

  const requestInit: RequestInit = { method, headers };
  if (body !== undefined && method !== 'GET' && method !== 'HEAD') {
    requestInit.body =
      typeof body === 'string' ? body : JSON.stringify(body);
    if (!requestInit.headers) requestInit.headers = {};
    (requestInit.headers as Record<string, string>)['content-type'] ??=
      'application/json';
  }

  const cookieJar: Record<string, string> = { ...cookies };

  const event = {
    request: new Request(url, requestInit),
    url: new URL(url),
    params,
    locals,
    platform: mockPlatform(env),

    cookies: {
      get: vi.fn((name: string) => cookieJar[name]),
      set: vi.fn((name: string, value: string) => {
        cookieJar[name] = value;
      }),
      delete: vi.fn((name: string) => {
        delete cookieJar[name];
      }),
      serialize: vi.fn()
    },

    fetch: vi.fn().mockResolvedValue(
      new Response(JSON.stringify({}), {
        status: 200,
        headers: { 'content-type': 'application/json' }
      })
    ),

    getClientAddress: vi.fn().mockReturnValue('127.0.0.1'),
    isDataRequest: false,
    isSubRequest: false,
    route: { id: '/test' },
    setHeaders: vi.fn()
  };

  return event;
};

// ==============================================================
// Utilitários de teste
// ==============================================================

/**
 * Constrói um FormData a partir de um objeto.
 */
export const formData = (data: Record<string, string | Blob>): FormData => {
  const fd = new FormData();
  for (const [key, value] of Object.entries(data)) {
    fd.append(key, value);
  }
  return fd;
};

/**
 * Aguarda N milissegundos.
 */
export const sleep = (ms: number): Promise<void> =>
  new Promise((resolve) => setTimeout(resolve, ms));

/**
 * Lê um Response como JSON tipado.
 */
export const readJson = async <T = unknown>(res: Response): Promise<T> =>
  (await res.json()) as T;

// ==============================================================
// Setup e teardown globais
// ==============================================================

beforeEach(() => {
  // Silencia console.error em testes, a menos que DEBUG=1
  if (!process.env.DEBUG) {
    vi.spyOn(console, 'error').mockImplementation(() => {});
    vi.spyOn(console, 'warn').mockImplementation(() => {});
  }
});

afterEach(() => {
  vi.restoreAllMocks();
  vi.clearAllMocks();
});

// ==============================================================
// Declarações de tipo globais para os mocks (opcional)
// ==============================================================

export type MockDB = ReturnType<typeof mockDB>;
export type MockKV = ReturnType<typeof mockKV>;
export type MockR2 = ReturnType<typeof mockR2>;
export type MockAI = ReturnType<typeof mockAI>;
export type MockPlatform = ReturnType<typeof mockPlatform>;
export type MockRequestEvent = ReturnType<typeof mockRequestEvent>;
