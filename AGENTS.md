# AGENT.md: SvelteKit + Cloudflare + DeepSeek Harness

<!--
  Versão: 3.0.0
  Stack: SvelteKit 2 + Svelte 5 (runes) + TypeScript strict + Tailwind v4 + shadcn-svelte
  Deploy: Cloudflare Pages + Workers
  Bindings: D1, KV, R2, AI Gateway
  Harness: DeepSeek Harness (DSH)
  Inspirado em: flu-harness, Addy Osmani (Loop Engineering, Agentic Code Quality,
  Agentic Code Review, New SDLC), AkitaOnRails (open source com LLM)
-->

Regras operacionais para agentes de IA (DeepSeek Harness) neste repositório.
Leia integralmente antes de qualquer modificação.

## 1. Stack

- Framework: SvelteKit 2 + Svelte 5 (runes)
- Linguagem: TypeScript strict (`noUncheckedIndexedAccess`, `noImplicitOverride`)
- UI: **Tailwind CSS v4** (via `@tailwindcss/vite`) + **shadcn-svelte** (Bits UI 2)
- Deploy: Cloudflare Pages + Workers
- Bindings: D1 (SQL), KV (cache/config), R2 (objetos), AI Gateway (LLM proxy)
- Adapter: `@sveltejs/adapter-cloudflare`
- Testes: Vitest (unit/integration) + Playwright (e2e) + Stryker (mutation)

**Não existe `tailwind.config.js` nem `postcss.config.js`.** O Tailwind v4 se
configura no CSS (`src/app.css`), e o tema do shadcn vive nos tokens de lá.

## 2. Comandos

| Comando | Propósito |
|---------|-----------|
| `pnpm install` | Instalar dependências |
| `pnpm dev` | Dev server :5173 |
| `pnpm build` | Build produção |
| `pnpm check` | Type check (svelte-check) |
| `pnpm lint` | Prettier + ESLint |
| `pnpm format` | Formatar |
| `pnpm test` | Vitest |
| `pnpm test:coverage` | Vitest + coverage |
| `pnpm test:e2e` | Playwright (contra o build) |
| `pnpm test:mutation` | Stryker |
| `pnpm ui:add <componente>` | Adicionar componente shadcn |
| `pnpm ui:init` | Reinicializar o shadcn (cuidado: reescreve `app.css`) |
| `pnpm verify` | Pipeline completo |
| `pnpm security:scan` | Gitleaks + audit + OWASP + D1 + Gate 9 |
| `pnpm complexity:scan` | Complexidade e duplicação |
| `pnpm git:flow` | Fluxo Git guiado |
| `pnpm smoke staging` | Smoke test |

## 3. Estrutura

```text
.agents/
  skills/         13 skills (SKILL.md com frontmatter name+description)
  commands/       5 comandos /sveflare-*
  goals/          goal ativo da tarefa
  templates/      SPEC.md, PLAN.md, GOAL.md
  hooks.json      hooks do bridge do DSH
components.json   config do CLI do shadcn-svelte
_headers          headers HTTP para o Cloudflare Pages (o adapter exige na RAIZ)
src/
  app.html        shell HTML + script anti-FOUC do tema
  app.css         tokens Tailwind v4 + shadcn (oklch), :root/.dark/@theme inline
  hooks.server.ts headers de segurança aplicados pelo Worker (espelha _headers)
  routes/
    +layout.svelte    importa app.css, ModeWatcher, Toaster, ThemeToggle
    +page.svelte      página de prova dos 8 componentes
    api/health/       GET /api/health
  lib/
    utils.ts          export { cn } from 'cn'
    validation.ts     schemas Zod (Gate 2)
    components/
      theme-toggle.svelte
      ui/              8 componentes gerados pelo CLI (vendorizado)
workers/          Worker entry e bindings
migrations/       migrations D1
tests/            unit, e2e, setup
scripts/          verificação (8 .sh + hook-dispatch.mjs + validate-kit.mjs)
docs/             SETUP, HARNESS, FEATURES, USAGE, DISTRIBUTION
wrangler*.toml    configs Cloudflare (local, staging, produção)
```

### Aliases

`$lib` é nativo do SvelteKit e é o que o código gerado pelo shadcn usa
(`$lib/utils.js`, `$lib/components/ui/button/index.js`). O kit também tem
`$components`, `$utils`, `$server` e `$workers`, que apontam para os mesmos
lugares. Ao importar, prefira o caminho que o arquivo já usa.

**Nunca crie `src/lib/utils/` (diretório):** o alias `$utils` aponta para
`src/lib/utils` e competiria com `src/lib/utils.ts`.

## 4. Code Rules

- Svelte 5 runes apenas: `$state`, `$derived`, `$effect`, `$props`, `$bindable`.
  Proibido `export let`, `$:` e stores legadas em código novo.
- TypeScript strict: nada de `any` implícito, `as` para calar erro ou `!` sem
  justificativa.
- Input do usuário passa por **Zod** (`src/lib/validation.ts`), nunca por cast.
- Componentes de UI vêm do shadcn via CLI (`pnpm ui:add`). **Não edite
  `src/lib/components/ui/**` à mão** — é código regenerável.
- Regra de negócio não mora em `ui/`. Vai em `$lib/server` ou `$lib/`.
- Acessibilidade vem do Bits UI. Não reimplemente foco, teclado ou ARIA.
- Dark mode tem uma fonte de verdade só: `mode-watcher`, chave
  `mode-watcher-mode` no `localStorage`.

## 5. Security Gates (9)

| # | Gate | Regra | Onde é aplicado |
|---|------|-------|-----------------|
| 1 | Secrets | Nunca hardcode. Use `wrangler secret put`. | gitleaks (pre-commit + CI) |
| 2 | Input | Zod em toda entrada; CORS sem `*` em prod | `src/lib/validation.ts`, OWASP A03/A05 |
| 3 | D1 | Prepared statements; migrations versionadas | `owasp-check`, review |
| 4 | R2 | Bucket privado, signed URL ≤15min, validar tipo/tamanho | `owasp-check`, review |
| 5 | AI Gateway | Guardrails + rate limit + log com redaction | `owasp-check`, review |
| 6 | OWASP | Top 10 verificado | `scripts/owasp-check.sh` |
| 7 | Prompt Injection | Input sanitizado antes do LLM | `owasp-check` A03 |
| 8 | Deploy | Staging → smoke → aprovação → produção | `.github/workflows/`, environment protegido |
| 9 | Supply chain de UI | CLI pinado, registry oficial, diff de `ui/` revisado | `scripts/security-scan.sh`, review |

**Gate 9 em detalhe.** O `shadcn-svelte add` baixa **código executável** de um
registry remoto e escreve em `src/lib/components/ui/`. Portanto:

1. `shadcn-svelte` fica em **versão fixa** (nunca `latest`).
2. `components.json.registry` aponta para `https://shadcn-svelte.com/registry`.
   Trocar exige revisão explícita.
3. Todo `add` entra por PR com o diff de `ui/` lido.
4. `--overwrite` (`-o`) só com intenção.
5. Componente copiado de blog/GitHub passa pelo mesmo review.

## 6. O que é vendorizado

`src/lib/components/ui/**` é gerado pelo CLI e regenerável. Por isso fica
**fora** de: ESLint, Prettier, cobertura, knip, jscpd e complexidade.

Mas continua **dentro** de: `svelte-check`, testes e2e e varredura de segurança.
O código roda no browser do usuário; não ser linted não significa não ser
revisado.

## 7. Regras Críticas

1. **Nunca reescreva um teste para passar.** Corrija o código, não o teste.
2. **Nunca enfraqueça CI** (remover lint, baixar cobertura, pular gate).
3. **Nunca comite `.env`.** Só `.env.example` é versionado.
4. **Nunca declare uma tarefa concluída sem evidência** (comando + saída).
5. **Peça confirmação antes de** deploy em produção, migration destrutiva ou
   `git push --force`.
6. **Não troque `components.json.baseColor`** sem recriar o tema: os tokens do
   `app.css` foram gerados para ela.
7. **Não introduza `"latest"`** em `package.json`. O CLI do shadcn escreve isso
   ao adicionar dependências; re-pine.

## 8. Antes de finalizar

```bash
pnpm check          # 0 erros
pnpm lint           # limpo
pnpm test:coverage  # passa os thresholds
pnpm build          # gera .svelte-kit/cloudflare
node scripts/validate-kit.mjs   # 13 skills, 8/8 componentes
```

Se mexeu em UI, rode também `pnpm test:e2e` (cobre os 8 componentes).
