# SETUP.md — Configuração do ambiente

Guia completo para configurar o projeto localmente, do clone ao
primeiro `pnpm verify` verde.

**Público-alvo:** desenvolvedores configurando o projeto pela primeira vez.

**Tempo estimado:** 20–40 minutos (primeira vez), 5 minutos (recorrente).

**Pré-requisitos:** conta Cloudflare, acesso ao repositório Git, terminal.

---

## Índice

1. [Pré-requisitos](#1-pré-requisitos)
2. [Clone e instalação](#2-clone-e-instalação)
3. [Autenticação Cloudflare](#3-autenticação-cloudflare)
4. [Criação de recursos](#4-criação-de-recursos)
5. [Substituição de IDs](#5-substituição-de-ids)
6. [Configuração de secrets](#6-configuração-de-secrets)
7. [Migrations](#7-migrations)
8. [Dev server](#8-dev-server)
9. [Verificação](#9-verificação)
10. [Troubleshooting](#10-troubleshooting)

---

## 1. Pré-requisitos

### Versões mínimas

```bash
node --version    # >= 20.0.0
pnpm --version    # >= 9.0.0
git --version     # >= 2.40
```

### Instalação por sistema

**macOS (Homebrew):**
```bash
brew install node@20 pnpm git
brew install gitleaks       # para secrets scan local
```

**Linux (Ubuntu/Debian):**
```bash
# Node 20 via NodeSource
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# pnpm via corepack
corepack enable
corepack prepare pnpm@9.12.0 --activate

# git
sudo apt install -y git

# gitleaks (via binary)
curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz \
  | sudo tar -xz -C /usr/local/bin gitleaks
```

**Windows (WSL2 recomendado):**
Siga as instruções de Linux dentro do WSL2. Para PowerShell puro:
```powershell
winget install OpenJS.NodeJS.LTS
winget install pnpm.pnpm
winget install Git.Git
# gitleaks: baixar de https://github.com/gitleaks/gitleaks/releases
```

### Cloudflare

- Conta ativa (plano free é suficiente para dev).
- Acesso ao dashboard: https://dash.cloudflare.com
- `wrangler` será instalado como devDependency (`pnpm install` cuida disso).

### Verificação

```bash
node --version     # v20.x
pnpm --version     # 9.x
git --version      # 2.4x
wrangler --version # 3.9x (após pnpm install)
```

Se algum comando falhar, resolva antes de prosseguir.

---

## 2. Clone e instalação

### Clone

```bash
git clone <url-do-repo>
cd <nome-do-repo>
```

### Instalar dependências

```bash
pnpm install
```

**O que acontece:**
- Instala ~50 dependências (SvelteKit, Vitest, Playwright, Wrangler, Stryker, ESLint, etc.).
- Roda `pnpm prepare` automaticamente, que configura o Husky (pre-commit hook).
- Tempo estimado: 1–3 minutos.

### Verificar permissões dos scripts

```bash
chmod +x scripts/*.sh
chmod +x .husky/pre-commit
ls -la scripts/  # todos os .sh devem ter 'x' no modo
```

### Verificar que Husky está ativo

```bash
ls -la .husky/_/
# deve existir (Husky instalou seus hooks internos)
```

**Se `.husky/_/` não existir:**
```bash
pnpm prepare
```

---

## 3. Autenticação Cloudflare

Há duas formas. Escolha conforme seu contexto.

### Opção A — Login interativo (desenvolvimento local)

```bash
pnpm wrangler login
```

Isso abre o navegador. Autorize. O Wrangler salva o token em
`~/.wrangler/config/default.toml`.

**Vantagens:** simples, escopos completos, ideal para dev.
**Desvantagens:** não funciona em CI/headless.

### Opção B — API Token (CI/headless ou múltiplas contas)

1. Acesse: https://dash.cloudflare.com/profile/api-tokens
2. **Create Token** > **Custom token**.
3. Permissões necessárias:
   - `Account > Workers Scripts > Edit`
   - `Account > D1 > Edit`
   - `Account > Workers KV Storage > Edit`
   - `Account > Workers R2 Storage > Edit`
   - `Account > AI Gateway > Edit`
   - `Account > Account Settings > Read`
4. Copie o token (mostrado uma única vez).

Exporte:
```bash
export CLOUDFLARE_API_TOKEN=<seu-token>
export CLOUDFLARE_ACCOUNT_ID=<seu-account-id>
```

Para persistir, adicione ao `~/.bashrc` ou `~/.zshrc`.

### Verificar autenticação

```bash
pnpm wrangler whoami
# deve imprimir: sua conta, seu email, seus escopos
```

**Se falhar:** refaça o login ou verifique os escopos do token.

---

## 4. Criação de recursos

Você precisa criar recursos em **3 ambientes** (dev, staging, produção).
Para começar a desenvolver, apenas dev é obrigatório. Crie staging e
produção quando for fazer o primeiro deploy.

### 4.1 — D1 (banco SQL)

```bash
# Dev
pnpm wrangler d1 create myapp-db

# Staging
pnpm wrangler d1 create myapp-db-staging

# Produção
pnpm wrangler d1 create myapp-db-prod
```

**Cada comando retorna:**
```
✅ Successfully created DB 'myapp-db'

[[d1_databases]]
binding = "DB"
database_name = "myapp-db"
database_id = "abc123def-4567-89ab-cdef-0123456789ab"
```

**Copie o `database_id` de cada ambiente.** Você vai usá-los no passo 5.

### 4.2 — KV (cache)

```bash
# Dev (com preview obrigatório)
pnpm wrangler kv namespace create CACHE
pnpm wrangler kv namespace create CACHE --preview

# Staging
pnpm wrangler kv namespace create CACHE --env staging

# Produção
pnpm wrangler kv namespace create CACHE --env production
```

**Cada comando retorna:**
```
[[kv_namespaces]]
binding = "CACHE"
id = "abcdef1234567890abcdef1234567890"
preview_id = "1234567890abcdef1234567890abcdef"  # apenas para dev
```

**Copie os IDs.** Para dev, você precisa dos dois (id + preview_id).

### 4.3 — R2 (objetos)

```bash
# Dev
pnpm wrangler r2 bucket create myapp-storage

# Staging
pnpm wrangler r2 bucket create myapp-storage-staging

# Produção
pnpm wrangler r2 bucket create myapp-storage-prod
```

R2 não retorna ID — o nome do bucket é o identificador.
Já está correto nos `wrangler.*.toml`.

### 4.4 — AI Gateway

AI Gateway é criado pelo dashboard (não via CLI):

1. Acesse: https://dash.cloudflare.com > **AI** > **AI Gateway**
2. **Create Gateway**
3. Nome: `myapp-gateway` (ou outro)
4. Slug: gerado automaticamente (ex: `myapp-gateway`)
5. **Cache:** habilitar, TTL 300s
6. **Rate limiting:** habilitar, 100 req/min por IP
7. **Guardrails:** habilitar (Llama Guard)
8. **Fallback:** opcional (ex: OpenAI → Anthropic)

**Anote:**
- `ACCOUNT_ID` (visível na URL do dashboard ou em `wrangler whoami`)
- `GATEWAY_NAME` (slug do gateway, ex: `myapp-gateway`)

A URL final será:
```
https://gateway.ai.cloudflare.com/v1/<ACCOUNT_ID>/<GATEWAY_NAME>/openai
```

### 4.5 — Resumo dos recursos

Ao final deste passo, você deve ter:

| Recurso | Dev | Staging | Produção |
|---------|-----|---------|----------|
| D1 | `myapp-db` ✅ | `myapp-db-staging` ✅ | `myapp-db-prod` ✅ |
| KV | `CACHE` + preview ✅ | `CACHE` ✅ | `CACHE` ✅ |
| R2 | `myapp-storage` ✅ | `myapp-storage-staging` ✅ | `myapp-storage-prod` ✅ |
| AI Gateway | `myapp-gateway` ✅ | (mesmo) | (mesmo) |

---

## 5. Substituição de IDs

Os arquivos `wrangler*.toml` contêm placeholders `REPLACE_*` que precisam
ser substituídos pelos valores reais dos recursos criados no passo 4.

### 5.1 — wrangler.toml (dev)

Abra o arquivo e substitua:

| Placeholder | Valor |
|-------------|-------|
| `REPLACE_LOCAL_D1_ID` | `database_id` do `myapp-db` |
| `REPLACE_LOCAL_KV_ID` | `id` do `CACHE` |
| `REPLACE_LOCAL_KV_PREVIEW_ID` | `preview_id` do `CACHE` |
| `REPLACE_ACCOUNT` | seu Cloudflare Account ID |
| `REPLACE_GATEWAY` | `myapp-gateway` (ou o nome que escolheu) |

Exemplo de como deve ficar:
```toml
[[d1_databases]]
binding = "DB"
database_name = "myapp-db"
database_id = "abc123def-4567-89ab-cdef-0123456789ab"

[[kv_namespaces]]
binding = "CACHE"
id = "abcdef1234567890abcdef1234567890"
preview_id = "1234567890abcdef1234567890abcdef"

[vars]
AI_GATEWAY_URL = "https://gateway.ai.cloudflare.com/v1/1234abcd5678/myapp-gateway/openai"
```

### 5.2 — wrangler.staging.toml

| Placeholder | Valor |
|-------------|-------|
| `REPLACE_STAGING_D1_ID` | `database_id` do `myapp-db-staging` |
| `REPLACE_STAGING_KV_ID` | `id` do KV staging |
| `REPLACE_STAGING_KV_PREVIEW_ID` | `preview_id` do KV staging |
| `REPLACE_ACCOUNT` | seu Cloudflare Account ID |
| `REPLACE_GATEWAY` | nome do gateway |

### 5.3 — wrangler.production.toml

| Placeholder | Valor |
|-------------|-------|
| `REPLACE_PROD_D1_ID` | `database_id` do `myapp-db-prod` |
| `REPLACE_PROD_KV_ID` | `id` do KV prod |
| `REPLACE_PROD_KV_PREVIEW_ID` | `preview_id` do KV prod |
| `REPLACE_ACCOUNT` | seu Cloudflare Account ID |
| `REPLACE_GATEWAY` | nome do gateway |

### 5.4 — Verificação

```bash
grep -rn "REPLACE_" wrangler*.toml
```

**Saída esperada:** nada. Se aparecer qualquer linha, ainda há
placeholder não substituído.

### 5.5 — Verificar sintaxe dos TOML

```bash
pnpm wrangler deploy --dry-run --env staging -c wrangler.staging.toml
```

Não vai fazer deploy — apenas valida o arquivo. Saída esperada:
```
--dry-run: exiting now.
```

---

## 6. Configuração de secrets

Secrets **NUNCA** ficam em código ou em `wrangler.toml`. Usamos duas
camadas:

- **`.env`** — para desenvolvimento local (não commitado).
- **`wrangler secret put`** — para staging e produção (armazenados na
  Cloudflare, criptografados).

### 6.1 — Secrets locais (`.env`)

```bash
cp .env.example .env
```

Edite `.env` com valores reais:

```bash
# Cloudflare CLI
CLOUDFLARE_ACCOUNT_ID=<account id, 32 hex chars>
CLOUDFLARE_API_TOKEN=<token (opcional se fez wrangler login)>

# Aplicação
SESSION_SECRET=<openssl rand -base64 32>
JWT_SECRET=<openssl rand -base64 32>

# AI Gateway
AI_GATEWAY_URL=https://gateway.ai.cloudflare.com/v1/<ACCOUNT>/<GATEWAY>/openai
OPENAI_API_KEY=sk-...

# Runtime
ENVIRONMENT=development
LOG_LEVEL=debug
```

**Gerar secrets seguros:**
```bash
openssl rand -base64 32   # para cada secret
```

**Verificar que `.env` NÃO será commitado:**
```bash
git check-ignore .env
# saída esperada: .env
```

Se a saída estiver vazia, algo está errado no `.gitignore` — corrija
antes de continuar.

### 6.2 — Secrets remotos (staging)

```bash
pnpm wrangler secret put SESSION_SECRET --env staging
# (cola o valor quando pedido)

pnpm wrangler secret put JWT_SECRET --env staging
pnpm wrangler secret put OPENAI_API_KEY --env staging
```

**Verificar:**
```bash
pnpm wrangler secret list --env staging
```

Saída esperada:
```json
[
  { "name": "SESSION_SECRET", "type": "secret_text" },
  { "name": "JWT_SECRET", "type": "secret_text" },
  { "name": "OPENAI_API_KEY", "type": "secret_text" }
]
```

### 6.3 — Secrets remotos (produção)

**Só faça isso quando estiver pronto para o primeiro deploy de produção.**

```bash
pnpm wrangler secret put SESSION_SECRET --env production
pnpm wrangler secret put JWT_SECRET --env production
pnpm wrangler secret put OPENAI_API_KEY --env production
```

### 6.4 — Rotação de secrets

Se um secret vazou (gitleaks encontrou no histórico, por exemplo):

```bash
# 1. Gerar novo valor
openssl rand -base64 32

# 2. Atualizar em todos os ambientes
pnpm wrangler secret put SESSION_SECRET --env staging
pnpm wrangler secret put SESSION_SECRET --env production

# 3. Invalidar sessões ativas (delete chaves em KV)
# 4. Revogar token no provider de origem
# 5. Documentar post-mortem
```

Ver skill `security-leaks` para procedimento completo.

---

## 7. Migrations

Migrations são aplicadas em ordem crescente (`0001`, `0002`, ...).
Cada ambiente tem seu próprio D1.

### 7.1 — Local (dev)

```bash
pnpm wrangler d1 migrations apply DB --local
```

O `--local` usa um SQLite em `.wrangler/state/v3/d1/` — não toca a
Cloudflare.

**Verificar:**
```bash
pnpm wrangler d1 execute DB --local --command "SELECT * FROM schema_info"
```

Saída esperada:
```
┌───────┬─────────┬────────────┐
│ key   │ value   │ updated_at │
├───────┼─────────┼────────────┤
│ version │ 0002  │ 17...      │
└───────┴─────────┴────────────┘
```

### 7.2 — Staging

```bash
pnpm wrangler d1 migrations apply DB --env staging
```

### 7.3 — Produção

**Só aplique após validar em staging.**

```bash
pnpm wrangler d1 migrations apply DB --env production
```

### 7.4 — Verificar migrations pendentes

```bash
pnpm wrangler d1 migrations list DB --env staging
```

Saída esperada:
```
Migrations to be applied:
  (nenhuma)  ← tudo aplicado

Ou:

Migrations to be applied:
  ✅ 0003_add_teams.sql
```

### 7.5 — Criar nova migration

```bash
pnpm wrangler d1 migrations create DB add_teams
```

Isso cria `migrations/0003_add_teams.sql` (vazio). Edite e teste:

```bash
# Aplicar local primeiro
pnpm wrangler d1 migrations apply DB --local

# Verificar que rodou
pnpm wrangler d1 execute DB --local --command "SELECT * FROM schema_info"
```

**Regra de ouro:** migrations são **imutáveis** depois de aplicadas em
produção. Se precisar corrigir, crie uma nova migration.

---

## 8. Dev server

### 8.1 — Iniciar

```bash
pnpm dev
```

Saída esperada:
```
  VITE v5.4.11  ready in 432 ms

  ➜  Local:   http://localhost:5173/
  ➜  Network: use --host to expose
  ➜  press h + enter to show help
```

Abra http://localhost:5173 no navegador.

### 8.2 — Verificar que os bindings funcionam

Abra o terminal onde o dev server está rodando. Em outro terminal:

```bash
curl http://localhost:5173/api/health
```

Saída esperada (ou equivalente):
```json
{"status":"ok","env":"development"}
```

Se retornar erro 500, verifique:
- Se `.env` está preenchido.
- Se as migrations foram aplicadas localmente (passo 7.1).
- Se os IDs em `wrangler.toml` estão corretos.

### 8.3 — Testar binding D1

```bash
curl http://localhost:5173/api/health/db
```

Se você criou esse endpoint, deve retornar algo como:
```json
{"users": 0, "db": "ok"}
```

### 8.4 — Parar

`Ctrl+C` no terminal do dev server.

### 8.5 — Rebuild após mudanças em `wrangler.toml`

Se você alterar qualquer binding, **reinicie o dev server**:

```bash
# Ctrl+C
pnpm dev
```

---

## 9. Verificação

Após o setup, rode a sequência abaixo. Cada comando valida uma camada.

### 9.1 — Type check

```bash
pnpm check
```

**Valida:** tipos TypeScript + Svelte.
**Falha típica:** imports não usados, tipos incompatíveis.
**Tempo:** ~5s.

### 9.2 — Lint

```bash
pnpm lint
```

**Valida:** formatação (Prettier) + regras ESLint.
**Falha típica:** indentação, `console.log` esquecido.
**Correção rápida:** `pnpm format` (auto-fix).
**Tempo:** ~10s.

### 9.3 — Testes unitários

```bash
pnpm test
```

**Valida:** lógica pura, mocks de bindings.
**Falha típica:** asserção desatualizada, mock incompleto.
**Tempo:** ~15s.

### 9.4 — Cobertura

```bash
pnpm test:coverage
```

**Valida:** thresholds mínimos (70% lines/functions, 60% branches).
**Falha típica:** arquivo novo sem teste.
**Relatório:** `coverage/index.html`.
**Tempo:** ~20s.

### 9.5 — Build

```bash
pnpm build
```

**Valida:** compilação para produção.
**Falha típica:** dependência circular, `env` ausente.
**Tempo:** ~30s.

### 9.6 — E2E (Playwright)

```bash
pnpm test:e2e
```

**Valida:** fluxos end-to-end em browser real.
**Pré-requisito:** primeiro run instala browsers (~1 min).
**Tempo:** ~1–3 min.

Se for a primeira vez:
```bash
pnpm exec playwright install --with-deps chromium firefox
```

### 9.7 — Security scan

```bash
pnpm security:scan
```

**Valida:** secrets + dependências vulneráveis + OWASP + D1.
**Falha típica:** `gitleaks` encontrando falso positivo, `pnpm audit` reportando vulnerabilidade.
**Tempo:** ~30s.

### 9.8 — Complexity scan

```bash
pnpm complexity:scan
```

**Valida:** complexidade ciclomática + duplicação + dead code.
**Falha típica:** função com complexidade > 10.
**Tempo:** ~20s.

### 9.9 — Pipeline completo

```bash
pnpm verify
```

Roda em sequência: `check` → `lint` → `test:coverage` → `build` → `e2e`.

**Se todos passarem: ambiente está configurado corretamente.**

### 9.10 — Ordem de execução recomendada

Para desenvolvimento diário, use esta ordem:

```bash
# Antes de cada commit (o pre-commit hook já cuida disso)
pnpm lint && pnpm check

# Antes de cada push
pnpm verify --fast    # pula e2e

# Antes de cada PR
pnpm verify           # pipeline completo

# Antes de cada deploy
pnpm security:scan
pnpm complexity:scan
```

---

## 10. Troubleshooting

### Problema: `pnpm install` falha com erro de rede

**Sintoma:** `ERR_PNPM_META_FETCH_FAIL` ou timeout.

**Solução:**
```bash
# Limpar cache
pnpm store prune

# Tentar novamente com registry explícito
pnpm install --registry=https://registry.npmjs.org
```

### Problema: `wrangler login` não abre o navegador

**Sintoma:** comando trava ou navegador não abre.

**Solução:** use token de API (passo 3, opção B).

### Problema: `pnpm dev` retorna erro 500 nos endpoints

**Sintomas possíveis:**
- `D1_ERROR: no such table: users`
- `Cannot read properties of undefined (reading 'get')`

**Causas e soluções:**

| Erro | Causa | Solução |
|------|-------|---------|
| `no such table` | Migrations não aplicadas | `pnpm wrangler d1 migrations apply DB --local` |
| `undefined 'get'` | Binding KV ausente | Verificar `preview_id` em `wrangler.toml` |
| `D1_ERROR: binding not found` | `database_id` errado | Refazer passo 5.1 |
| `AI binding not found` | `[ai]` ausente | Verificar seção `[ai]` em `wrangler.toml` |

### Problema: `pnpm check` reporta erros em arquivos gerados

**Sintoma:** erros em `.svelte-kit/` ou `node_modules/`.

**Solução:**
```bash
rm -rf .svelte-kit
pnpm exec svelte-kit sync
pnpm check
```

### Problema: `pnpm test:e2e` falha com "browser not found"

**Sintoma:** `Executable doesn't exist at .../chrome-linux/chrome`.

**Solução:**
```bash
pnpm exec playwright install --with-deps chromium firefox
```

### Problema: pre-commit hook não roda

**Sintoma:** você faz commit e nada acontece.

**Verificação:**
```bash
ls -la .husky/_/
cat .husky/pre-commit
```

**Solução:**
```bash
pnpm prepare
chmod +x .husky/pre-commit
```

### Problema: `gitleaks` não encontrado

**Sintoma:** pre-commit hook avisa "gitleaks não encontrado".

**Solução:**

**macOS:**
```bash
brew install gitleaks
```

**Linux:**
```bash
curl -sSL https://github.com/gitleaks/gitleaks/releases/latest/download/gitleaks_linux_x64.tar.gz \
  | sudo tar -xz -C /usr/local/bin gitleaks
```

**Windows:** baixe de https://github.com/gitleaks/gitleaks/releases.

### Problema: `wrangler d1 migrations apply` falha com "database_id not found"

**Sintoma:** erro 7003 ou "Couldn't find a D1 DB with that name".

**Causa:** `database_id` em `wrangler.toml` não corresponde ao real.

**Solução:**
```bash
pnpm wrangler d1 list
# copie o UUID exato do banco desejado
# cole em wrangler.toml
```

### Problema: `pnpm verify` falha em `pnpm build` com "ENOENT: no such file"

**Sintoma:** build falha com erro de arquivo ausente.

**Causa:** `svelte-kit sync` não rodou após mudanças estruturais.

**Solução:**
```bash
pnpm exec svelte-kit sync
pnpm build
```

### Problema: erros de tipo no `.env`

**Sintoma:** `Property 'SESSION_SECRET' does not exist on type 'Env'`.

**Solução:** adicione a tipagem em `src/app.d.ts` (se ainda não estiver):

```ts
interface Platform {
  env: {
    DB: D1Database;
    CACHE: KVNamespace;
    STORAGE: R2Bucket;
    AI: Ai;
    ENVIRONMENT: string;
    AI_GATEWAY_URL: string;
    SESSION_SECRET: string;
    JWT_SECRET: string;
    OPENAI_API_KEY: string;
  };
}
```

### Problema: deploy em staging falha com "AI_GATEWAY_URL is not defined"

**Sintoma:** Worker falha no primeiro request.

**Causa:** `AI_GATEWAY_URL` não foi configurado em `[vars]` do staging.

**Solução:** verifique `wrangler.staging.toml` se a seção `[vars]` está
completa (passo 5.2).

### Problema: `pnpm security:scan` falha em `pnpm audit`

**Sintoma:** "high severity vulnerability found".

**Solução:**
```bash
# Ver detalhes
pnpm audit

# Tentar atualizar dependência
pnpm update <pacote>

# Se não houver fix disponível, avaliar se é realmente explorável
# no seu contexto. Documente a decisão.
```

### Problema: gitleaks encontra "REPLACE_" em wrangler.toml

**Sintoma:** `gitleaks protect` bloqueia commit.

**Causa:** placeholders não substituídos (passo 5).

**Solução:** completar o passo 5 — todos os `REPLACE_*` devem ser
substituídos antes de commitar.

---

## Checklist final

Após completar todos os passos, você deve conseguir marcar:

### Ambiente
- [ ] `node --version` >= 20
- [ ] `pnpm --version` >= 9
- [ ] `pnpm install` sem erro
- [ ] Husky configurado (`.husky/_/` existe)
- [ ] Scripts executáveis (`chmod +x scripts/*.sh`)
- [ ] `wrangler whoami` retorna sua conta

### Recursos Cloudflare
- [ ] D1 dev, staging, prod criados
- [ ] KV dev (com preview), staging, prod criados
- [ ] R2 dev, staging, prod criados
- [ ] AI Gateway criado no dashboard

### Configuração
- [ ] `REPLACE_*` substituídos em todos os `wrangler.*.toml`
- [ ] `pnpm wrangler deploy --dry-run` sem erro
- [ ] `.env` criado com valores reais
- [ ] `.env` no `.gitignore` (`git check-ignore .env` retorna)
- [ ] Secrets configurados em staging
- [ ] Secrets configurados em produção (se for deployar)

### Banco de dados
- [ ] Migrations aplicadas localmente
- [ ] `SELECT * FROM schema_info` retorna `version = 0002`
- [ ] Migrations aplicadas em staging

### Verificação
- [ ] `pnpm check` verde
- [ ] `pnpm lint` verde
- [ ] `pnpm test` verde
- [ ] `pnpm build` verde
- [ ] `pnpm test:e2e` verde
- [ ] `pnpm security:scan` verde
- [ ] `pnpm complexity:scan` verde
- [ ] **`pnpm verify` verde** ← critério de conclusão

### Dev server
- [ ] `pnpm dev` inicia sem erro
- [ ] `curl http://localhost:5173/api/health` retorna 200
- [ ] Bindings (DB, KV, R2, AI) acessíveis

---

## Próximos passos

Após o setup completo:

1. **Para entender o harness de agentes:** ver `docs/HARNESS.md`.
2. **Para usar este kit em outro projeto:** ver `docs/HARNESS.md#bootstrap`.
3. **Para contribuir com código:** ver `.agents/skills/git-flow/SKILL.md`.
4. **Para revisar segurança:** ver `.agents/skills/security-leaks/SKILL.md`.

---

## Referências

- Cloudflare Workers docs: https://developers.cloudflare.com/workers/
- Cloudflare D1 docs: https://developers.cloudflare.com/d1/
- Cloudflare KV docs: https://developers.cloudflare.com/kv/
- Cloudflare R2 docs: https://developers.cloudflare.com/r2/
- Cloudflare AI Gateway: https://developers.cloudflare.com/ai-gateway/
- SvelteKit docs: https://kit.svelte.dev/docs
- Wrangler CLI: https://developers.cloudflare.com/workers/wrangler/
- README.md — visão geral do projeto
- docs/HARNESS.md — configuração do harness de agentes
