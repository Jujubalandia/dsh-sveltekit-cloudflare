# FEATURES.md — Inventário de componentes

Referência estática do que este kit entrega. Diferente de `HARNESS.md`
(que explica *como usar e estender*), este documento é um **inventário**:
lista tudo que existe, com uma linha por item.

**Público-alvo:**
- Desenvolvedores avaliando o kit.
- Times fazendo onboarding.
- Quem faz bootstrap em novo projeto (o que copiar, adaptar, remover).
- Auditoria e revisão periódica.

**Manutenção:** atualize este arquivo sempre que adicionar, remover ou
renomear um componente.

---

## Índice

1. [Resumo numérico](#1-resumo-numérico)
2. [Skills](#2-skills)
3. [Scripts](#3-scripts)
4. [Subagentes](#4-subagentes)
5. [Security Gates](#5-security-gates)
6. [Hooks](#6-hooks)
7. [Workflows CI/CD](#7-workflows-cicd)
8. [Testes](#8-testes)
9. [Documentação](#9-documentação)
10. [Configuração](#10-configuração)
11. [Tabela: manter / adaptar / remover](#11-tabela-manter--adaptar--remover)
12. [Checklist de completude](#12-checklist-de-completude)

---

## 1. Resumo numérico

| Categoria | Quantidade |
|-----------|-----------:|
| Skills | 12 |
| Scripts | 8 |
| Subagentes | 5 |
| Security Gates | 8 |
| Tipos de hook | 8 |
| Workflows CI/CD | 2 |
| Suítes de teste | 3 (unit, e2e, mutation) |
| Documentos | 8 |
| Arquivos de configuração | 6 |
| Migrations | 2 |

---

## 2. Skills

Skills são carregadas sob demanda (2–3 por tarefa). Cada uma define
padrões, anti-patterns e checklist do seu domínio.

| # | Skill | Cobertura | Quando carregar |
|---|-------|-----------|-----------------|
| 1 | `cloudflare-d1` | SQL, migrations, prepared statements | Arquivos em `workers/src/db/`, `migrations/` |
| 2 | `cloudflare-kv` | Cache, feature flags, TTL | Arquivos em `workers/src/cache/` |
| 3 | `cloudflare-r2` | Objetos, signed URLs, upload | Arquivos em `workers/src/storage/` |
| 4 | `cloudflare-ai-gateway` | LLM, guardrails, prompt injection | Arquivos em `workers/src/ai/` |
| 5 | `sveltekit-runes` | Svelte 5, `$state`, `$derived`, `$props` | Qualquer componente `.svelte` |
| 6 | `sveltekit-auth` | Sessão, guards, form actions de login | `hooks.server.ts`, `+layout.server.ts` |
| 7 | `cloudflare-security` | Headers, CORS, hardening | Config de segurança, revisão pré-deploy |
| 8 | `owasp-top10` | Top 10 OWASP adaptado | Auth, input, endpoints, DB, upload, LLM |
| 9 | `security-leaks` | 7 categorias de vazamento | Antes de commit, PR, deploy |
| 10 | `code-complexity` | Complexidade, duplicação, dead code | Adicionar/refatorar funções |
| 11 | `git-flow` | Branches, commits, PRs, releases | Qualquer operação Git |
| 12 | `agentic-code-review` | Camadas de review, red flags | Revisão de PR |

**Localização:** `.agents/skills/<nome>/SKILL.md`

**Regra de ouro:** 2–3 skills por tarefa. Mais que isso indica que a
tarefa deveria ser dividida.

---

## 3. Scripts

Scripts são verificações determinísticas. Diferente de skills (que
são contexto), scripts **executam** e retornam exit code.

| # | Script | Propósito | Quando roda |
|---|--------|-----------|-------------|
| 1 | `verify.sh` | Pipeline completo: check + lint + unit + build + e2e | Antes de push/PR |
| 2 | `security-scan.sh` | Secrets + deps + OWASP + D1 + AI Gateway | Antes de PR e deploy |
| 3 | `owasp-check.sh` | OWASP Top 10 (A01–A10) via grep estrutural | Pre-PR, auditoria |
| 4 | `complexity-check.sh` | Complexidade + duplicação + dead code | Pre-PR, auditoria |
| 5 | `smoke-test.sh` | Endpoints + headers + 404 pós-deploy | Após deploy |
| 6 | `pre-edit-check.sh` | Lembra skill + gates antes de editar | Hook PreToolUse |
| 7 | `post-edit-check.sh` | Check + lint + teste focado após editar | Hook PostToolUse |
| 8 | `git-flow.sh` | Fluxo Git guiado (start, commit, push, pr, release) | Interativo |

**Localização:** `scripts/`

**Comandos pnpm equivalentes:**

```bash
pnpm verify            # → scripts/verify.sh
pnpm security:scan     # → scripts/security-scan.sh
pnpm owasp:check       # → scripts/owasp-check.sh
pnpm complexity:scan   # → scripts/complexity-check.sh
pnpm smoke staging     # → scripts/smoke-test.sh
pnpm git:flow <ação>   # → scripts/git-flow.sh
```

**Flags úteis:**

```bash
./scripts/verify.sh --fast        # pula e2e
./scripts/verify.sh --no-build    # pula build
./scripts/owasp-check.sh --warn-only
./scripts/complexity-check.sh --warn-only
./scripts/security-scan.sh --staged
```

---

## 4. Subagentes

Princípio: **"One sub-agent drafts the change. A separate one verifies it."**

| # | Subagente | Papel | Modelo | Ferramentas |
|---|-----------|-------|--------|-------------|
| 1 | Drafter | Implementa a mudança | `deepseek-chat` | edit, write, bash |
| 2 | Verifier | Verifica independentemente (não confia no drafter) | `deepseek-chat` | read, bash, grep |
| 3 | Judge | Decide se está pronto com base em evidências | `deepseek-reasoner` | read, grep |
| 4 | Security Auditor | Roda OWASP + gitleaks | `deepseek-chat` | bash, read, grep |
| 5 | Complexity Auditor | Analisa complexidade + redundância | `deepseek-chat` | bash, read |

**Como isso funciona no DSH:** estes papéis são uma **intenção de design**,
documentada em `harness.config.yml` — que é um documento conceitual, sem
efeito de runtime. O `@deepseek-ai/dsh-subagent` é o Service Definition do
seam `ctx.subagents` e não expõe config `agents`; o mecanismo nativo para
papéis nomeados é **Agent Presets** (um diretório com `agent.cordis.yml`).
Na prática, cada papel se realiza chamando a tool `subagent` com um prompt
distinto.

**Regra de ouro:** nunca deixe o mesmo subagente que produziu verificar.

**Quando usar cada um:**

| Cenário | Subagentes |
|---------|-----------|
| PR pequeno sem risco | Drafter (Verifier opcional) |
| PR normal | Drafter + Verifier |
| Toca auth/DB/IA/R2 | + Security Auditor |
| PR grande/complexo | + Complexity Auditor |
| Decisão final | Judge |

---

## 5. Security Gates

Regras que o agente **não pode violar**. Definidas em `AGENTS.md`,
seção 5.

| # | Gate | Regra | Enforcement |
|---|------|-------|-------------|
| 1 | Secrets | Nunca hardcode. `wrangler secret put`. | gitleaks (pre-commit + CI) |
| 2 | Input | Zod em todo endpoint. CORS sem `*` em prod. | owasp-check A03, A05 |
| 3 | D1 | Prepared statements. Migrations versionadas. | owasp-check A03, review |
| 4 | R2 | Privado, signed URLs ≤15min, validar tipo/tamanho. | owasp-check A08, review |
| 5 | AI Gateway | Guardrails + rate limit + log com redaction. | owasp-check A03, A10 |
| 6 | OWASP | Top 10 verificado. | `scripts/owasp-check.sh` |
| 7 | Prompt Injection | Input sanitizado antes de LLM. | owasp-check A03 |
| 8 | Deploy | Staging → smoke → aprovação → prod. | `.github/workflows/release.yml` + environment protegido |

**Onde os gates são aplicados:**

| Gate | Onde |
|------|------|
| `.husky/pre-commit` | Gate 1 — lint, type check e gitleaks nos arquivos staged |
| Hook `PostToolUse` (`.agents/hooks.json`) | Gates 2, 3 — feedback no contexto do agente após cada edição |
| `.husky/pre-push` | Gates 1, 2, 3, 4, 5, 6, 7 — verify + security + OWASP + complexidade |
| `.github/workflows/ci.yml` | Repete todos os gates no CI (fonte da verdade) |
| Environment protegido no GitHub | Gate 8 — aprovação de deploy em produção |

Nenhum desses é o `require_approval` do `harness.config.yml`: aquele
bloco é documentação de intenção, sem efeito de runtime.

---

## 6. Hooks

O bundle registra **um** bridge de hooks — `@deepseek-ai/dsh-hooks-claude-code`
— via `cordis.patch.yml`, configurado por `.agents/hooks.json`. Os gates
que não são eventos do bridge vivem nos hooks de git.

| # | Gate | Onde vive | Quando dispara | Ação |
|---|------|-----------|----------------|------|
| 1 | `PreToolUse` | `.agents/hooks.json` | Antes de `edit`/`write`/`str_replace` | `scripts/pre-edit-check.sh` via `hook-dispatch.mjs` |
| 2 | `PostToolUse` | `.agents/hooks.json` | Depois de `edit`/`write`/`str_replace` | `scripts/post-edit-check.sh` via `hook-dispatch.mjs` |
| 3 | `UserPromptSubmit` | `.agents/hooks.json` | Ao enviar mensagem | Lembrete de skills no contexto |
| 4 | PreCommit | `.husky/pre-commit` | Antes de `git commit` | lint + check + gitleaks |
| 5 | PrePR | `.husky/pre-push` | Antes de `git push` | verify + security + OWASP + complexity |
| 6 | PreDeploy / PostDeploy | `.github/workflows/` | No pipeline de deploy | verify + security + smoke test |

**Localização:** a linha do bridge fica em `cordis.patch.yml`; a
configuração dos eventos fica em `.agents/hooks.json`.

**Eventos que o bridge suporta:** `SessionStart`, `UserPromptSubmit`,
`PreToolUse`, `PostToolUse`, `Stop`, `SubagentStart`, `SubagentStop`.
`PreCommit`, `PrePR`, `PreDeploy` e `PostDeploy` **não** são eventos do
bridge — por isso estão nos hooks de git e no CI.

**Contrato:** os hooks recebem o payload como **JSON no stdin**. Exit `2`
bloqueia; qualquer outro exit é não-bloqueante. Os checks deste kit são
guias, então `hook-dispatch.mjs` sempre sai com código 0.

**Regra:** hooks devem rodar rápido. Verificações longas (lint, testes,
scan de segurança) vão para os hooks de git ou para o CI.

---

## 7. Workflows CI/CD

### 7.1 — `ci.yml`

Pipeline a cada PR e push em `main`/`develop`.

```text
secrets-scan (gitleaks)
    ↓
verify (check + lint + test:coverage + build + audit)
    ↓
e2e (Playwright)
    ↓
quality-audit (owasp + complexity) [informativo]
    ↓
ci-success (gate final)
```

**Jobs bloqueantes:** `secrets-scan`, `verify`, `e2e`, `ci-success`.
**Job informativo:** `quality-audit` (não bloqueia merge).

### 7.2 — `release.yml`

Dispara em push de tag `v*.*.*` ou `workflow_dispatch`.

```text
build (check + lint + test + build)
    ↓
changelog (extrai seção do CHANGELOG.md)
    ↓
publish (cria GitHub Release com artefatos)
```

**Localização:** `.github/workflows/`

---

## 8. Testes

| # | Suíte | Ferramenta | Escopo | Threshold |
|---|-------|-----------|--------|-----------|
| 1 | Unit | Vitest | `src/**/*.test.ts`, `tests/unit/**` | 70% lines/functions, 60% branches |
| 2 | E2E | Playwright | `tests/e2e/**` | 100% dos testes passam |
| 3 | Mutation | Stryker | `src/lib/**`, `workers/src/**` | 60% mutantes mortos |

**Mocks compartilhados:** `tests/setup.ts`

Fornece:
- `mockDB()` — mock de D1.
- `mockKV()` — mock de KV.
- `mockR2()` — mock de R2.
- `mockAI()` — mock de Workers AI.
- `mockPlatform()` — env + context.
- `mockRequestEvent()` — evento SvelteKit.
- `formData()` — helper de FormData.
- `readJson()` — helper de parsing.

**Comandos:**

```bash
pnpm test              # unit
pnpm test:coverage     # unit + coverage
pnpm test:e2e          # e2e
pnpm test:mutation     # mutation
```

---

## 9. Documentação

| # | Arquivo | Propósito | Público |
|---|---------|-----------|---------|
| 1 | `README.md` | Visão geral + índice | Todos |
| 2 | `docs/SETUP.md` | Configuração do ambiente | Dev primeiro acesso |
| 3 | `docs/HARNESS.md` | Como funciona e como estender | Quem usa/avalia o harness |
| 4 | `docs/FEATURES.md` | Este arquivo — inventário | Auditoria, bootstrap |
| 5 | `AGENTS.md` | Regras operacionais do agente | O agente (e quem quer entender) |
| 6 | `CONVERSATION.md` | Histórico de decisões | Quem quer contexto |
| 7 | `CHANGELOG.md` | Mudanças por versão | Todos |
| 8 | `.agents/goals/current.md` | Template de goal | O agente (por tarefa) |
| 9 | `docs/DISTRIBUTION.md` | Como publicar e distribuir | Mantenedores |

**Hierarquia de consulta:**

```text
Primeira vez no projeto → README.md → docs/SETUP.md
Dúvida sobre harness    → docs/HARNESS.md
Dúvida sobre componente → docs/FEATURES.md
Dúvida sobre regra      → AGENTS.md
Dúvida sobre skill      → .agents/skills/<nome>/SKILL.md
```

---

## 10. Configuração

### 10.1 — Wrangler

| Arquivo | Ambiente | Deploy |
|---------|----------|--------|
| `wrangler.toml` | Dev local | `pnpm dev` |
| `wrangler.staging.toml` | Staging | `pnpm deploy:staging` |
| `wrangler.production.toml` | Produção | `pnpm deploy:prod` (após aprovação) |

**Bindings configurados:**
- `DB` → D1 (SQL)
- `CACHE` → KV (cache/config)
- `STORAGE` → R2 (objetos)
- `AI` → Workers AI (binding nativo)

### 10.2 — Outros arquivos de configuração

| Arquivo | Propósito |
|---------|-----------|
| `.gitleaks.toml` | Regras de detecção de secrets |
| `.env.example` | Template de variáveis (copiar para `.env`) |
| `.gitignore` | Arquivos ignorados pelo Git |
| `package.json` | Scripts e dependências |
| `tsconfig.json` | TypeScript strict |
| `svelte.config.js` | SvelteKit + adapter Cloudflare |
| `vite.config.ts` | Vite |
| `vitest.config.ts` | Vitest + coverage |
| `playwright.config.ts` | Playwright |
| `tests/mutation/stryker.config.mjs` | Stryker |

### 10.3 — Migrations

| Arquivo | O que faz |
|---------|-----------|
| `migrations/0001_init.sql` | users, sessions, audit_log, notifications, schema_info |
| `migrations/0002_add_uploaded_files.sql` | uploaded_files, file_shares, storage_usage + triggers |

**Regra:** migrations são imutáveis após aplicadas em produção.

---

## 11. Tabela: manter / adaptar / remover

Guia para bootstrap em novo projeto (não-SvelteKit ou não-Cloudflare).

### 11.1 — Manter 100% (universal)

| Componente | Motivo |
|------------|--------|
| `scripts/owasp-check.sh` | OWASP é universal |
| `scripts/complexity-check.sh` | Complexidade é universal |
| `scripts/security-scan.sh` | Estrutura genérica |
| `scripts/git-flow.sh` | Fluxo Git é universal |
| `.gitleaks.toml` | Gitleaks é universal |
| `.husky/pre-commit` | Estrutura genérica |
| Skill `owasp-top10` | Universal |
| Skill `security-leaks` | Universal |
| Skill `code-complexity` | Universal |
| Skill `git-flow` | Universal |
| Skill `agentic-code-review` | Universal |
| `harness.config.yml` | Estrutura genérica (ajustar paths) |
| `docs/*.md` | Estrutura genérica |
| `CHANGELOG.md` | Universal |
| `.agents/goals/current.md` | Template universal |

### 11.2 — Adaptar (mesma ideia, comandos diferentes)

| Componente | O que adaptar |
|------------|---------------|
| `AGENTS.md` | Stack, comandos, estrutura, code rules |
| `scripts/verify.sh` | Comandos de check/lint/test/build |
| `scripts/pre-edit-check.sh` | Cases por path |
| `scripts/post-edit-check.sh` | Comandos de verificação |
| `scripts/smoke-test.sh` | URLs e endpoints |
| `.github/workflows/ci.yml` | Setup (Node/pnpm → stack novo) |
| `.github/workflows/release.yml` | Empacotamento |
| `harness.config.yml` | `sandbox.allowed_write_paths` |
| `docs/SETUP.md` | Pré-requisitos, recursos |
| `docs/HARNESS.md` | Exemplos específicos do stack |

### 11.3 — Remover (específico deste stack)

| Componente | Motivo |
|------------|--------|
| `wrangler.toml`, `wrangler.staging.toml`, `wrangler.production.toml` | Cloudflare |
| Skills `cloudflare-d1`, `cloudflare-kv`, `cloudflare-r2`, `cloudflare-ai-gateway`, `cloudflare-security` | Cloudflare |
| Skills `sveltekit-runes`, `sveltekit-auth` | SvelteKit |
| `migrations/*.sql` (D1) | Cloudflare D1 |
| `svelte.config.js`, `vite.config.ts` | SvelteKit |
| `playwright.config.ts` com `wrangler pages dev` | Cloudflare |
| `vitest.config.ts` (adaptar) | Depende do stack |

### 11.4 — Adicionar (específico do novo stack)

Depende do destino. Exemplos:

| Novo stack | Skills a adicionar |
|------------|-------------------|
| Node + Express + PostgreSQL | `postgres-orm`, `express-middleware` |
| Python + FastAPI | `fastapi-async`, `pydantic-validation`, `sqlalchemy-orm` |
| Rust + Axum | `rust-ownership`, `axum-routing`, `sqlx-queries` |
| Go + Fiber | `go-concurrency`, `fiber-middleware` |
| Next.js + Vercel | `next-app-router`, `vercel-edge` |

---

## 12. Checklist de completude

Use este checklist para verificar que o kit está íntegro.

### 12.1 — Skills

- [ ] `.agents/skills/cloudflare-d1/SKILL.md`
- [ ] `.agents/skills/cloudflare-kv/SKILL.md`
- [ ] `.agents/skills/cloudflare-r2/SKILL.md`
- [ ] `.agents/skills/cloudflare-ai-gateway/SKILL.md`
- [ ] `.agents/skills/sveltekit-runes/SKILL.md`
- [ ] `.agents/skills/sveltekit-auth/SKILL.md`
- [ ] `.agents/skills/cloudflare-security/SKILL.md`
- [ ] `.agents/skills/owasp-top10/SKILL.md`
- [ ] `.agents/skills/security-leaks/SKILL.md`
- [ ] `.agents/skills/code-complexity/SKILL.md`
- [ ] `.agents/skills/git-flow/SKILL.md`
- [ ] `.agents/skills/agentic-code-review/SKILL.md`

### 12.2 — Scripts

- [ ] `scripts/verify.sh` (executável)
- [ ] `scripts/security-scan.sh` (executável)
- [ ] `scripts/owasp-check.sh` (executável)
- [ ] `scripts/complexity-check.sh` (executável)
- [ ] `scripts/smoke-test.sh` (executável)
- [ ] `scripts/pre-edit-check.sh` (executável)
- [ ] `scripts/post-edit-check.sh` (executável)
- [ ] `scripts/git-flow.sh` (executável)

### 12.3 — Configuração

- [ ] `AGENTS.md`
- [ ] `README.md`
- [ ] `CHANGELOG.md`
- [ ] `CONVERSATION.md`
- [ ] `harness.config.yml`
- [ ] `wrangler.toml` (com IDs reais)
- [ ] `wrangler.staging.toml` (com IDs reais)
- [ ] `wrangler.production.toml` (com IDs reais)
- [ ] `.gitleaks.toml`
- [ ] `.env.example`
- [ ] `.gitignore` (com `.env` na lista)
- [ ] `package.json`
- [ ] `tsconfig.json`
- [ ] `svelte.config.js`
- [ ] `vite.config.ts`
- [ ] `vitest.config.ts`
- [ ] `playwright.config.ts`

### 12.4 — Testes

- [ ] `tests/setup.ts`
- [ ] `tests/unit/example.test.ts`
- [ ] `tests/e2e/smoke.spec.ts`
- [ ] `tests/mutation/stryker.config.mjs`

### 12.5 — CI/CD

- [ ] `.github/workflows/ci.yml`
- [ ] `.github/workflows/release.yml`
- [ ] `.husky/pre-commit` (executável)

### 12.6 — Migrations

- [ ] `migrations/0001_init.sql`
- [ ] `migrations/0002_add_uploaded_files.sql`

### 12.7 — Documentação

- [ ] `docs/SETUP.md`
- [ ] `docs/HARNESS.md`
- [ ] `docs/FEATURES.md` (este arquivo)
- [ ] `.agents/goals/current.md`

### 12.8 — Verificação funcional

- [ ] `pnpm check` verde
- [ ] `pnpm lint` verde
- [ ] `pnpm test` verde
- [ ] `pnpm build` verde
- [ ] `pnpm test:e2e` verde
- [ ] `pnpm security:scan` verde
- [ ] `pnpm complexity:scan` verde
- [ ] `pnpm verify` verde (critério de conclusão)
- [ ] Pre-commit hook dispara em commit
- [ ] CI verde em PR
- [ ] `pnpm dev` inicia sem erro
- [ ] Bindings (DB, KV, R2, AI) acessíveis

### 12.9 — Integração DSH

- [ ] `harness.config.yml` copiado para `$DSH_HOME/projects/<nome>/`
- [ ] Sessão do DSH inicia dentro do projeto
- [ ] Agente responde perguntas sobre `AGENTS.md`
- [ ] Skill é carregada sob demanda (testado)
- [ ] Hook dispara em edição (testado)

---

## Como usar este documento

### Para auditoria
Percorra as seções 2–10 e confirme que cada componente existe no
projeto. Use o checklist da seção 12 para validação completa.

### Para bootstrap em novo projeto
1. Veja a tabela da seção 11.1 → copie o que é universal.
2. Veja a tabela da seção 11.2 → adapte os comandos.
3. Veja a tabela da seção 11.3 → remova o que não se aplica.
4. Veja a tabela da seção 11.4 → adicione o que falta.
5. Rode o checklist da seção 12.

### Para manutenção contínua
Sempre que adicionar/remover um componente:
1. Atualize a seção correspondente (2–10).
2. Atualize o resumo numérico (seção 1).
3. Atualize o checklist (seção 12).
4. Registre em `CHANGELOG.md`.

---

## Referências

- `README.md` — visão geral
- `docs/SETUP.md` — configuração do ambiente
- `docs/HARNESS.md` — arquitetura e extensão
- `AGENTS.md` — regras operacionais
- `CHANGELOG.md` — histórico de mudanças
