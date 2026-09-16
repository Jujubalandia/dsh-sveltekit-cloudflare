# Changelog

Todas as mudanças notáveis deste projeto são documentadas neste arquivo.

Formato baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/).
Versionamento segue [SemVer](https://semver.org/lang/pt-BR/).

## [Unreleased]

### Added
- Subagentes verificadores (drafter, verifier, judge, security, complexity).
- OWASP Top 10 check automatizado em `scripts/owasp-check.sh`.
- Skill `security-leaks` cobrindo 7 tipos de vazamento.
- Análise de complexidade e redundância em `scripts/complexity-check.sh`.
- Skill `code-complexity` com thresholds e mutation testing.
- Skill `agentic-code-review` com camadas de revisão e red flags.
- Skill `git-flow` com Conventional Commits e fluxo de branches.
- Skill `owasp-top10` com checklist adaptado.
- Script `scripts/git-flow.sh` para fluxo Git guiado.
- Workflow `.github/workflows/release.yml` por tag.
- Config Stryker em `tests/mutation/stryker.config.mjs`.
- `CHANGELOG.md` seguindo Keep a Changelog.


#### Comandos e templates
- 5 comandos `/sveflare-*` para fluxo SDLC completo:
  - `/sveflare-spec` — especificação estruturada de feature
  - `/sveflare-plan` — plano técnico a partir da spec
  - `/sveflare-goal` — travamento de escopo de tarefa atômica
  - `/sveflare-verify` — pipeline completo de verificação
  - `/sveflare-ship` — validação + deploy + monitoramento
- 2 templates reutilizáveis:
  - `.agents/templates/SPEC.md` — base para `docs/SPEC.md`
  - `.agents/templates/PLAN.md` — base para `docs/PLAN.md`
- Registro de comandos no bundle: o plugin `lib/commands.mjs`, montado
  pela linha `- insert:` de id `sveflare-commands` em `cordis.patch.yml`,
  lê os prompts em `.agents/commands/*.md` e registra cada um via
  `ctx.commands.register()`.

#### Documentação
- `docs/USAGE.md` — guia de uso diário (fluxos, subagentes, FAQ,
  troubleshooting).
- `docs/DISTRIBUTION.md` — publicação como bundle DSH e como template
  GitHub.
- Seção `5.7 — commands` em `docs/HARNESS.md`.
- Seções `13 — Comandos` e `14 — Templates` em `docs/FEATURES.md`.
- Seções `3.6`, `3.7`, `3.8` em `docs/USAGE.md` (registro de comandos
  e troubleshooting).
- Seção "Depois de instalar" em `README.md`.

#### Distribuição
- `cordis.patch.yml` — bundle DSH unificado (skills + commands +
  subagents + hooks).
- Campos `dsh.bundle.patch` e `files` em `package.json`.
- Suporte a instalação via `dsh plugin --profile web add`.

#### Skills
- 12 skills carregáveis sob demanda (`cloudflare-d1`, `cloudflare-kv`,
  `cloudflare-r2`, `cloudflare-ai-gateway`, `sveltekit-runes`,
  `sveltekit-auth`, `cloudflare-security`, `owasp-top10`,
  `security-leaks`, `code-complexity`, `git-flow`,
  `agentic-code-review`).

#### Subagentes
- 5 subagentes especializados: `drafter`, `verifier`, `judge`,
  `security_auditor`, `complexity_auditor`.
- Princípio "um rascunha, outro verifica" aplicado em todos os fluxos.

#### Scripts
- 8 scripts de verificação determinística: `verify.sh`,
  `security-scan.sh`, `owasp-check.sh`, `complexity-check.sh`,
  `smoke-test.sh`, `pre-edit-check.sh`, `post-edit-check.sh`,
  `git-flow.sh`.

### Changed
- `AGENT.md` promovido para v2.0.0 com fluxo Git, subagentes e 8 Security Gates.
- `harness.config.yml` expandido com seção `subagents` e hooks Pre-PR.
- `README.md` reescrito com fluxo SDLC e tabela de subagentes.
- `.agents/goals/current.md` agora exige verificação independente.

- `README.md` — nova seção "Depois de instalar" com os 5 comandos e
  troubleshooting rápido.
- `docs/HARNESS.md` — nova seção `5.7 — commands` documentando o
  registro de comandos no bundle.
- `docs/FEATURES.md` — resumo numérico atualizado (Comandos: 5,
  Templates: 2) e novas seções `13` e `14`.
- `docs/USAGE.md` — expandido com `3.6`, `3.7` e `3.8` cobrindo o
  registro, verificação e troubleshooting dos comandos.
- `package.json` — adicionado `dsh.bundle.patch`, campo `files`
  delimitando o escopo do bundle, e keywords para descoberta.


### Security
- Adicionado Gate 7 (Prompt Injection).
- Adicionado check automatizado de CORS wildcard em produção.
- Adicionado check de tokens em localStorage.

## [1.0.0] - 2026-09-15

### Added
- `AGENT.md` v1 com regras operacionais básicas.
- `README.md` com setup e fluxo inicial.
- `harness.config.yml` com hooks e sandbox básicos.
- Configs Wrangler: dev, staging, produção.
- `package.json`, `tsconfig.json`, `svelte.config.js`, `vite.config.ts`.
- `vitest.config.ts` e `playwright.config.ts`.
- Skills: `cloudflare-d1`, `cloudflare-kv`, `cloudflare-r2`,
  `cloudflare-ai-gateway`, `sveltekit-runes`, `sveltekit-auth`,
  `cloudflare-security`.
- Scripts: `verify.sh`, `security-scan.sh`, `smoke-test.sh`,
  `pre-edit-check.sh`, `post-edit-check.sh`.
- CI em `.github/workflows/ci.yml` com gitleaks.
- Pre-commit hook em `.husky/pre-commit`.
- `.gitleaks.toml`, `.env.example`, `.gitignore`.
- Migração inicial `migrations/0001_init.sql`.
- Testes de exemplo (unit e e2e).
- `.agents/goals/current.md`.

### Security
- 6 Security Gates iniciais (secrets, input, D1, R2, AI Gateway, deploy).
- Gitleaks no pre-commit e no CI.
- `.env` no `.gitignore`.

---

Tipos de mudança usados neste changelog:

- `Added` — novas funcionalidades.
- `Changed` — mudanças em funcionalidades existentes.
- `Deprecated` — funcionalidades que serão removidas.
- `Removed` — funcionalidades removidas.
- `Fixed` — correções de bugs.
- `Security` — correções de vulnerabilidades.
