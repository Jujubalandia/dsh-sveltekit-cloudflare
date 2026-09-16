---
name: cloudflare-r2
description: "Cloudflare R2, o object storage compatível com a API S3: upload, download, assets estáticos, backups e URLs assinadas. Use ao trabalhar com env.STORAGE, arquivos em workers/src/storage/, ou ao transmitir arquivos grandes."
---

# Skill: cloudflare-r2

## Quando usar

Carregue esta skill ao trabalhar com:
- Upload ou download de arquivos
- Armazenamento de assets estáticos (imagens, PDFs, vídeos)
- Backups e exportações
- Qualquer arquivo em `workers/src/storage/` ou que importe `env.STORAGE`

## O que é R2

Cloudflare R2 é um armazenamento de objetos compatível com a API S3,
sem taxas de egress. Buckets são privados por padrão.

Características importantes:
- **Buckets são privados por padrão** — acesso via signed URL ou Worker.
- Objetos até 5 TB; uploads >5 GB exigem multipart.
- Zero egress fee.
- Consistência forte (diferente do KV).
- Ideal para arquivos binários, não para dados relacionais ou cache.

## Regras de ouro

1. **Bucket NUNCA público.** Acesso sempre via Worker ou signed URL.
2. **Signed URL com expiração ≤15 min.** Nunca URLs permanentes.
3. **Validar tipo e tamanho ANTES do upload.** Não confiar no cliente.
4. **Key naming determinística** com prefixo por tenant/usuário.
5. **Nunca armazenar PII não criptografada.**

## Padrões corretos

### Upload com validação

```ts
// workers/src/storage/upload.ts
const MAX_SIZE = 10 * 1024 * 1024; // 10 MB
const ALLOWED_TYPES = new Set([
  'image/png',
  'image/jpeg',
  'image/webp',
  'application/pdf'
]);

export async function uploadFile(
  env: Env,
  input: {
    ownerId: string;
    fileName: string;
    contentType: string;
    size: number;
    body: ReadableStream;
  }
) {
  if (input.size > MAX_SIZE) {
    throw new Error(`Arquivo excede ${MAX_SIZE} bytes`);
  }
  if (!ALLOWED_TYPES.has(input.contentType)) {
    throw new Error(`Content-type não permitido: ${input.contentType}`);
  }

  const key = buildKey(input.ownerId, input.fileName);

  await env.STORAGE.put(key, input.body, {
    httpMetadata: {
      contentType: input.contentType,
      cacheControl: 'private, max-age=0'
    },
    customMetadata: {
      ownerId: input.ownerId,
      originalName: input.fileName
    }
  });

  return { key };
}
```

### Key naming determinística

```ts
import { randomUUID } from 'node:crypto';

function buildKey(ownerId: string, fileName: string): string {
  const ext = fileName.split('.').pop()?.toLowerCase() ?? 'bin';
  const uuid = randomUUID();
  const now = new Date();
  const yyyy = now.getUTCFullYear();
  const mm = String(now.getUTCMonth() + 1).padStart(2, '0');

  return `${ownerId}/${yyyy}/${mm}/${uuid}.${ext}`;
}
```

Padrão: `<ownerId>/<yyyy>/<mm>/<uuid>.<ext>`

Vantagens:
- Facilita limpeza por tenant.
- Facilita lifecycle policies por data.
- Evita colisão de nome.
- Não vaza nome original do arquivo.

### Download com verificação de ownership

```ts
export async function downloadFile(
  env: Env,
  userId: string,
  key: string
) {
  // Verifica ownership ANTES de buscar
  const meta = await env.STORAGE.head(key);
  if (!meta) throw new Error('Not found');

  if (meta.customMetadata?.ownerId !== userId) {
    throw new Error('Forbidden');
  }

  const object = await env.STORAGE.get(key);
  if (!object) throw new Error('Not found');

  return object;
}
```

### Signed URL (quando o cliente busca direto do R2)

```ts
import { AwsClient } from 'aws4fetch';

export async function getSignedUrl(
  env: Env,
  key: string,
  expiresIn = 900 // 15 min máximo
): Promise<string> {
  if (expiresIn > 900) {
    throw new Error('Signed URL não pode exceder 15 minutos');
  }

  const client = new AwsClient({
    accessKeyId: env.R2_ACCESS_KEY_ID,
    secretAccessKey: env.R2_SECRET_ACCESS_KEY
  });

  const url = new URL(
    `https://${env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${env.R2_BUCKET}/${key}`
  );
  url.searchParams.set('X-Amz-Expires', String(expiresIn));

  const signed = await client.sign(
    new Request(url, { method: 'GET' }),
    { aws: { signQuery: true } }
  );

  return signed.url;
}
```

### Deletar com verificação

```ts
export async function deleteFile(
  env: Env,
  userId: string,
  key: string
) {
  const meta = await env.STORAGE.head(key);
  if (!meta) return; // idempotente

  if (meta.customMetadata?.ownerId !== userId) {
    throw new Error('Forbidden');
  }

  await env.STORAGE.delete(key);
}
```

### Listar arquivos de um usuário

```ts
export async function listUserFiles(
  env: Env,
  userId: string,
  cursor?: string
) {
  return env.STORAGE.list({
    prefix: `${userId}/`,
    cursor,
    limit: 100
  });
}
```

## Anti-patterns (proibidos)

### 1. Bucket público

```text
❌ NUNCA configure public access no bucket.
❌ NUNCA use r2.dev subdomain em produção.
✅ Acesso via Worker ou signed URL.
```

### 2. Signed URL sem expiração

```ts
// ❌ NUNCA
const url = await getPermanentUrl(key);

// ✅ SEMPRE
const url = await getSignedUrl(env, key, 900);
```

### 3. Confiar em content-type do cliente

```ts
// ❌ NUNCA — cliente pode mentir
await env.STORAGE.put(key, body, {
  httpMetadata: { contentType: request.headers.get('content-type')! }
});

// ✅ SEMPRE — valide contra allowlist
if (!ALLOWED_TYPES.has(contentType)) throw new Error('Invalid type');
```

### 4. Key com nome original do cliente

```ts
// ❌ NUNCA — path traversal, colisão, vazamento de nome
const key = fileName;

// ✅ SEMPRE — sanitize e gere UUID
const key = `${ownerId}/${yyyy}/${mm}/${randomUUID()}.${ext}`;
```

### 5. Upload sem limite de tamanho

```ts
// ❌ NUNCA — DoS trivial
await env.STORAGE.put(key, request.body);

// ✅ SEMPRE — valide Content-Length ANTES
const size = Number(request.headers.get('content-length') ?? 0);
if (size > MAX_SIZE) return new Response('Too large', { status: 413 });
```

### 6. Servir arquivo sem verificar ownership

```ts
// ❌ NUNCA — qualquer um lê qualquer arquivo
const obj = await env.STORAGE.get(key);

// ✅ SEMPRE — verifique ownership
const meta = await env.STORAGE.head(key);
if (meta?.customMetadata?.ownerId !== userId) {
  return new Response('Forbidden', { status: 403 });
}
```

### 7. Armazenar PII sem criptografia

```ts
// ❌ NUNCA
await env.STORAGE.put(key, JSON.stringify({ cpf, address }));

// ✅ SEMPRE — criptografe antes, ou use D1 com column-level encryption
```

## Streaming e arquivos grandes

Para uploads >5 MB, use multipart via presigned URLs para o cliente
enviar direto ao R2, contornando o limite de memória do Worker:

```ts
// 1. Worker gera URL de upload assinada
const uploadUrl = await getSignedPutUrl(env, key, 900);

// 2. Cliente faz PUT direto para R2
// 3. Cliente notifica Worker após conclusão
// 4. Worker valida e registra metadados no D1
```

## Comandos

```bash
# Criar bucket
wrangler r2 bucket create myapp-storage

# Listar buckets
wrangler r2 bucket list

# Upload manual (dev)
wrangler r2 object put myapp-storage/test.txt --file=./test.txt

# Download manual (dev)
wrangler r2 object get myapp-storage/test.txt --file=./out.txt

# Deletar objeto
wrangler r2 object delete myapp-storage/test.txt

# Listar objetos
wrangler r2 object list myapp-storage --prefix="user-1/"
```

## Lifecycle policies

Configure via dashboard para:
- Deletar objetos `tmp/` após 24h.
- Mover para armazenamento mais frio após 90 dias.
- Deletar versões antigas após 30 dias.

## Checklist antes de finalizar

- [ ] Bucket privado (não público)
- [ ] Key com prefixo por owner e UUID (sem nome original)
- [ ] Validação de content-type contra allowlist
- [ ] Validação de tamanho antes do upload
- [ ] Signed URLs com expiração ≤15 min
- [ ] Ownership verificado antes de GET/DELETE
- [ ] Content-Type retornado ao cliente com sanitização
- [ ] Metadados registrados no D1 (`uploaded_files`)
- [ ] Testes cobrindo upload válido, tipo inválido, tamanho excedido, ownership negado
- [ ] Lifecycle policy configurada para prefixos temporários

## Referências

- Cloudflare R2 docs: https://developers.cloudflare.com/r2/
- R2 presigned URLs: https://developers.cloudflare.com/r2/api/s3/presigned-urls/
- aws4fetch: https://github.com/mhart/aws4fetch
- AGENT.md — seção 5, Gate 4
