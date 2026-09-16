---
name: cloudflare-kv
description: "Cloudflare KV: cache de respostas, feature flags, sessões leves, contadores de rate limit e TTL. Use ao trabalhar com env.CACHE, arquivos em workers/src/cache/, ou ao decidir entre KV, D1 e R2 para persistir dados."
---

# Skill: cloudflare-kv

## Quando usar

Carregue esta skill ao trabalhar com:
- Cache de respostas ou dados computados
- Feature flags e configurações de runtime
- Sessões leves (dados pequenos, com TTL)
- Rate limiting counters
- Qualquer arquivo em `workers/src/cache/` ou que importe `env.CACHE`

## O que é KV

Workers KV é um armazenamento chave-valor distribuído globalmente,
otimizado para **leitura intensa** e **baixa latência na borda**.

Características importantes:
- **Eventually consistent**: escritas podem levar até 60s para propagar globalmente.
- Leituras são extremamente rápidas em cache de borda.
- Chaves até 512 bytes; valores até 25 MB.
- Ideal para dados que mudam pouco e são lidos muito.
- **NÃO é banco transacional.** Não use para dados que exigem consistência forte.

## Padrões corretos

### Cache com TTL explícito

```ts
// workers/src/cache/user-cache.ts
const TTL_USER = 300; // 5 minutos

export async function getCachedUser(env: Env, userId: string) {
  const key = `cache:user:${userId}`;
  const cached = await env.CACHE.get<User>(key, 'json');
  if (cached) return cached;
  return null;
}

export async function setCachedUser(env: Env, user: User) {
  const key = `cache:user:${user.id}`;
  await env.CACHE.put(key, JSON.stringify(user), {
    expirationTtl: TTL_USER
  });
}

export async function invalidateUser(env: Env, userId: string) {
  await env.CACHE.delete(`cache:user:${userId}`);
}
```

### Feature flags

```ts
const TTL_FLAG = 60; // 1 minuto — flags mudam com frequência

export async function isEnabled(env: Env, flag: string): Promise<boolean> {
  const value = await env.CACHE.get<{ enabled: boolean }>(
    `flag:${flag}`,
    'json'
  );
  return value?.enabled ?? false;
}
```

### Rate limiting counter

```ts
const WINDOW = 60; // segundos
const LIMIT = 100;

export async function checkRateLimit(
  env: Env,
  identifier: string
): Promise<{ allowed: boolean; remaining: number }> {
  const key = `rl:${identifier}`;
  const current = Number((await env.CACHE.get(key)) ?? '0');

  if (current >= LIMIT) {
    return { allowed: false, remaining: 0 };
  }

  await env.CACHE.put(key, String(current + 1), {
    expirationTtl: WINDOW
  });

  return { allowed: true, remaining: LIMIT - current - 1 };
}
```

### Sessão leve

```ts
const TTL_SESSION = 60 * 60 * 24 * 7; // 7 dias

export async function createSession(
  env: Env,
  sessionId: string,
  data: { userId: string }
) {
  await env.CACHE.put(
    `sess:${sessionId}`,
    JSON.stringify(data),
    { expirationTtl: TTL_SESSION }
  );
}

export async function readSession(env: Env, sessionId: string) {
  return env.CACHE.get<{ userId: string }>(`sess:${sessionId}`, 'json');
}

export async function destroySession(env: Env, sessionId: string) {
  await env.CACHE.delete(`sess:${sessionId}`);
}
```

### Metadados com list

```ts
export async function listUserSessions(env: Env, userId: string) {
  const list = await env.CACHE.list({ prefix: `sess:${userId}:` });
  return list.keys.map((k) => k.name);
}
```

## Convenções de prefixo de chave

| Prefixo | Uso | TTL típico |
|---------|-----|------------|
| `cache:` | Cache de dados computados | 5–60 min |
| `flag:` | Feature flags | 1–5 min |
| `sess:` | Sessões de usuário | 1–30 dias |
| `rl:` | Rate limiting | 1–60 s |
| `cfg:` | Configuração de runtime | 5–60 min |
| `tmp:` | Dados temporários de curta vida | <1 h |

**Regra:** todo prefixo novo deve ser documentado aqui antes de ser usado.

## Anti-patterns (proibidos)

### 1. KV sem TTL

```ts
// ❌ NUNCA — dado fica órfão para sempre
await env.CACHE.put('user:1', JSON.stringify(user));

// ✅ SEMPRE — TTL explícito
await env.CACHE.put('user:1', JSON.stringify(user), {
  expirationTtl: 300
});
```

### 2. Usar KV como banco relacional

```ts
// ❌ NUNCA — KV não suporta joins, transações, nem listagens complexas
await env.CACHE.put(`users:${id}`, user);
await env.CACHE.put(`posts:${postId}`, post);

// ✅ Use D1 para dados relacionais; KV apenas para cache
```

### 3. Guardar PII sem proteção

```ts
// ❌ NUNCA — KV não tem criptografia em repouso por padrão
await env.CACHE.put(`cpf:${id}`, cpf);

// ✅ Guarde dados não sensíveis, ou criptografe antes
await env.CACHE.put(
  `cpf:${id}`,
  await encrypt(cpf, env.ENCRYPTION_KEY),
  { expirationTtl: 300 }
);
```

### 4. Confiar em consistência imediata

```ts
// ❌ NUNCA — pode ler valor antigo por até 60s após a escrita
await env.CACHE.put('config', newValue);
const value = await env.CACHE.get('config'); // pode ser o antigo
```

### 5. Guardar valores grandes

```ts
// ❌ NUNCA — valores >25 MB são rejeitados; >1 MB é lento
await env.CACHE.put('big', hugeJson);

// ✅ Para blobs, use R2; para dados relacionais, use D1
```

### 6. Chave sem prefixo

```ts
// ❌ Ambíguo, difícil de listar/invalidar
await env.CACHE.put(userId, data);

// ✅ Prefixo semântico
await env.CACHE.put(`cache:user:${userId}`, data);
```

## Comandos

```bash
# Criar namespace (produção)
wrangler kv namespace create CACHE

# Criar namespace de preview (obrigatório para dev)
wrangler kv namespace create CACHE --preview

# Listar namespaces
wrangler kv namespace list

# Ler uma chave (dev)
wrangler kv key get --binding=CACHE --local "cache:user:1"

# Escrever uma chave (dev)
wrangler kv key put --binding=CACHE --local "flag:beta" '{"enabled":true}'

# Deletar uma chave
wrangler kv key delete --binding=CACHE --local "cache:user:1"

# Listar chaves por prefixo
wrangler kv key list --binding=CACHE --prefix="sess:"
```

## Estratégias de invalidação

### Cache-aside (padrão mais comum)

```ts
export async function getUser(env: Env, id: string) {
  const cached = await getCachedUser(env, id);
  if (cached) return cached;

  const user = await getUserById(env, id);
  if (user) await setCachedUser(env, user);
  return user;
}

export async function updateUser(env: Env, id: string, patch: Partial<User>) {
  const user = await updateUserInDB(env, id, patch);
  await invalidateUser(env, id); // invalida após escrita
  return user;
}
```

### Versionamento de chave

Quando a estrutura do dado muda, incremente a versão no prefixo:

```ts
const CACHE_VERSION = 'v2';
const key = `cache:${CACHE_VERSION}:user:${userId}`;
```

## Checklist antes de finalizar

- [ ] TTL explícito em todo `put()`
- [ ] Chave com prefixo semântico documentado
- [ ] Fallback implementado em cache miss
- [ ] Invalidação após escrita em D1
- [ ] Nenhum PII sem criptografia
- [ ] Valores abaixo de 1 MB (ideal)
- [ ] Testes cobrindo hit, miss e erro
- [ ] `preview_id` configurado em `wrangler.toml`
- [ ] Não está usando KV para dados transacionais

## Referências

- Cloudflare KV docs: https://developers.cloudflare.com/kv/
- Consistency model: https://developers.cloudflare.com/kv/concepts/how-kv-works/
- AGENT.md — Code Rules, seção Cloudflare
