# Conversa: AGENT.md para SvelteKit + Cloudflare no DeepSeek Harness

Registro da conversa, decisões e evolução do pacote operacional para uso
com DeepSeek Harness neste stack.

## Objetivo inicial

Criar um guideline `AGENT.md` para projeto SvelteKit/TypeScript + Cloudflare
(Pages/Workers/D1/KV/R2/AI Gateway) para uso no DeepSeek Harness, com hooks,
skills, tools, goals verifications, code rules, security gates e step
verifications, inspirado em https://github.com/Jujubalandia/flu-harness.

## Conceitos-chave consolidados

- AGENT.md é contexto durável, não enforcement. Enforcement real = hooks +
  sandbox + approval gates + CI + allowlists.
- Hierarquia de autoridade: system -> user -> global AGENTS.md -> project root
  -> nested -> skill.
- SDLC em 6 fases: planning, implementation, testing, security, deploy, retro.
- Skills por domínio: d1, kv, r2, ai-gateway, runes, auth, security, owasp,
  leaks, complexity, git-flow, code-review.

## Estrutura do AGENT.md

1. Cabeçalho e versão
2. Stack e comandos
3. Estrutura de diretórios
4. Code rules (Svelte 5, TypeScript, Cloudflare)
5. Security gates (8 gates)
6. Fluxo Git (branches, commits, PR, release)
7. Subagentes (drafter, verifier, judge, security, complexity)
8. Hooks (pre/post execute, pre-commit, pre-PR, pre-deploy, post-deploy)
9. Step verification (14 etapas)
10. Goal verification
11. Skills
12. Regras críticas

## Artigos incorporados

### 1. AkitaOnRails — Boas práticas open source com LLM

Três pilares:
- Instalação fácil.
- CI confiável (testes, lint, build, release).
- Documentação escrita pelo problema que resolve, não pela feature.

Implicações:
- Padronização permite automação confiável.
- Release por tag, CHANGELOG, matriz de build.
- Checklist de contribuição claro.

### 2. Addy Osmani — Practical Loop Engineering

Modelo de loop: trigger -> task -> verification -> state.

Quatro tipos de loop:
- Manual: você dirige cada passo.
- Goal: `/goal <critério> stop after N tries`.
- Time-based: `/loop 5m check PR`.
- Proactive: `/schedule every 1h: triage issues`.

Regras:
- Critério de "done" precisa ser determinístico.
- Subagente separado verifica.
- Não delegar o julgamento, só a tarefa.

### 3. Addy Osmani — Agentic Code Quality

- Constraints como quality gates (lint, types, tests, coverage).
- Back-pressure ao longo do pipeline.
- Complexidade ciclomática e tamanho de arquivo como métricas.
- Mutation testing: "Coverage tells you a line ran, mutation testing tells
  you whether the test would notice if that line were wrong."
- Redundância e dead code são dívida silenciosa.

### 4. Addy Osmani — The New SDLC with Vibe Coding

- Agente = modelo + harness. O harness é 90% do resultado.
- Context engineering: contexto estático (AGENTS.md, skills) vs dinâmico
  (arquivos abertos, saída de ferramentas).
- Verification é a linha entre vibe coding e engenharia.
- Conductor (você dirige) vs orchestrator (delega e audita).

### 5. Addy Osmani — Agentic Code Review

- Review é o novo gargalo: 4x mais código para 12% mais valor.
- Human on the loop, não in the loop.
- Triagem por subagente + camadas de revisão por risco.
- Red flags em PRs de agentes:
  - Testes reescritos para passar.
  - CI enfraquecido.
  - Helper duplicado.
  - Input não confiável indo para LLM.
  - PR gigante sem intenção declarada.

## Processo de testes

### Unit / Integration (Vitest)

- `pnpm test` — suite completa.
- `pnpm test:coverage` — thresholds: 70% lines/functions, 60% branches.
- Mocks de bindings Cloudflare em `tests/setup.ts`.
- Testes em `src/**/*.test.ts` e `tests/unit/`.

### E2E (Playwright)

- `pnpm test:e2e` — sobe `wrangler pages dev` automaticamente.
- Contra staging: `PLAYWRIGHT_BASE_URL=https://... pnpm test:e2e`.
- Projetos: chromium + mobile (Pixel 7).
- Trace e screenshot em falhas.

### Mutation (Stryker)

- `pnpm test:mutation` — threshold 60% de mutantes mortos.
- Config em `tests/mutation/stryker.config.mjs`.
- Roda sobre `src/lib/**` e `workers/src/**`.

### CI (GitHub Actions)

Pipeline em `.github/workflows/ci.yml`:

```text
gitleaks -> check -> lint -> test:coverage -> build -> audit
```

- Coverage publicado como artifact.
- Bloqueia merge se falhar.

### Pre-commit (Husky)

```text
lint -> check -> gitleaks --staged
```

## Configuração Wrangler

### Arquivos

- `wrangler.toml` — dev local.
- `wrangler.staging.toml` — staging.
- `wrangler.production.toml` — produção (observability on).

### Bindings

- `DB` -> D1 (`d1_databases`).
- `CACHE` -> KV (`kv_namespaces`).
- `STORAGE` -> R2 (`r2_buckets`).
- `AI` -> Workers AI binding.
- `AI_GATEWAY_URL` em `[vars]`.

### Comandos

```bash
# Criar recursos
wrangler d1 create myapp-db-staging
wrangler kv namespace create CACHE --env staging
wrangler r2 bucket create myapp-storage-staging

# Migrations
wrangler d1 migrations create DB add_users
wrangler d1 migrations apply DB --local
wrangler d1 migrations apply DB --env staging
wrangler d1 migrations apply DB --env production

# Secrets
wrangler secret put SESSION_SECRET --env staging
wrangler secret put OPENAI_API_KEY --env staging
wrangler secret list --env staging

# Deploy
wrangler deploy --env staging
wrangler deploy --env production

# Observabilidade
wrangler tail --env production --format pretty
```

### AI Gateway

- URL: `https://gateway.ai.cloudflare.com/v1/<ACCOUNT>/<GATEWAY>/openai`
- Guardrails e rate limit configurados no dashboard.
- Metadata com `userId` em cada request.
- Logs com redaction de PII.

## O que foi adicionado na versão 2

| Área | Arquivo |
|------|---------|
| Fluxo Git | `.agents/skills/git-flow/SKILL.md`, `scripts/git-flow.sh` |
| Subagentes | `harness.config.yml` (seção subagents) |
| OWASP | `.agents/skills/owasp-top10/SKILL.md`, `scripts/owasp-check.sh` |
| Security leaks | `.agents/skills/security-leaks/SKILL.md` |
| Complexidade | `.agents/skills/code-complexity/SKILL.md`, `scripts/complexity-check.sh` |
| Mutation testing | `tests/mutation/stryker.config.mjs` |
| Code review | `.agents/skills/agentic-code-review/SKILL.md` |
| Release | `.github/workflows/release.yml` |
| Goals | `.agents/goals/current.md` (com subagentes) |
| Changelog | `CHANGELOG.md` |

## Checklist final antes do deploy

- [ ] `pnpm verify` verde
- [ ] `pnpm security:scan` verde
- [ ] `pnpm complexity:scan` verde
- [ ] Subagente verificador confirmou independentemente
- [ ] Migrations aplicadas em staging
- [ ] Smoke test staging OK
- [ ] Rollback plan documentado
- [ ] Aprovação humana registrada
- [ ] Observability habilitada em produção
- [ ] `wrangler tail` ativo por 15 minutos pós-deploy
