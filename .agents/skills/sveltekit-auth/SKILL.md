---
name: sveltekit-auth
description: "Autenticação e autorização em SvelteKit: hooks.server.ts, guards de rota, form actions de login e logout, cookies de sessão, event.locals.user e proteção de endpoints em +server.ts. Use ao implementar login, sessão, RBAC, ou ao proteger rotas e endpoints."
---

# Skill: sveltekit-auth

## Quando usar

Carregue esta skill ao trabalhar com:
- `src/hooks.server.ts` (handle hook, validação de sessão)
- Guards de rota em `+layout.server.ts` ou `+page.server.ts`
- Form actions de login/logout/registro
- Cookies de sessão
- `event.locals.user` e tipos em `app.d.ts`
- Proteção de endpoints em `+server.ts`
- Rate limiting em rotas de autenticação

## Arquitetura recomendada

```text
1. Login POST → form action
   - Zod valida input
   - Rate limit por IP + email
   - Verifica hash da senha (bcrypt/argon2)
   - Gera session_id (UUID)
   - Grava em D1 (sessions) e/ou KV (cache)
   - Seta cookie httpOnly + secure + sameSite

2. Toda request → hooks.server.ts
   - Lê cookie sid
   - Valida sessão (KV primeiro, D1 fallback)
   - Popula event.locals.user

3. Rotas protegidas → +layout.server.ts
   - Verifica locals.user
   - Redirect para /login se ausente
   - Popula dados da página

4. Logout POST → form action
   - Deleta sessão (KV + D1)
   - Limpa cookie
   - Redirect para /login
```

## Padrões corretos

### Tipos globais em `app.d.ts`

```ts
// src/app.d.ts
import type { D1Database, KVNamespace, R2Bucket, Ai } from '@cloudflare/workers-types';

declare global {
  namespace App {
    interface Locals {
      user: {
        id: string;
        email: string;
        role: 'user' | 'admin' | 'moderator';
      } | null;
      sessionId: string | null;
    }

    interface PageData {
      user?: App.Locals['user'];
    }

    interface Platform {
      env: {
        DB: D1Database;
        CACHE: KVNamespace;
        STORAGE: R2Bucket;
        AI: Ai;
        ENVIRONMENT: string;
        AI_GATEWAY_URL: string;
        SESSION_SECRET: string;
      };
      context: ExecutionContext;
      caches: CacheStorage;
    }
  }
}

export {};
```

### `hooks.server.ts` — validação de sessão

```ts
// src/hooks.server.ts
import type { Handle } from '@sveltejs/kit';
import { validateSession } from '$server/session';

export const handle: Handle = async ({ event, resolve }) => {
  const sid = event.cookies.get('sid');

  if (sid) {
    const session = await validateSession(event.platform!.env, sid);
    if (session) {
      event.locals.user = session.user;
      event.locals.sessionId = session.id;
    } else {
      // Sessão expirada ou inválida
      event.locals.user = null;
      event.locals.sessionId = null;
      event.cookies.delete('sid', { path: '/' });
    }
  } else {
    event.locals.user = null;
    event.locals.sessionId = null;
  }

  return resolve(event);
};
```

### Serviço de sessão

```ts
// src/lib/server/session.ts
import type { D1Database, KVNamespace } from '@cloudflare/workers-types';
import { randomUUID } from 'node:crypto';

interface Env {
  DB: D1Database;
  CACHE: KVNamespace;
}

export interface Session {
  id: string;
  user: { id: string; email: string; role: 'user' | 'admin' | 'moderator' };
}

const SESSION_TTL = 60 * 60 * 24 * 7; // 7 dias

export async function createSession(
  env: Env,
  userId: string,
  meta: { userAgent?: string; ip?: string }
): Promise<string> {
  const id = randomUUID();
  const expiresAt = Math.floor(Date.now() / 1000) + SESSION_TTL;

  await env.DB.prepare(
    'INSERT INTO sessions (id, user_id, expires_at, user_agent, ip_address) VALUES (?, ?, ?, ?, ?)'
  )
    .bind(id, userId, expiresAt, meta.userAgent ?? null, meta.ip ?? null)
    .run();

  return id;
}

export async function validateSession(
  env: Env,
  sessionId: string
): Promise<Session | null> {
  // 1. Tenta KV primeiro (rápido)
  const cached = await env.CACHE.get<Session>(`sess:${sessionId}`, 'json');
  if (cached) return cached;

  // 2. Fallback D1
  const row = await env.DB.prepare(
    `SELECT s.id, s.expires_at, u.id as user_id, u.email, u.role
     FROM sessions s
     JOIN users u ON u.id = s.user_id
     WHERE s.id = ? AND s.expires_at > unixepoch()`
  )
    .bind(sessionId)
    .first<{
      id: string;
      expires_at: number;
      user_id: string;
      email: string;
      role: 'user' | 'admin' | 'moderator';
    }>();

  if (!row) return null;

  const session: Session = {
    id: row.id,
    user: { id: row.user_id, email: row.email, role: row.role }
  };

  // Popula KV para próximas requests
  await env.CACHE.put(`sess:${sessionId}`, JSON.stringify(session), {
    expirationTtl: Math.max(60, row.expires_at - Math.floor(Date.now() / 1000))
  });

  return session;
}

export async function destroySession(env: Env, sessionId: string): Promise<void> {
  await Promise.all([
    env.DB.prepare('DELETE FROM sessions WHERE id = ?').bind(sessionId).run(),
    env.CACHE.delete(`sess:${sessionId}`)
  ]);
}
```

### Form action de login

```ts
// src/routes/login/+page.server.ts
import { fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { createSession } from '$server/session';
import { verifyPassword } from '$server/password';
import { checkRateLimit } from '$server/rate-limit';

const LoginSchema = z.object({
  email: z.string().email().max(254),
  password: z.string().min(8).max(128)
});

export const actions = {
  default: async ({ request, cookies, platform, getClientAddress, request: req }) => {
    const formData = await request.formData();
    const parsed = LoginSchema.safeParse({
      email: formData.get('email'),
      password: formData.get('password')
    });

    if (!parsed.success) {
      return fail(400, { error: 'Credenciais inválidas', email: '' });
    }

    const { email, password } = parsed.data;
    const ip = getClientAddress();

    // Rate limit por IP + email
    const { allowed } = await checkRateLimit(
      platform!.env,
      `login:${ip}:${email}`
    );
    if (!allowed) {
      return fail(429, { error: 'Muitas tentativas. Tente novamente em 1 minuto.' });
    }

    // Busca usuário
    const user = await platform!.env.DB.prepare(
      'SELECT id, email, role, password_hash FROM users WHERE email = ?'
    )
      .bind(email)
      .first<{ id: string; email: string; role: string; password_hash: string }>();

    // Timing-safe: sempre verifica, mesmo se user não existe
    const valid = await verifyPassword(
      password,
      user?.password_hash ?? '$2b$10$invalidhashplaceholder'
    );

    if (!user || !valid) {
      return fail(401, { error: 'Credenciais inválidas', email });
    }

    const sessionId = await createSession(platform!.env, user.id, {
      userAgent: req.headers.get('user-agent') ?? undefined,
      ip
    });

    cookies.set('sid', sessionId, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7
    });

    throw redirect(303, '/dashboard');
  }
};
```

### Guard em layout protegido

```ts
// src/routes/(app)/+layout.server.ts
import { redirect } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, url }) => {
  if (!locals.user) {
    const redirectTo = encodeURIComponent(url.pathname + url.search);
    throw redirect(303, `/login?redirectTo=${redirectTo}`);
  }

  return { user: locals.user };
};
```

### Form action de logout

```ts
// src/routes/logout/+page.server.ts
import { redirect } from '@sveltejs/kit';
import { destroySession } from '$server/session';

export const actions = {
  default: async ({ cookies, locals, platform }) => {
    const sid = cookies.get('sid');
    if (sid) {
      await destroySession(platform!.env, sid);
    }

    cookies.delete('sid', { path: '/' });
    throw redirect(303, '/login');
  }
};
```

### Proteger endpoint `+server.ts`

```ts
// src/routes/api/admin/users/+server.ts
import { error, json } from '@sveltejs/kit';
import type { RequestHandler } from './$types';

export const GET: RequestHandler = async ({ locals, platform }) => {
  if (!locals.user) {
    throw error(401, 'Unauthorized');
  }
  if (locals.user.role !== 'admin') {
    throw error(403, 'Forbidden');
  }

  const { results } = await platform!.env.DB.prepare(
    'SELECT id, email, role FROM users LIMIT 100'
  ).all();

  return json({ users: results ?? [] });
};
```

### Form action de registro com validação forte

```ts
// src/routes/register/+page.server.ts
import { fail, redirect } from '@sveltejs/kit';
import { z } from 'zod';
import { randomUUID } from 'node:crypto';
import { hashPassword } from '$server/password';
import { createSession } from '$server/session';

const RegisterSchema = z.object({
  email: z.string().email().max(254).toLowerCase(),
  password: z.string()
    .min(12, 'Senha deve ter ao menos 12 caracteres')
    .max(128)
    .regex(/[A-Z]/, 'Deve conter letra maiúscula')
    .regex(/[a-z]/, 'Deve conter letra minúscula')
    .regex(/[0-9]/, 'Deve conter número'),
  name: z.string().min(1).max(100).trim()
});

export const actions = {
  default: async ({ request, cookies, platform }) => {
    const formData = await request.formData();
    const parsed = RegisterSchema.safeParse({
      email: formData.get('email'),
      password: formData.get('password'),
      name: formData.get('name')
    });

    if (!parsed.success) {
      return fail(400, {
        error: parsed.error.issues[0]?.message ?? 'Dados inválidos',
        email: String(formData.get('email') ?? ''),
        name: String(formData.get('name') ?? '')
      });
    }

    const { email, password, name } = parsed.data;
    const id = randomUUID();
    const passwordHash = await hashPassword(password);

    try {
      await platform!.env.DB.prepare(
        'INSERT INTO users (id, email, name, password_hash) VALUES (?, ?, ?, ?)'
      )
        .bind(id, email, name, passwordHash)
        .run();
    } catch (err) {
      // UNIQUE constraint no email
      if (String(err).includes('UNIQUE')) {
        return fail(409, { error: 'Email já cadastrado', email, name });
      }
      throw err;
    }

    const sessionId = await createSession(platform!.env, id, {});
    cookies.set('sid', sessionId, {
      path: '/',
      httpOnly: true,
      secure: true,
      sameSite: 'lax',
      maxAge: 60 * 60 * 24 * 7
    });

    throw redirect(303, '/dashboard');
  }
};
```

### Proteção CSRF (já habilitada por padrão)

```ts
// svelte.config.js — SvelteKit valida Origin por padrão
kit: {
  csrf: {
    checkOrigin: true  // padrão — mantenha em true
  }
}
```

## Anti-patterns (proibidos)

### 1. Guard só no cliente

```svelte
<!-- ❌ NUNCA — qualquer um acessa via requisição direta -->
<script>
  import { page } from '$app/stores';
  $: if (!$page.data.user) goto('/login');
</script>

<!-- ✅ SEMPRE — guard server-side -->
<!-- +layout.server.ts -->
export const load = async ({ locals }) => {
  if (!locals.user) throw redirect(303, '/login');
  return { user: locals.user };
};
```

### 2. Cookie sem httpOnly / secure

```ts
// ❌ NUNCA — XSS rouba sessão; MITM em HTTP
cookies.set('sid', sessionId, { path: '/' });

// ✅ SEMPRE
cookies.set('sid', sessionId, {
  path: '/',
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 7
});
```

### 3. Confiar em `locals.user` sem validar em cada request

```ts
// ❌ NUNCA — se hooks.server.ts falhar, endpoint fica aberto
export const GET = async ({ locals, platform }) => {
  const data = await platform.env.DB.prepare('SELECT * FROM secrets').all();
  return json(data);
};

// ✅ SEMPRE — valide no endpoint também
export const GET = async ({ locals, platform }) => {
  if (!locals.user) throw error(401);
  if (locals.user.role !== 'admin') throw error(403);
  // ...
};
```

### 4. Guardar token em localStorage

```ts
// ❌ NUNCA — XSS rouba tokens de localStorage
localStorage.setItem('token', jwt);

// ✅ SEMPRE — cookie httpOnly
cookies.set('sid', sessionId, { httpOnly: true, secure: true, ... });
```

### 5. Comparação não-timing-safe de secrets

```ts
// ❌ NUNCA — timing attack
if (inputToken === storedToken) { /* ok */ }

// ✅ SEMPRE — timingSafeEqual
import { timingSafeEqual } from 'node:crypto';
function safeEqual(a: string, b: string): boolean {
  const ba = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ba.length !== bb.length) return false;
  return timingSafeEqual(ba, bb);
}
```

### 6. Hash de senha fraco

```ts
// ❌ NUNCA — MD5, SHA1, SHA256 puro
const hash = crypto.createHash('sha256').update(password).digest('hex');

// ✅ SEMPRE — bcrypt ou argon2
import bcrypt from 'bcryptjs';
const hash = await bcrypt.hash(password, 12);
```

### 7. Sem rate limit em login

```ts
// ❌ NUNCA — brute force trivial
if (valid) { createSession(); }

// ✅ SEMPRE — rate limit por IP + identificador
const { allowed } = await checkRateLimit(env, `login:${ip}:${email}`);
if (!allowed) return fail(429, { error: 'Muitas tentativas' });
```

### 8. Mensagem de erro revelando existência de usuário

```ts
// ❌ NUNCA — "Email não encontrado" revela quais emails existem
if (!user) return fail(401, { error: 'Email não encontrado' });
if (!valid) return fail(401, { error: 'Senha incorreta' });

// ✅ SEMPRE — mensagem genérica
if (!user || !valid) return fail(401, { error: 'Credenciais inválidas' });
```

### 9. Sessão sem expiração

```ts
// ❌ NUNCA — sessão eterna
await env.DB.prepare('INSERT INTO sessions (id, user_id) VALUES (?, ?)');

// ✅ SEMPRE — expires_at explícito
const expiresAt = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7;
await env.DB.prepare(
  'INSERT INTO sessions (id, user_id, expires_at) VALUES (?, ?, ?)'
).bind(id, userId, expiresAt).run();
```

### 10. Logout que só limpa cookie

```ts
// ❌ NUNCA — sessão continua válida no servidor
cookies.delete('sid', { path: '/' });

// ✅ SEMPRE — invalida no servidor também
await destroySession(env, sid);
cookies.delete('sid', { path: '/' });
```

## Hash de senha com bcryptjs

```ts
// src/lib/server/password.ts
import bcrypt from 'bcryptjs';

const ROUNDS = 12;

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, ROUNDS);
}

export async function verifyPassword(
  password: string,
  hash: string
): Promise<boolean> {
  try {
    return await bcrypt.compare(password, hash);
  } catch {
    return false;
  }
}
```

**Nota:** Workers têm suporte nativo a `crypto.subtle` (PBKDF2, HMAC),
mas bcryptjs funciona e é mais comum. Para projetos novos, considere
`@noble/hashes` ou Web Crypto API.

## Comandos

```bash
# Gerar secret seguro
openssl rand -base64 32

# Configurar secret no Cloudflare
wrangler secret put SESSION_SECRET --env staging
wrangler secret put SESSION_SECRET --env production

# Testar login manualmente
curl -X POST https://myapp-staging.pages.dev/login \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "email=user@example.com&password=..."
```

## Checklist antes de finalizar

- [ ] `hooks.server.ts` valida sessão em toda request
- [ ] `event.locals.user` populado corretamente
- [ ] Guards server-side em todas as rotas protegidas
- [ ] Cookies com `httpOnly: true`, `secure: true`, `sameSite: 'lax'`
- [ ] Sessão com `expires_at` explícito em D1
- [ ] Sessão invalidada no servidor no logout (KV + D1)
- [ ] Login com rate limit por IP + identificador
- [ ] Senha hash com bcrypt (12 rounds) ou argon2
- [ ] Zod validando todo input de auth
- [ ] Mensagem de erro genérica (não revela existência de usuário)
- [ ] CSRF check habilitado em `svelte.config.js`
- [ ] Endpoints `+server.ts` revalidam `locals.user` e role
- [ ] `SESSION_SECRET` configurado via `wrangler secret put`
- [ ] Nenhum token em `localStorage`
- [ ] Testes cobrindo: login ok, senha errada, user inexistente, rate limit, sessão expirada, acesso negado
- [ ] Timing-safe comparison onde aplicável

## Referências

- SvelteKit hooks: https://kit.svelte.dev/docs/hooks
- SvelteKit form actions: https://kit.svelte.dev/docs/form-actions
- SvelteKit routing: https://kit.svelte.dev/docs/routing
- OWASP Authentication Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html
- AGENT.md — seção 5, Gate 1 e Gate 2
