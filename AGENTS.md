# AGENT.md — SvelteKit + Cloudflare + DeepSeek Harness

<!--
  Versão: 2.0.0
  Stack: SvelteKit 2 + Svelte 5 (runes) + TypeScript strict
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
- Deploy: Cloudflare Pages + Workers
- Bindings: D1 (SQL), KV (cache/config), R2 (objetos), AI Gateway (LLM proxy)
- Adapter: `@sveltejs/adapter-cloudflare`
- Testes: Vitest (unit/integration) + Playwright (e2e) + Stryker (mutation)

## 2. Comandos

| Comando | Propósito |
|---------|-----------|
| `pnpm install` | Instalar dependências |
| `pnpm dev` | Dev server :5173 |
| `pnpm build` | Build produção |
| `pnpm check` | Type check |
| `pnpm lint` | ESLint + Prettier |
| `pnpm test` | Vitest |
| `pnpm test:coverage` | Vitest + coverage |
| `pnpm test:e2e` | Playwright |
| `pnpm test:mutation` | Stryker mutation testing |
| `pnpm verify` | Pipeline completo |
| `pnpm security:scan` | Gitleaks + audit + OWASP + D1 |
| `pnpm complexity:scan` | Análise de complexidade e duplicação |
| `pnpm git:flow` | Fluxo Git guiado |
| `pnpm smoke staging` | Smoke test |

## 3. Estrutura
