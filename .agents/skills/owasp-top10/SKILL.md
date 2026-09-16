---
name: owasp-top10
description: "OWASP Top 10 aplicado a SvelteKit e Cloudflare: injection, broken access control, falhas de autenticação, SSRF, misconfiguration e logging inseguro. Use em qualquer mudança que toque autenticação, autorização, sessão, endpoints +server.ts, form actions, D1, KV, R2 ou chamadas a LLM."
---

# Skill: owasp-top10

## Quando usar

Carregue esta skill ao trabalhar com:
- Qualquer mudança que toque autenticação, autorização ou sessão
- Input do usuário (formulários, query params, headers, uploads)
- Endpoints de API (`+server.ts`) e form actions
- Banco de dados (D1), cache (KV), storage (R2)
- Chamadas a LLMs (AI Gateway)
- Configuração de CORS, headers, cookies
- Revisão de PR antes de merge

## OWASP Top 10 (2021) — adaptado ao stack

Cada seção traz: o que é, como aparece no stack, padrão correto,
anti-pattern e verificação automatizada.

---

## A01 — Broken Access Control

### O que é
Falhas que permitem usuário acessar recurso além do seu nível de permissão.

### Como aparece no stack
- Guard só no cliente (rota protegida sem `+layout.server.ts`).
- Endpoint `+server.ts` sem verificação de role.
- D1 query sem filtro por `user_id`.
- Confiar em `role` enviada pelo cliente.

### Padrão correto

```ts
// src/routes/(app)/+layout.server.ts
export const load: LayoutServerLoad = async ({ locals, url }) => {
  if (!locals.user) {
    throw redirect(303, `/login?redirectTo=${encodeURIComponent(url.pathname)}`);
  }
  return { user: locals.user };
};

// src/routes/api/admin/users/+server.ts
export const GET: RequestHandler = async ({ locals, platform }) => {
  if (!locals.user) throw error(401, 'Unauthorized');
  if (locals.user.role !== 'admin') throw error(403, 'Forbidden');

  const { results } = await platform!.env.DB
    .prepare('SELECT id, email FROM users LIMIT 100')
    .all();
  return json({ users: results ?? [] });
};
```

### Anti-pattern

```ts
// ❌ Guard só no cliente
<script>
  import { page } from '$app/stores';
  $: if (!$page.data.user) goto('/login');
</script>

// ❌ Filtro por user_id do cliente
await env.DB.prepare('SELECT * FROM docs WHERE user_id = ?')
  .bind(request.headers.get('x-user-id'))  // cliente controla
  .all();
```

### Verificação
```bash
# Automatizado em scripts/owasp-check.sh (A01)
# Verifica presença de locals.user / requireAuth em rotas
```

### Checklist
- [ ] Rotas protegidas têm guard em `+layout.server.ts`
- [ ] Endpoints `+server.ts` revalidam `locals.user` e `role`
- [ ] Queries D1 filtram por `user_id` do **servidor** (nunca do cliente)
- [ ] Nunca confiar em `role` ou `user_id` enviado pelo cliente
- [ ] Testar acesso negado com `curl` sem cookie

---

## A02 — Cryptographic Failures

### O que é
Uso inadequado de criptografia: dados sensíveis sem proteção, algoritmos
fracos, secrets em texto claro.

### Como aparece no stack
- Cookies sem `httpOnly`/`secure`.
- Comparação de secrets com `==`.
- Senhas com hash fraco (MD5, SHA1, SHA256 puro).
- Dados sensíveis em KV sem criptografia.

### Padrão correto

```ts
// Cookie seguro
cookies.set('sid', sessionId, {
  path: '/',
  httpOnly: true,
  secure: true,
  sameSite: 'lax',
  maxAge: 60 * 60 * 24 * 7
});

// Comparação timing-safe
import { timingSafeEqual } from 'node:crypto';

function safeEqual(a: string, b: string): boolean {
  const bufA = Buffer.from(a);
  const bufB = Buffer.from(b);
  if (bufA.length !== bufB.length) return false;
  return timingSafeEqual(bufA, bufB);
}

// Hash de senha
import bcrypt from 'bcryptjs';
const hash = await bcrypt.hash(password, 12);
```

### Anti-pattern

```ts
// ❌ Cookie inseguro
cookies.set('sid', sessionId, { path: '/' });

// ❌ Comparação timing-vulnerable
if (token === env.SESSION_SECRET) { /* ... */ }

// ❌ Hash fraco
const hash = crypto.createHash('sha256').update(password).digest('hex');
```

### Verificação
```bash
# scripts/owasp-check.sh detecta cookies sem httpOnly/secure
# e comparações inseguras de secret
```

### Checklist
- [ ] Cookies com `httpOnly`, `secure`, `sameSite: 'lax'`
- [ ] Comparações de secret com `timingSafeEqual`
- [ ] Senhas com bcrypt (12 rounds) ou argon2
- [ ] Dados sensíveis criptografados antes de ir para KV/R2
- [ ] SESSION_SECRET gerado com `openssl rand -base64 32`
- [ ] Tokens com expiração curta

---

## A03 — Injection

### O que é
Dados não confiáveis interpretados como código: SQL, comandos, HTML,
prompts de LLM.

### Como aparece no stack
- D1 com concatenação de string.
- `eval`/`new Function` com input.
- `innerHTML` com dado não sanitizado.
- Input do usuário direto no prompt de LLM (prompt injection).

### Padrão correto

```ts
// D1 com prepared statement
const stmt = env.DB
  .prepare('SELECT * FROM users WHERE email = ?')
  .bind(email);

// Zod valida todo input
const Schema = z.object({ email: z.string().email() });
const parsed = Schema.safeParse(input);
if (!parsed.success) return fail(400);

// Sanitização de prompt
const sanitized = sanitizeForPrompt(userInput);
const prompt = `Responda: ${sanitized}`;
```

### Anti-pattern

```ts
// ❌ SQL Injection
env.DB.prepare(`SELECT * FROM users WHERE email = '${email}'`);

// ❌ XSS
element.innerHTML = userComment;

// ❌ Prompt injection
const prompt = `Instruções: ${userInput}`;
```

### Verificação
```bash
# scripts/owasp-check.sh detecta:
# - DB.prepare(` sem .bind()
# - eval( / new Function(
# - innerHTML
# - input direto em prompt
```

### Checklist
- [ ] D1 sempre com `.bind()`
- [ ] Nenhum `eval`/`new Function` com input
- [ ] `innerHTML` apenas com dado sanitizado (ou prefira `textContent`)
- [ ] Zod em todo input externo
- [ ] Prompt de LLM com input sanitizado
- [ ] Nenhuma query concatenada (nem "interna")

---

## A04 — Insecure Design

### O que é
Falhas de design (não de implementação): ausência de rate limit,
timeouts, validação de regras de negócio.

### Como aparece no stack
- Endpoints públicos sem rate limit.
- `fetch` sem timeout.
- Upload sem limite de tamanho.
- Sem limite em loops ou queries.

### Padrão correto

```ts
// Rate limit em endpoint público
const { allowed } = await rateLimit(env, `ip:${ip}`, 100, 60);
if (!allowed) return json({ error: 'Too many requests' }, { status: 429 });

// Timeout em fetch externo
const controller = new AbortController();
setTimeout(() => controller.abort(), 30_000);
const res = await fetch(url, { signal: controller.signal });

// Limite de upload
const size = Number(request.headers.get('content-length') ?? 0);
if (size > 10 * 1024 * 1024) {
  return new Response('Too large', { status: 413 });
}
```

### Anti-pattern

```ts
// ❌ Sem rate limit
await expensiveOperation();

// ❌ Sem timeout
await fetch(externalUrl);

// ❌ Sem limite de tamanho
await env.STORAGE.put(key, request.body);
```

### Checklist
- [ ] Rate limit em endpoints públicos (login, IA, upload)
- [ ] Timeout em todo `fetch` externo
- [ ] Limite de tamanho em upload
- [ ] Limite em queries (paginação)
- [ ] Limite em chamadas LLM (custo)
- [ ] Regras de negócio validadas server-side

---

## A05 — Security Misconfiguration

### O que é
Configuração incorreta de segurança: CORS wildcard, headers ausentes,
debug em produção, defaults inseguros.

### Como aparece no stack
- CORS com `*` em produção.
- Headers de segurança ausentes (`static/_headers`).
- Stack trace em resposta de erro.
- Logs de debug em produção.

### Padrão correto

```ts
// CORS com allowlist
const ALLOWED = new Set(['https://myapp.com', 'https://www.myapp.com']);
const origin = request.headers.get('origin');
if (origin && ALLOWED.has(origin)) {
  headers['Access-Control-Allow-Origin'] = origin;
  headers['Vary'] = 'Origin';
}

// Erro genérico ao cliente
try {
  await doSomething();
} catch (err) {
  logSafe('error', { message: String(err) });
  return json({ error: 'Internal error' }, { status: 500 });
}
```

### Anti-pattern

```ts
// ❌ CORS wildcard
headers['Access-Control-Allow-Origin'] = '*';

// ❌ Stack trace
catch (err) { return json({ error: err.stack }, { status: 500 }); }
```

### Verificação
```bash
# scripts/owasp-check.sh detecta CORS wildcard e stack trace
# scripts/smoke-test.sh verifica headers de segurança
```

### Checklist
- [ ] CORS com allowlist explícita
- [ ] `static/_headers` com CSP, HSTS, X-Frame-Options
- [ ] Erros sem stack trace em produção
- [ ] `LOG_LEVEL=warn` em produção
- [ ] `observability` habilitada no wrangler de prod
- [ ] Nenhum endpoint de debug exposto

---

## A06 — Vulnerable and Outdated Components

### O que é
Dependências com vulnerabilidades conhecidas.

### Como aparece no stack
- `node_modules` desatualizado.
- Pacotes abandonados.
- Sem `pnpm audit` no CI.

### Padrão correto

```bash
# CI roda
pnpm audit --audit-level high

# Atualização regular
pnpm outdated
pnpm update --latest
```

### Anti-pattern
- Ignorar warnings de audit.
- Fixar versões antigas sem motivo.
- Usar pacotes sem manutenção.

### Verificação
```bash
# CI: pnpm audit --audit-level high
# Pre-PR: scripts/security-scan.sh
```

### Checklist
- [ ] `pnpm audit` verde
- [ ] Dependências atualizadas (revisão mensal)
- [ ] Nenhum pacote abandonado
- [ ] Lockfile commitado
- [ ] Renovate/Dependabot configurado (recomendado)

---

## A07 — Identification and Authentication Failures

### O que é
Falhas em autenticação: senha fraca, sessão sem expiração,
sem rate limit, token em localStorage.

### Como aparece no stack
- Sessão em cookie sem `httpOnly`.
- Sem rate limit em login.
- Sessão sem `expires_at`.
- Logout que só limpa cookie.

### Padrão correto

```ts
// Sessão com expiração
const expiresAt = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7;
await env.DB.prepare(
  'INSERT INTO sessions (id, user_id, expires_at) VALUES (?, ?, ?)'
).bind(id, userId, expiresAt).run();

// Logout invalida no servidor
await env.DB.prepare('DELETE FROM sessions WHERE id = ?').bind(sid).run();
await env.CACHE.delete(`sess:${sid}`);
cookies.delete('sid', { path: '/' });
```

### Anti-pattern

```ts
// ❌ Token em localStorage
localStorage.setItem('token', jwt);

// ❌ Logout só cliente
cookies.delete('sid');  // servidor ainda válido

// ❌ Sem expiração
INSERT INTO sessions (id, user_id) VALUES (?, ?);
```

### Verificação
```bash
# scripts/owasp-check.sh detecta localStorage com token
# e hooks.server.ts sem validação
```

### Checklist
- [ ] Cookie httpOnly + secure + sameSite
- [ ] Sessão com `expires_at` em D1
- [ ] Logout invalida no servidor (KV + D1)
- [ ] Rate limit em login
- [ ] Mensagem de erro genérica (não revela se email existe)
- [ ] Hash de senha com bcrypt (12 rounds)
- [ ] Nenhum token em localStorage

---

## A08 — Software and Data Integrity Failures

### O que é
Falhas em garantir integridade de código ou dados: migrations sem
controle, upload sem validação, dependências sem verificação.

### Como aparece no stack
- Migrations alteradas após aplicadas.
- Upload sem validação de tipo real.
- Signed URLs sem expiração.
- Sem checksum em dados críticos.

### Padrão correto

```ts
// Validação de tipo real (magic bytes)
const magic = new Uint8Array(await file.slice(0, 4).arrayBuffer());
const isPng = magic[0] === 0x89 && magic[1] === 0x50
           && magic[2] === 0x4e && magic[3] === 0x47;

// Signed URL com expiração curta
const url = await getSignedUrl(env, key, 900); // 15 min

// Migration imutável após aplicada
-- migrations/0002_add_uploaded_files.sql
-- nunca altere este arquivo após aplicar em produção
```

### Anti-pattern

```ts
// ❌ Confia no Content-Type do cliente
if (file.type.startsWith('image/')) { /* ok */ }

// ❌ Signed URL eterna
const url = await getPermanentUrl(key);

// ❌ Alterar migration aplicada
-- migrations/0001_init.sql (editado após deploy)
```

### Verificação
```bash
# scripts/owasp-check.sh verifica signed URLs com expiração
# e presença de migrations versionadas
```

### Checklist
- [ ] Migrations imutáveis após aplicadas
- [ ] Validação de tipo real (magic bytes)
- [ ] Signed URLs com expiração ≤15 min
- [ ] Checksum (SHA-256) em arquivos críticos
- [ ] Nenhuma alteração manual em schema de produção

---

## A09 — Security Logging and Monitoring Failures

### O que é
Ausência de logs ou logs com PII; falta de alertas para eventos anômalos.

### Como aparece no stack
- `console.log` com email, token, senha.
- Sem logs de tentativa de login falhada.
- Sem alertas em 5xx.

### Padrão correto

```ts
// Log estruturado com redaction
logSafe('login_failed', { email: redact(email), ip: getClientAddress() });
logSafe('access_denied', { userId: locals.user?.id, path: url.pathname });
logSafe('rate_limit_hit', { identifier });

// Nunca logar
// - password, token, authorization, cookie
// - cpf, cnpj, email completo, phone, address
```

### Anti-pattern

```ts
// ❌ PII em log
console.log('Login:', { email, password });
console.log('Token:', request.headers.get('authorization'));
```

### Verificação
```bash
# scripts/owasp-check.sh detecta console.log com password/token/email
```

### Checklist
- [ ] Logs sem PII (redaction aplicada)
- [ ] Eventos de segurança logados (login, acesso negado, rate limit)
- [ ] Logs em formato JSON estruturado
- [ ] Alertas configurados para 5xx (via dashboard)
- [ ] `wrangler tail` disponível para incidentes

---

## A10 — Server-Side Request Forgery (SSRF)

### O que é
Aplicação faz requisição a URL controlada pelo atacante.

### Como aparece no stack
- `fetch(userProvidedUrl)`.
- Chamada direta a provider LLM (bypass do Gateway).
- Proxy de imagens sem allowlist.

### Padrão correto

```ts
// Allowlist de hosts
const ALLOWED_HOSTS = new Set(['api.stripe.com', 'api.github.com']);

function validateUrl(input: string): URL {
  const url = new URL(input);
  if (url.protocol !== 'https:') throw new Error('HTTPS required');
  if (!ALLOWED_HOSTS.has(url.hostname)) throw new Error('Host not allowed');
  return url;
}

// Sempre via AI Gateway
await fetch(`${env.AI_GATEWAY_URL}/chat/completions`, { ... });
```

### Anti-pattern

```ts
// ❌ URL do cliente
await fetch(request.body.url);

// ❌ Provider LLM direto
await fetch('https://api.openai.com/v1/chat/completions', { ... });
```

### Verificação
```bash
# scripts/owasp-check.sh detecta fetch com URL do cliente
# e chamadas diretas a providers LLM
```

### Checklist
- [ ] Nenhum `fetch` com URL do cliente sem allowlist
- [ ] LLM sempre via AI Gateway
- [ ] Bloquear IPs privados (127.0.0.1, 169.254.x.x, 10.x, 192.168.x)
- [ ] HTTPS obrigatório em chamadas externas

---

## Como executar a verificação automatizada

```bash
# Roda todos os checks A01–A10
./scripts/owasp-check.sh

# Modo não-bloqueante (só reporta)
./scripts/owasp-check.sh --warn-only
```

O script cobre os 10 itens com grep estrutural e heurísticas.
Falsos positivos são possíveis — revise cada achado.

## Checklist geral antes de PR

- [ ] A01: guards server-side em todas as rotas protegidas
- [ ] A02: cookies seguros + timing-safe + bcrypt
- [ ] A03: prepared statements + Zod + sem eval + prompt sanitizado
- [ ] A04: rate limit + timeout + limite de upload
- [ ] A05: CORS allowlist + headers + sem stack trace
- [ ] A06: `pnpm audit` verde
- [ ] A07: sessão com expiração + logout server-side
- [ ] A08: migrations imutáveis + signed URLs curtas + magic bytes
- [ ] A09: logs sem PII + eventos de segurança
- [ ] A10: sem SSRF + LLM via Gateway
- [ ] `./scripts/owasp-check.sh` verde

## Referências

- OWASP Top 10 (2021): https://owasp.org/Top10/
- OWASP Cheat Sheets: https://cheatsheetseries.owasp.org/
- ASVS (Application Security Verification Standard): https://owasp.org/www-project-application-security-verification-standard/
- AGENT.md — seção 5, Gate 6
- Skill `security-leaks` para detalhes de vazamento
- Skill `cloudflare-security` para hardening específico
