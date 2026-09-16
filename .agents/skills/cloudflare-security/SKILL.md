---
name: cloudflare-security
description: "Hardening de aplicações Cloudflare (Workers e Pages): headers de segurança, CSP, CORS, cookies, superfície de ataque e resposta a incidentes. Use em revisão de segurança antes de deploy de produção, ou ao auditar autenticação, autorização e input externo."
---

# Skill: cloudflare-security

## Quando usar

Carregue esta skill ao trabalhar com:
- Hardening de aplicação Cloudflare (Workers/Pages)
- Headers de segurança e CSP
- Revisão de segurança antes de deploy de produção
- Resposta a incidente de segurança
- Auditoria de superfície de ataque
- Qualquer arquivo que lide com autenticação, autorização, ou input externo

## Modelo de ameaça do stack

| Superfície | Risco | Mitigação |
|------------|-------|-----------|
| Worker endpoints | Input malicioso | Zod + prepared statements |
| D1 | SQL Injection | `.bind()` sempre |
| KV | Exposição de cache | Prefixos + TTL + sem PII |
| R2 | Vazamento de arquivos | Bucket privado + signed URLs curtas |
| AI Gateway | Prompt injection | Sanitização + guardrails |
| Sessão | Sequestro | Cookie httpOnly + secure + expiração |
| Secrets | Vazamento | `wrangler secret put` + gitleaks |
| Deploy | Publicação de código errado | Staging + aprovação + rollback |
| CORS | Exposição cross-origin | Allowlist explícita |
| Logs | Vazamento de PII | Redaction + níveis |

## Headers de segurança

Adicione `static/_headers` no projeto (Cloudflare Pages injeta em toda resposta):

```text
/*
  X-Content-Type-Options: nosniff
  X-Frame-Options: DENY
  X-XSS-Protection: 0
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: camera=(), microphone=(), geolocation=(), interest-cohort=()
  Strict-Transport-Security: max-age=31536000; includeSubDomains; preload
  Cross-Origin-Opener-Policy: same-origin
  Cross-Origin-Resource-Policy: same-origin
  Cross-Origin-Embedder-Policy: require-corp
  Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self'; connect-src 'self' https://gateway.ai.cloudflare.com; frame-ancestors 'none'; base-uri 'self'; form-action 'self'; object-src 'none'; upgrade-insecure-requests
```

Ajuste a CSP conforme o uso real:
- Se usar CDN externa, adicione ao `script-src`/`style-src`.
- Se usar WebSocket, adicione ao `connect-src`.
- **Nunca** use `'unsafe-eval'` ou `'unsafe-inline'` para `script-src`.

## Padrões corretos

### CORS com allowlist explícita

```ts
// workers/src/middleware/cors.ts
const ALLOWED_ORIGINS = new Set([
  'https://myapp.com',
  'https://www.myapp.com',
  'https://myapp-staging.pages.dev'
]);

export function corsHeaders(origin: string | null): Record<string, string> {
  if (!origin || !ALLOWED_ORIGINS.has(origin)) {
    return {};
  }

  return {
    'Access-Control-Allow-Origin': origin,
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    'Access-Control-Allow-Credentials': 'true',
    'Access-Control-Max-Age': '86400',
    'Vary': 'Origin'
  };
}
```

### Redaction de PII em logs

```ts
// workers/src/logging.ts
const PII_KEYS = new Set([
  'password', 'token', 'authorization', 'cookie',
  'cpf', 'cnpj', 'email', 'phone', 'address'
]);

export function redact(obj: unknown, depth = 0): unknown {
  if (depth > 5 || obj === null || typeof obj !== 'object') return obj;
  if (Array.isArray(obj)) return obj.map((v) => redact(v, depth + 1));

  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    out[key] = PII_KEYS.has(key.toLowerCase())
      ? '[REDACTED]'
      : redact(value, depth + 1);
  }
  return out;
}

export function logSafe(event: string, data: Record<string, unknown>) {
  console.log(JSON.stringify({
    event,
    data: redact(data),
    ts: new Date().toISOString()
  }));
}
```

### Validação de origem em form actions

```ts
// Já habilitado por padrão em svelte.config.js:
// kit: { csrf: { checkOrigin: true } }

// Para endpoints +server.ts, valide manualmente:
export const POST: RequestHandler = async ({ request }) => {
  const origin = request.headers.get('origin');
  const allowed = ['https://myapp.com', 'https://www.myapp.com'];

  if (!origin || !allowed.includes(origin)) {
    throw error(403, 'Forbidden origin');
  }
  // ...
};
```

### Comparação timing-safe

```ts
// workers/src/crypto.ts
export function safeEqual(a: string, b: string): boolean {
  const bufA = new TextEncoder().encode(a);
  const bufB = new TextEncoder().encode(b);

  if (bufA.length !== bufB.length) return false;

  let diff = 0;
  for (let i = 0; i < bufA.length; i++) {
    diff |= bufA[i]! ^ bufB[i]!;
  }
  return diff === 0;
}
```

### Erros que não vazam internos

```ts
// ✅ SEMPRE — mensagem genérica ao cliente, detalhe no log
try {
  await doSomething(request);
  return json({ ok: true });
} catch (err) {
  logSafe('request_error', { error: String(err) });
  return json({ error: 'Internal error' }, { status: 500 });
}
```

### Rate limiting por IP

```ts
// workers/src/middleware/rate-limit.ts
export async function rateLimit(
  env: Env,
  identifier: string,
  limit: number,
  windowSec: number
): Promise<{ allowed: boolean; remaining: number }> {
  const key = `rl:${identifier}`;
  const current = Number((await env.CACHE.get(key)) ?? '0');

  if (current >= limit) {
    return { allowed: false, remaining: 0 };
  }

  await env.CACHE.put(key, String(current + 1), {
    expirationTtl: windowSec
  });

  return { allowed: true, remaining: limit - current - 1 };
}
```

## Anti-patterns (proibidos)

### 1. CORS wildcard

```ts
// ❌ NUNCA em produção
'Access-Control-Allow-Origin': '*'

// ✅ Allowlist
'Access-Control-Allow-Origin': origin // validado contra ALLOWED_ORIGINS
```

### 2. Stack trace em resposta

```ts
// ❌ NUNCA
catch (err) { return json({ error: err.stack }, { status: 500 }); }

// ✅ SEMPRE
catch (err) {
  logSafe('error', { message: String(err) });
  return json({ error: 'Internal error' }, { status: 500 });
}
```

### 3. Log de PII

```ts
// ❌ NUNCA
console.log({ user, password, token });

// ✅ SEMPRE
logSafe('login_attempt', { userId: user.id, email: redact(user.email) });
```

### 4. CSP com `unsafe-eval` / `unsafe-inline` em script

```text
❌ script-src 'self' 'unsafe-eval' 'unsafe-inline'
✅ script-src 'self' 'nonce-<random>'
```

### 5. Expor variáveis de ambiente ao cliente

```ts
// ❌ NUNCA — env do Worker é server-only
return json({ env });

// ✅ Apenas dados seguros e específicos
return json({ version: env.APP_VERSION });
```

### 6. Comparação de secret com `==`

```ts
// ❌ NUNCA — timing attack
if (token === env.SESSION_SECRET) { /* ... */ }

// ✅ SEMPRE
if (safeEqual(token, env.SESSION_SECRET)) { /* ... */ }
```

### 7. Trust em `X-Forwarded-For` sem validação

```ts
// ❌ NUNCA — cliente pode forjar
const ip = request.headers.get('x-forwarded-for');

// ✅ SEMPRE — use getClientAddress() do SvelteKit/Cloudflare
const ip = getClientAddress();
```

### 8. Session ID previsível

```ts
// ❌ NUNCA
const sessionId = `${userId}-${Date.now()}`;

// ✅ SEMPRE
const sessionId = crypto.randomUUID();
```

### 9. Upload sem validação de tipo real

```ts
// ❌ NUNCA — confia no Content-Type do cliente
if (file.type.startsWith('image/')) { /* ok */ }

// ✅ SEMPRE — valide magic bytes
const magic = new Uint8Array(await file.slice(0, 4).arrayBuffer());
if (!isPng(magic) && !isJpeg(magic)) throw new Error('Not an image');
```

### 10. Deploy sem staging prévio

```bash
# ❌ NUNCA
wrangler deploy --env production

# ✅ SEMPRE
wrangler deploy --env staging
./scripts/smoke-test.sh staging
# aprovação humana
wrangler deploy --env production
```

## Resposta a incidente

Se um secret vazou (ex: gitleaks encontrou em commit antigo):

```bash
# 1. Rotacionar IMEDIATAMENTE o secret
wrangler secret put SESSION_SECRET --env production
# gera novo valor: openssl rand -base64 32

# 2. Invalidar todas as sessões (KV)
# (via script interno — flush namespace de sessões)

# 3. Remover do histórico Git
git filter-repo --path path/to/secret --invert-paths

# 4. Force push (cuidado — coordene com o time)
git push --force-with-lease

# 5. Notificar usuários afetados (se PII vazou)

# 6. Documentar post-mortem
```

## Auditoria periódica

Execute mensalmente:

```bash
# 1. Secrets scan completo
gitleaks detect --source . --no-git --redact --config .gitleaks.toml

# 2. Dependências vulneráveis
pnpm audit --audit-level moderate

# 3. OWASP check
./scripts/owasp-check.sh

# 4. Verificar permissões de tokens Cloudflare
# Dashboard > My Profile > API Tokens — auditar escopos

# 5. Verificar logs de acesso anômalo
wrangler tail --env production --format json | jq 'select(.outcome != "ok")'
```

## Checklist antes de deploy

- [ ] Nenhum secret em código (gitleaks verde)
- [ ] Todos os endpoints com validação Zod
- [ ] D1 com prepared statements
- [ ] R2 com buckets privados
- [ ] Signed URLs ≤15 min
- [ ] CORS com allowlist
- [ ] CSP sem `unsafe-eval`/`unsafe-inline` em script
- [ ] Headers de segurança presentes (`static/_headers`)
- [ ] Cookies httpOnly + secure + sameSite
- [ ] Rate limiting em endpoints públicos
- [ ] Logs sem PII
- [ ] Erros sem stack trace
- [ ] Sessões com expiração
- [ ] AI Gateway com guardrails
- [ ] Prompt injection mitigado
- [ ] Auditoria de dependências verde
- [ ] Staging testado antes de produção
- [ ] Aprovação humana registrada
- [ ] Rollback plan documentado
- [ ] `wrangler tail` monitorado pós-deploy

## Referências

- OWASP Top 10: https://owasp.org/Top10/
- Cloudflare security best practices: https://developers.cloudflare.com/workers/learning/security-model/
- Web Security Headers: https://securityheaders.com/
- Mozilla Observatory: https://observatory.mozilla.org/
- AGENT.md — seção 5, Security Gates (todos)
