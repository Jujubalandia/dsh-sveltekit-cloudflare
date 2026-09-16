# DeepSeek Harness — SvelteKit + Cloudflare

Kit operacional completo para trabalhar com **DeepSeek Harness (DSH)**
em projetos **SvelteKit + TypeScript + Cloudflare** (Pages, Workers,
D1, KV, R2, AI Gateway), incorporando práticas de:

- **Addy Osmani** — *Practical Loop Engineering*, *Agentic Code Quality*,
  *The New SDLC with Vibe Coding*, *Agentic Code Review*
- **AkitaOnRails** — *Boas práticas para projetos open source com LLM*
- **flu-harness** — arquitetura de referência

---

## Começar aqui

Escolha conforme seu objetivo:

| Objetivo | Documento |
|----------|-----------|
| **Configurar o projeto pela primeira vez** | [`docs/SETUP.md`](docs/SETUP.md) |
| **Entender o harness de agentes** | [`docs/HARNESS.md`](docs/HARNESS.md) |
| **Ver inventário de componentes** | [`docs/FEATURES.md`](docs/FEATURES.md) |
| **Usar este kit em outro projeto** | [`docs/HARNESS.md#9-bootstrap-em-novo-projeto`](docs/HARNESS.md#9-bootstrap-em-novo-projeto) |
| **Entender as regras do agente** | [`AGENTS.md`](AGENTS.md) |
| **Ver as skills disponíveis** | [`.agents/skills/`](.agents/skills/) |
| **Ver os scripts de verificação** | [`scripts/`](scripts/) |
| **Publicar este kit para outros** | [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md) |
---

## O que é este kit

Um **harness** é a infraestrutura ao redor de um modelo de linguagem
que o transforma de "chatbot" em "agente que executa tarefas de
engenharia com segurança".

> "Agente = modelo + harness. O modelo é 10% do resultado; o harness
> é 90%." — Addy Osmani

Este kit fornece:

- **Regras operacionais** (`AGENTS.md`) — o que o agente pode e não pode fazer.
- **12 skills** (`.agents/skills/`) — contexto especializado carregado sob demanda.
- **5 subagentes** — drafter, verifier, judge, security auditor, complexity auditor.
- **Hooks automáticos** — verificações antes/depois de cada edição.
- **8 Security Gates** — bloqueiam ações inseguras.
- **Scripts determinísticos** — verify, security-scan, owasp-check, complexity-check, smoke-test.
- **CI completo** — gitleaks, testes, cobertura, build, audit.
- **Goal template** — critérios de aceitação versionados por tarefa.

---

## Estrutura do projeto

```text
.
├── AGENTS.md                       Regras operacionais do agente
├── README.md                       Este arquivo
├── CHANGELOG.md                    Changelog (Keep a Changelog)
├── CONVERSATION.md                 Histórico de decisões
├── harness.config.yml              Config do DSH (subagentes, hooks, sandbox)
├── docs/
│   ├── SETUP.md                    Como configurar o ambiente
│   └── HARNESS.md                  Como usar e estender o harness
│   ├── FEATURES.md                 Inventário de componentes
|   └── DISTRIBUTION.md             Como publicar e distribuir
├── .agents/
│   ├── goals/current.md            Template de goal por tarefa
│   └── skills/                     12 skills carregáveis
│       ├── cloudflare-d1/
│       ├── cloudflare-kv/
│       ├── cloudflare-r2/
│       ├── cloudflare-ai-gateway/
│       ├── sveltekit-runes/
│       ├── sveltekit-auth/
│       ├── cloudflare-security/
│       ├── owasp-top10/
│       ├── security-leaks/
│       ├── code-complexity/
│       ├── git-flow/
│       └── agentic-code-review/
├── scripts/
│   ├── verify.sh                   Pipeline completo
│   ├── security-scan.sh            Secrets + deps + OWASP + D1
│   ├── owasp-check.sh              OWASP Top 10 automatizado
│   ├── complexity-check.sh         Complexidade + duplicação + dead code
│   ├── smoke-test.sh               Pós-deploy
│   ├── pre-edit-check.sh           Hook: antes de editar
│   ├── post-edit-check.sh          Hook: depois de editar
│   └── git-flow.sh                 Fluxo Git guiado
├── wrangler.toml                   Config Cloudflare dev
├── wrangler.staging.toml           Config Cloudflare staging
├── wrangler.production.toml        Config Cloudflare produção
├── migrations/                     Migrations D1
├── tests/
│   ├── setup.ts                    Mocks de bindings
│   ├── unit/                       Testes unitários
│   ├── e2e/                        Testes end-to-end
│   └── mutation/                   Config Stryker
├── .github/workflows/
│   ├── ci.yml                      Pipeline CI
│   └── release.yml                 Release por tag
└── .husky/pre-commit               Hook de pre-commit
```

---

## Comandos principais

```bash
# Desenvolvimento
pnpm dev                            # Dev server :5173
pnpm build                          # Build produção

# Verificação
pnpm check                          # Type check
pnpm lint                           # ESLint + Prettier
pnpm test                           # Vitest
pnpm test:coverage                  # Vitest + coverage
pnpm test:e2e                       # Playwright
pnpm test:mutation                  # Stryker
pnpm verify                         # Pipeline completo

# Segurança
pnpm security:scan                  # gitleaks + audit + owasp + d1
pnpm owasp:check                    # OWASP Top 10
pnpm complexity:scan                # Complexidade + duplicação

# Git
pnpm git:flow start feat/nome       # Criar branch
pnpm git:flow commit "feat: ..."    # Commit com verificação
pnpm git:flow verify                # Verificar antes de push
pnpm git:flow pr                    # Abrir PR

# Cloudflare
pnpm d1:migrate:local               # Migrations local
pnpm d1:migrate:staging             # Migrations staging
pnpm deploy:staging                 # Deploy staging
pnpm deploy:prod                    # Deploy produção (requer aprovação)

# Smoke test
pnpm smoke staging                  # Smoke em staging
```

---

## Fluxo SDLC

Baseado em *The New SDLC with Vibe Coding* (Addy Osmani):

```text
1. Planning       → carregar skills, travar goals em .agents/goals/current.md
2. Implementation → drafter edita; hooks verificam antes/depois
3. Testing        → pnpm verify (check + lint + unit + build + e2e)
4. Security       → pnpm security:scan + pnpm complexity:scan
5. Verification   → subagente verifier confirma; judge decide
6. Review         → classificação por risco + revisão humana
7. Staging        → deploy + smoke
8. Approval       → aprovação humana obrigatória
9. Production     → deploy + observability + tail por 15 min
10. Retro         → registrar lição em $DSH_HOME/memory/
```

---

## Subagentes

Princípio: **"One sub-agent drafts the change. A separate one verifies it."**

| Subagente | Papel |
|-----------|-------|
| Drafter | Implementa a mudança |
| Verifier | Verifica independentemente (não confia no drafter) |
| Judge | Decide com base em evidências |
| Security Auditor | Roda OWASP + gitleaks |
| Complexity Auditor | Analisa complexidade e redundância |

Configurados em `harness.config.yml`, seção `subagents`.

---

## Security Gates

O agente **não pode** violar estas 8 regras:

1. **Secrets** — nunca hardcode. `wrangler secret put`. CI roda gitleaks.
2. **Input** — Zod em todo endpoint. CORS sem `*` em produção.
3. **D1** — prepared statements. Migrations versionadas.
4. **R2** — privado, signed URLs ≤15min, validar tipo/tamanho.
5. **AI Gateway** — Guardrails + rate limit + log com redaction.
6. **OWASP** — Top 10 verificado em `scripts/owasp-check.sh`.
7. **Prompt Injection** — input do usuário nunca vai direto para LLM.
8. **Deploy** — staging → smoke → aprovação → produção.

Detalhes completos em `AGENTS.md`, seção 5.

---

## Integração com DeepSeek Harness

Setup rápido (detalhes em `docs/HARNESS.md`):

```bash
# 1. Registrar o projeto no DSH
mkdir -p $DSH_HOME/projects/sveltekit-cloudflare
cp harness.config.yml $DSH_HOME/projects/sveltekit-cloudflare/

# 2. Iniciar uma sessão do DSH dentro do projeto
cd /caminho/do/projeto
dsh

# 3. Verificar que o harness carrega
#    Dentro da sessão: "Leia AGENTS.md e liste as Security Gates."
```

---

## Referências

### Artigos base

- Addy Osmani — *Practical Loop Engineering*
- Addy Osmani — *Agentic Code Quality*
- Addy Osmani — *The New SDLC with Vibe Coding*
- Addy Osmani — *Agentic Code Review*
- AkitaOnRails — *Boas práticas para projetos open source com LLM*

### Projetos

- flu-harness — github.com/Jujubalandia/flu-harness
- DeepSeek Harness — documentação oficial

### Documentação interna

- `docs/SETUP.md` — como configurar o ambiente
- `docs/HARNESS.md` — como usar e estender o harness
- `AGENTS.md` — regras operacionais do agente
- `CONVERSATION.md` — histórico de decisões
- `CHANGELOG.md` — mudanças por versão

### Stack

- SvelteKit — kit.svelte.dev
- Cloudflare Workers — developers.cloudflare.com/workers/
- Cloudflare D1 — developers.cloudflare.com/d1/
- Cloudflare KV — developers.cloudflare.com/kv/
- Cloudflare R2 — developers.cloudflare.com/r2/
- Cloudflare AI Gateway — developers.cloudflare.com/ai-gateway/

---

## Depois de instalar

Se você acabou de instalar o harness (via `dsh plugin add` ou via
template), faça esta verificação rápida nos primeiros 5 minutos.

### 1. Reinicie o DSH

```bash
dsh web
```

### 2. Verifique as skills

Dentro da sessão, pergunte:

```text
Liste as skills disponíveis no seu catálogo.
```

**Esperado:** as 12 skills do harness (`cloudflare-d1`, `cloudflare-kv`,
`cloudflare-r2`, `cloudflare-ai-gateway`, `sveltekit-runes`,
`sveltekit-auth`, `cloudflare-security`, `owasp-top10`,
`security-leaks`, `code-complexity`, `git-flow`,
`agentic-code-review`).

### 3. Verifique os comandos

Digite `/sveflare` no prompt e pressione Tab.

**Esperado:**

```
/sveflare-spec
/sveflare-plan
/sveflare-goal
/sveflare-verify
/sveflare-ship
```

### 4. Comece pelo comando certo

| Situação | Comando |
|----------|---------|
| Iniciar feature nova | `/sveflare-spec` |
| Converter spec aprovada em plano técnico | `/sveflare-plan` |
| Iniciar uma tarefa atômica | `/sveflare-goal` |
| Verificar antes de PR ou deploy | `/sveflare-verify` |
| Deployar para staging/produção | `/sveflare-ship` |

**Fluxo completo:**

```text
/sveflare-spec  →  docs/SPEC.md
       ↓
/sveflare-plan  →  docs/PLAN.md
       ↓
/sveflare-goal  →  .agents/goals/current.md  (por tarefa)
       ↓
(implementação com hooks automáticos)
       ↓
/sveflare-verify  →  relatório consolidado
       ↓
/sveflare-ship  →  deploy + monitoramento
```

### 5. Leia o guia de uso

- **Uso diário e fluxos completos:** [`docs/USAGE.md`](docs/USAGE.md)
- **Inventário de componentes:** [`docs/FEATURES.md`](docs/FEATURES.md)
- **Arquitetura e extensão:** [`docs/HARNESS.md`](docs/HARNESS.md)
- **Publicação e distribuição:** [`docs/DISTRIBUTION.md`](docs/DISTRIBUTION.md)

### Troubleshooting rápido

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| Nenhuma skill aparece | `SKILL.md` sem frontmatter YAML com `name` e `description` — o `@deepseek-ai/dsh-skill-filesystem`, montado pelo `dsh-base` com `includeDefaultRoots: true`, varre `.agents/skills` e ignora o arquivo | Adicionar o frontmatter no topo do `SKILL.md` (`name` precisa casar com `/^[a-z0-9]+(?:-[a-z0-9]+)*$/`) |
| Comandos `/sveflare-*` não aparecem | `cordis.patch.yml` sem a seção `sveflare-commands` | Reaplicar o `cordis.patch.yml` e reinstalar o bundle |
| Agente ignora o `AGENTS.md` | DSH iniciado fora do workspace | Sempre iniciar com `dsh web` de dentro do projeto |
| Hook não dispara | Scripts não executáveis | `chmod +x scripts/*.sh` |

Guia completo em [`docs/USAGE.md`, seção 10](docs/USAGE.md#10-troubleshooting).

---

## Licença

(Defina conforme o projeto — MIT, Apache 2.0, proprietária, etc.)
