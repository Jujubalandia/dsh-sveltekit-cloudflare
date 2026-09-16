---
name: cloudflare-ai-gateway
description: "Chamadas a LLM através do Cloudflare AI Gateway: proxy, cache, rate limiting, guardrails, embeddings e Workers AI. Use ao trabalhar com env.AI, arquivos em workers/src/ai/, prompts, streaming de tokens, custo e observabilidade de IA, ou ao mandar input não confiável para um modelo."
---

# Skill: cloudflare-ai-gateway

## Quando usar

Carregue esta skill ao trabalhar com:
- Chamadas a LLMs (OpenAI, Anthropic, Workers AI, etc.)
- Embeddings e classificação via IA
- Qualquer arquivo em `workers/src/ai/` ou que importe `env.AI`
- Rate limiting e guardrails de IA

## O que é AI Gateway

Cloudflare AI Gateway é um proxy que fica entre sua aplicação e os
providers de IA (OpenAI, Anthropic, Google, Workers AI, etc.).

Vantagens:
- **Observabilidade**: logs, métricas, custos por request.
- **Cache**: respostas idênticas cacheadas, reduzindo custo.
- **Rate limiting**: controle de requisições por usuário/IP.
- **Guardrails**: filtragem de input/output malicioso ou indesejado.
- **Fallback**: retry automático entre providers.
- **Zero código extra**: apenas troque a URL base.

Regra de ouro: **NUNCA** chame um provider de IA diretamente.
Sempre passe pelo AI Gateway.

## Padrões corretos

### Chamada básica via Gateway

```ts
// workers/src/ai/chat.ts
export async function chat(
  env: Env,
  userId: string,
  messages: Array<{ role: string; content: string }>
) {
  const res = await fetch(`${env.AI_GATEWAY_URL}/chat/completions`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
      'cf-aig-metadata': JSON.stringify({ userId })
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages,
      temperature: 0.7
    })
  });

  if (!res.ok) {
    throw new Error(`AI Gateway error: ${res.status}`);
  }

  return res.json();
}
```

### Com timeout e retry

```ts
export async function chatWithRetry(
  env: Env,
  userId: string,
  messages: Array<{ role: string; content: string }>,
  maxRetries = 3
) {
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 30_000);

      const res = await fetch(`${env.AI_GATEWAY_URL}/chat/completions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${env.OPENAI_API_KEY}`,
          'cf-aig-metadata': JSON.stringify({ userId, attempt })
        },
        body: JSON.stringify({
          model: 'gpt-4o-mini',
          messages
        }),
        signal: controller.signal
      });

      clearTimeout(timeout);

      if (res.ok) return res.json();

      if (res.status >= 500) continue;
      throw new Error(`AI Gateway error: ${res.status}`);
    } catch (err) {
      if (attempt === maxRetries - 1) throw err;
      await new Promise((r) => setTimeout(r, 2 ** attempt * 1000));
    }
  }
}
```

### Sanitização de prompt (anti prompt injection)

```ts
// workers/src/ai/sanitize.ts
const MAX_INPUT_LENGTH = 4000;

export function sanitizeForPrompt(input: string): string {
  if (typeof input !== 'string') {
    throw new Error('Input must be a string');
  }

  // Limita tamanho
  let sanitized = input.slice(0, MAX_INPUT_LENGTH);

  // Remove tentativas comuns de injeção
  sanitized = sanitized
    .replace(/ignore\s+(all\s+)?previous\s+instructions?/gi, '')
    .replace(/system\s*:/gi, '')
    .replace(/assistant\s*:/gi, '')
    .replace(/<\|.*?\|>/g, '');

  return sanitized.trim();
}
```

### Rate limiting por usuário

```ts
const AI_RATE_LIMIT = 20;      // requisições
const AI_RATE_WINDOW = 60;     // segundos

export async function checkAIRateLimit(env: Env, userId: string) {
  const key = `ai_rl:${userId}`;
  const current = Number((await env.CACHE.get(key)) ?? '0');

  if (current >= AI_RATE_LIMIT) {
    return { allowed: false, remaining: 0 };
  }

  await env.CACHE.put(key, String(current + 1), {
    expirationTtl: AI_RATE_WINDOW
  });

  return { allowed: true, remaining: AI_RATE_LIMIT - current - 1 };
}
```

### Uso de Workers AI binding (alternativa nativa)

```ts
// Quando usar Workers AI (modelos hospedados na Cloudflare)
export async function classify(env: Env, text: string) {
  const result = await env.AI.run('@cf/meta/llama-3-8b-instruct', {
    messages: [{ role: 'user', content: text }]
  });
  return result;
}
```

**Nota:** mesmo com Workers AI binding, prefira rotear via AI Gateway
quando precisar de cache, rate limit e observabilidade unificada.

### Fallback entre providers

Configure no dashboard do AI Gateway:
- Provider primário: OpenAI
- Fallback: Anthropic
- Fallback secundário: Workers AI

O Gateway tenta automaticamente na ordem se o primário falhar.

## Anti-patterns (proibidos)

### 1. Fetch direto ao provider

```ts
// ❌ NUNCA — perde cache, rate limit, observabilidade e guardrails
const res = await fetch('https://api.openai.com/v1/chat/completions', {
  headers: { Authorization: `Bearer ${env.OPENAI_API_KEY}` },
  // ...
});

// ✅ SEMPRE — via AI Gateway
const res = await fetch(`${env.AI_GATEWAY_URL}/chat/completions`, {
  // ...
});
```

### 2. Input do usuário direto no prompt

```ts
// ❌ NUNCA — prompt injection
const prompt = `Responda: ${userInput}`;

// ✅ SEMPRE — sanitize primeiro
const sanitized = sanitizeForPrompt(userInput);
const prompt = `Responda: ${sanitized}`;
```

### 3. Sem rate limit

```ts
// ❌ NUNCA — custo descontrolado, DoS
await chat(env, userId, messages);

// ✅ SEMPRE — verifique antes
const { allowed } = await checkAIRateLimit(env, userId);
if (!allowed) return new Response('Too many requests', { status: 429 });
await chat(env, userId, messages);
```

### 4. Logar prompt cru com PII

```ts
// ❌ NUNCA
console.log('Prompt:', messages);

// ✅ SEMPRE — redact PII
console.log('Prompt length:', messages.length, 'userId:', userId);
```

### 5. Sem timeout

```ts
// ❌ NUNCA — request pode travar indefinidamente
await fetch(gatewayUrl, { method: 'POST', body });

// ✅ SEMPRE — com AbortController
const controller = new AbortController();
setTimeout(() => controller.abort(), 30_000);
await fetch(gatewayUrl, { signal: controller.signal });
```

### 6. Sem metadata de usuário

```ts
// ❌ NUNCA — impossível rastrear custo por usuário
headers: { Authorization: `Bearer ${key}` }

// ✅ SEMPRE — metadata para observabilidade
headers: {
  Authorization: `Bearer ${key}`,
  'cf-aig-metadata': JSON.stringify({ userId })
}
```

## Configuração no dashboard

1. Criar Gateway: **AI > AI Gateway > Create Gateway**.
2. Configurar **Cache** (TTL para respostas idênticas).
3. Configurar **Rate Limiting** (por IP ou por header).
4. Habilitar **Guardrails** (Llama Guard ou similar).
5. Configurar **Fallback** entre providers.
6. Configurar **Logs** com redaction de PII.

## Comandos

```bash
# Listar gateways (via API)
curl -X GET "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/ai-gateway/gateways" \
  -H "Authorization: Bearer $CF_API_TOKEN"

# Criar gateway
curl -X POST "https://api.cloudflare.com/client/v4/accounts/$ACCOUNT_ID/ai-gateway/gateways" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"myapp-gateway","cache_ttl":300,"rate_limiting":{"limit":100,"window":60}}'

# Logs (via dashboard)
# AI Gateway > [seu gateway] > Logs
```

## Checklist antes de finalizar

- [ ] Chamada usa `env.AI_GATEWAY_URL` (não provider direto)
- [ ] Header `Authorization` com chave do provider (não do Gateway)
- [ ] Header `cf-aig-metadata` com `userId`
- [ ] Input do usuário sanitizado antes do prompt
- [ ] Rate limit verificado por usuário
- [ ] Timeout configurado (AbortController)
- [ ] Retry com backoff para erros 5xx
- [ ] Fallback entre providers configurado no dashboard
- [ ] Guardrails ativos no dashboard
- [ ] Logs sem PII (redaction configurada)
- [ ] Testes cobrindo: sucesso, timeout, rate limit, input malicioso
- [ ] Custo estimado documentado

## Referências

- Cloudflare AI Gateway: https://developers.cloudflare.com/ai-gateway/
- Guardrails: https://developers.cloudflare.com/ai-gateway/guardrails/
- Rate limiting: https://developers.cloudflare.com/ai-gateway/configuration/rate-limiting/
- AGENT.md — seção 5, Gate 5 e Gate 7
