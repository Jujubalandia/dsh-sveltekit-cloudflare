<!--
  TEMPLATE — PLAN.md

  Este template é a base para `docs/PLAN.md` gerado pelo comando
  `/sveflare-plan`.

  Como usar:
  1. Copie este arquivo para `docs/PLAN.md`.
  2. Substitua todos os `<placeholders>`.
  3. Remova os comentários HTML (<!-- ... -->) após preencher.
  4. Rode `/sveflare-plan` se preferir que o agente preencha
     automaticamente (a partir de um `docs/SPEC.md`).

  Regras:
  - Foco em COMO (não em o quê).
  - Cada critério de aceitação do SPEC deve aparecer em pelo menos
    uma tarefa.
  - Cada endpoint deve mapear para pelo menos um critério.
  - Cada tarefa deve ser verificável em 1-2h.
  - Não invente dependências que não estão no package.json.
-->

# PLAN — <nome da feature>

**ID:** PLAN-<NNN>
**Versão:** 1.0
**Data:** <YYYY-MM-DD>
**Autor:** <nome ou sessão DSH>
**Spec de origem:** `docs/SPEC.md` (versão <N>)
**Status:** `rascunho` <!-- rascunho | em-revisão | aprovado | obsoleto -->
**Aprovado em:** <YYYY-MM-DD>
**Aprovado por:** <nome>

---

## 1. Resumo executivo

<!--
  3-5 linhas descrevendo:
  - O que será construído
  - Principais decisões técnicas
  - Impacto estimado (arquivos, migrations, endpoints)
  - Blast radius
-->

<Linha 1: feature e abordagem técnica em 1 frase.>

<Linha 2: principais decisões (ex: "novo endpoint + nova tabela + componente UI").>

<Linha 3: números concretos (N endpoints, N tabelas, N arquivos).>

<Linha 4: blast radius (baixo/médio/alto) e justificativa curta.>

<Linha 5: riscos principais e como serão mitigados.>

---

## 2. Schema D1

<!--
  Se a feature requer mudanças no banco:
  - Tabelas novas
  - Alterações em tabelas existentes
  - Estratégia de migração

  Se não houver mudanças, escreva "Não aplicável."
-->

### 2.1 — Tabelas novas

```sql
-- migrations/000N_<nome>.sql
CREATE TABLE IF NOT EXISTS <tabela> (
  id         TEXT PRIMARY KEY,
  <campo>    <tipo> NOT NULL <constraints>,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (<campo>) REFERENCES <outra_tabela>(id) ON DELETE <ação>
);

CREATE INDEX IF NOT EXISTS idx_<tabela>_<campo> ON <tabela> (<campo>);
```

**Justificativa:**
- <por que esta tabela é necessária>
- <por que estes índices>
- <por que estas foreign keys e on delete>

### 2.2 — Alterações em tabelas existentes

```sql
-- migrations/000N_<nome>.sql
ALTER TABLE <tabela> ADD COLUMN <campo> <tipo> <constraints>;
```

**Justificativa:**
- <por que a alteração>
- <impacto em dados existentes>
- <necessidade de backfill>

Se não houver alterações, escreva:

> Nenhuma.

### 2.3 — Estratégia de migração

**Downtime esperado:** <nenhum | <X> segundos | requer manutenção>

**Dados a migrar:**
- <se há dados existentes que precisam ser transformados>
- <volume estimado>

**Ordem de aplicação:**
1. Aplicar migration em staging
2. Validar com smoke test
3. Aplicar em produção
4. Verificar dados

**Rollback:**
```sql
-- migrations/000N+1_<nome>_rollback.sql
DROP TABLE IF EXISTS <tabela>;
-- ou
ALTER TABLE <tabela> DROP COLUMN <campo>;
```

**Nota:** <se a migration é irreversível, documente o motivo e o
plano de backup>

---

## 3. Contratos de API

<!--
  Para cada endpoint novo ou alterado:

  - Método e caminho
  - Request (body, query, headers)
  - Response (sucesso e erros)
  - Regras aplicáveis (quais CAs do SPEC)
  - Segurança (quais gates aplicam)

  Se a feature não tiver endpoints, escreva "Não aplicável."
-->

### 3.1 — `METHOD /path/<endpoint>`

**Propósito:** <1 frase>

**Autenticação:** <público | autenticado | role X>

**Request:**

```ts
// Body (Zod schema)
const BodySchema = z.object({
  <campo>: z.string().min(1).max(255),
  <campo>: z.number().int().positive().optional()
});

// Query params
// ?limit=10&cursor=xxx

// Headers
// Content-Type: application/json
// Authorization: Bearer <token>  (se autenticado)
```

**Response:**

```ts
// 200 OK
{
  <campo>: <tipo>,
  ...
}

// 400 Bad Request — validação falhou
{
  error: string,
  fields?: string[]
}

// 401 Unauthorized — não autenticado
{
  error: "Unauthorized"
}

// 403 Forbidden — autenticado mas sem permissão
{
  error: "Forbidden"
}

// 404 Not Found — recurso não existe
{
  error: "Not found"
}

// 429 Too Many Requests — rate limit
{
  error: "Too many requests"
}

// 500 Internal Server Error — erro genérico (sem detalhes)
{
  error: "Internal error"
}
```

**Regras aplicáveis (do SPEC):**
- CA-1 (validação de tipo)
- CA-3 (limite de tamanho)

**Segurança:**
- Gate 2: validação Zod no body
- Gate 3: prepared statements em D1
- Gate 4: signed URL para download (se aplicável)

**Rate limit:** <N> req/min por <identificador>

### 3.2 — `METHOD /path/<endpoint>`

<...>

Se não houver endpoints, escreva:

> Não aplicável. Esta feature é <puramente UI | refatoração interna
> | etc.>

---

## 4. Estrutura de arquivos

<!--
  Árvore de arquivos a criar/modificar. Cada arquivo com um
  comentário de 1 linha explicando o propósito.
-->

```text
src/
├── routes/
│   └── api/<feature>/
│       ├── +server.ts              # GET (list), POST (create)
│       └── [id]/
│           └── +server.ts          # GET, PATCH, DELETE
│   └── (app)/<feature>/
│       ├── +page.server.ts         # load + form actions
│       └── +page.svelte            # UI
├── lib/
│   ├── components/<feature>/
│   │   ├── <Component>.svelte      # <propósito>
│   │   └── <Component>.test.ts     # testes do componente
│   └── server/<feature>/
│       ├── db.ts                   # queries D1
│       ├── validation.ts           # schemas Zod
│       └── <outros>.ts             # <propósito>

workers/src/
└── <feature>/
    └── <arquivo>.ts                # <propósito>

migrations/
└── 000N_<nome>.sql                 # schema D1

tests/
├── unit/
│   └── <feature>.test.ts           # testes unitários
└── e2e/
    └── <feature>.spec.ts           # testes end-to-end
```

**Arquivos a modificar:**
- `<arquivo>` — <o que muda>

**Arquivos a criar:**
- `<arquivo>` — <propósito>

---

## 5. Componentes de UI

<!--
  Se a feature tem UI:
  - Liste componentes
  - Descreva estado (runes)
  - Descreva fonte de dados (load)

  Se não houver UI, escreva "Não aplicável."
-->

### 5.1 — Componentes

| Componente | Caminho | Propósito |
|------------|---------|-----------|
| `<Nome>` | `src/lib/components/<feature>/<Nome>.svelte` | <propósito> |
| `<Nome>` | `src/lib/components/<feature>/<Nome>.svelte` | <propósito> |

### 5.2 — Estado (Svelte 5 runes)

```svelte
<script lang="ts">
  let { items, onSelect }: Props = $props();

  let selected = $state<string | null>(null);
  let filtered = $derived(items.filter((i) => i.active));

  $effect(() => {
    // side effect real (DOM, subscription)
  });
</script>
```

**Regras:**
- Apenas runes (`$state`, `$derived`, `$props`, `$effect`).
- Nenhum `export let`, `$:`, store legada.
- `$effect` só para side effects reais.

### 5.3 — Fonte de dados

Os dados vêm de `+page.server.ts` (load function):

```ts
export const load: PageServerLoad = async ({ locals, platform }) => {
  const items = await getItems(platform!.env.DB, locals.user!.id);
  return { items };
};
```

**Regras:**
- Dados via `load`, nunca `fetch` em `onMount`.
- Mutações via form actions com `use:enhance`.

---

## 6. Tarefas atômicas

<!--
  Cada tarefa:
  - Verificável em 1-2h
  - Tem artefato concreto
  - Tem critérios de verificação (comando ou inspeção)
  - Tem dependências explícitas

  Mínimo 3, ideal 6-12.

  Mapeie cada critério de aceitação do SPEC para pelo menos uma
  tarefa (via tag [CA-N]).
-->

### Tarefa 1 — <título>

**Objetivo:** <1 frase>

**Cobre:** CA-1, CA-2

**Dependências:** nenhuma

**Artefatos:**
- `migrations/000N_<nome>.sql` — schema D1
- `src/lib/server/<feature>/db.ts` — queries
- `tests/unit/<feature>.test.ts` — testes das queries

**Passos:**
1. Criar migration com tabela `<nome>`.
2. Aplicar localmente (`pnpm d1:migrate:local`).
3. Implementar funções de acesso em `db.ts`.
4. Escrever testes unitários.
5. Rodar `pnpm test`.

**Critérios de verificação:**
- [ ] `pnpm d1:migrate:local` sem erro
- [ ] `pnpm test` verde para os testes de `<feature>`
- [ ] `pnpm check` sem erros

**Estimativa:** 1h

---

### Tarefa 2 — <título>

**Objetivo:** <1 frase>

**Cobre:** CA-3, CA-4

**Dependências:** Tarefa 1

**Artefatos:**
- `src/routes/api/<feature>/+server.ts` — endpoint POST
- `src/lib/server/<feature>/validation.ts` — schema Zod

**Passos:**
1. Criar schema Zod em `validation.ts`.
2. Implementar handler em `+server.ts`.
3. Aplicar rate limit.
4. Testar manualmente com curl.

**Critérios de verificação:**
- [ ] `curl` retorna 201 com payload válido
- [ ] `curl` retorna 400 com payload inválido
- [ ] `curl` retorna 401 sem autenticação
- [ ] `pnpm security:scan` verde

**Estimativa:** 2h

---

### Tarefa 3 — <título>

<...>

**Estimativa:** <X>h

---

<!--
  Continue até cobrir todas as tarefas.
-->

### Resumo de tarefas

| # | Tarefa | Cobre | Dependências | Estimativa |
|---|--------|-------|--------------|------------|
| 1 | <título> | CA-1, CA-2 | — | 1h |
| 2 | <título> | CA-3, CA-4 | T1 | 2h |
| 3 | <título> | CA-5 | T1, T2 | 1h30 |
| 4 | <título> | CA-6, CA-7 | T2 | 2h |

**Estimativa total:** <X>h (~<Y> dias úteis)

---

## 7. Testes planejados

### 7.1 — Unit (Vitest)

| Arquivo | Cobre | Casos |
|---------|-------|-------|
| `src/lib/server/<feature>/db.test.ts` | Funções de acesso a dados | insert, get, list, delete |
| `src/lib/server/<feature>/validation.test.ts` | Schemas Zod | válido, inválido, edge cases |

**Cobertura alvo:** ≥70% nos arquivos novos.

### 7.2 — E2E (Playwright)

| Cenário | Arquivo | O que valida |
|---------|---------|--------------|
| <descrição> | `tests/e2e/<feature>.spec.ts` | CA-1, CA-2 |
| <descrição> | `tests/e2e/<feature>.spec.ts` | CA-3, CA-4 |

### 7.3 — Mutation (Stryker) — opcional

Se a feature toca módulo crítico (auth, pagamento, criptografia):

| Módulo | Motivo |
|--------|--------|
| `<módulo>` | <por que é crítico> |

**Mutation score alvo:** ≥60%

---

## 8. Riscos técnicos

<!--
  Tabela com: risco, probabilidade, impacto, mitigação.

  Probabilidade: baixa / média / alta
  Impacto: baixo / médio / alto
-->

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| <descrição> | baixa | médio | <ação> |
| <descrição> | média | alto | <ação> |
| <descrição> | alta | baixo | <ação> |

**Riscos aceitos:**

<!--
  Riscos que você decidiu NÃO mitigar, com justificativa.
-->

- **<risco>**: <justificativa para aceitar>

---

## 9. Impacto em segurança

<!--
  Para cada Security Gate do AGENTS.md que APLICA, diga como o plano
  atende.
-->

### Gate 1 — Secrets

**Aplica:** sim / não

**Como será atendido:**
- Nenhum secret hardcoded. Uso de `wrangler secret put` para valores sensíveis.
- `gitleaks` roda no pre-commit e no CI.

### Gate 2 — Input (Zod)

**Aplica:** sim

**Como será atendido:**
- Schemas Zod em `src/lib/server/<feature>/validation.ts`.
- Validação no início de cada `+server.ts` e form action.
- Rejeição de payloads que não batem com o schema.

### Gate 3 — D1 (prepared statements)

**Aplica:** sim

**Como será atendido:**
- Todas as queries usam `.prepare(...).bind(...)`.
- Nenhuma concatenação de string em SQL.
- Migrations versionadas.

### Gate 4 — R2

**Aplica:** <sim/não>

**Como será atendido:**
- <se aplicável>

### Gate 5 — AI Gateway

**Aplica:** <sim/não>

**Como será atendido:**
- <se aplicável>

### Gate 6 — OWASP Top 10

**Aplica:** sim

**Como será atendido:**
- `scripts/owasp-check.sh` roda em pre-PR.
- A01: guards server-side.
- A02: cookies httpOnly.
- A03: prepared statements + Zod.
- A07: sessão com expiração.
- A09: sem PII em logs.

### Gate 7 — Prompt Injection

**Aplica:** <sim/não>

**Como será atendido:**
- <se aplicável>

### Gate 8 — Deploy

**Aplica:** sim

**Como será atendido:**
- Staging antes de produção.
- Smoke test em staging.
- Aprovação humana explícita.
- Monitoramento 15 min pós-deploy.

---

## 10. Rollback

<!--
  Como reverter se algo der errado.
-->

### Rollback de deploy

```bash
# Se o deploy em produção falhar:
wrangler rollback --env production

# Se staging também falhar:
wrangler rollback --env staging
```

**Tempo estimado:** <1-2 min>

### Rollback de migration

```sql
-- migrations/000N+1_<nome>_rollback.sql
<SQL de rollback>
```

**Nota:** <se a migration é irreversível, documente o procedimento
alternativo (restaurar backup, etc.)>

### Rollback de código

```bash
git revert <commit-hash>
git push origin main
# Redeploy via pipeline
```

### Plano de contingência

Se o rollback automático falhar:

1. <passo 1>
2. <passo 2>
3. <passo 3>

**Contato de emergência:** <nome/slack>

---

## 11. Estimativa de blast radius

<!--
  Baixo: mudança isolada, sem impacto em outras features.
  Médio: afeta 1-2 features adjacentes, mas com impacto contido.
  Alto: afeta múltiplas features, dados de produção, ou usuários
        em massa.
-->

**Blast radius:** <baixo | médio | alto>

**Justificativa:**
- <razão 1>
- <razão 2>

**Mitigação do blast radius:**
- Feature flag: <sim/não> — <se sim, como>
- Rollout gradual: <sim/não> — <se sim, percentual>
- Canary deploy: <sim/não>

---

## Aprovação

<!--
  Preenchido ao aprovar o PLAN.
-->

**Revisado por:** <nome / subagente Complexity Auditor>
**Data de revisão:** <YYYY-MM-DD>
**Problemas encontrados:** <N>
**BLOQUEANTES resolvidos:** <N>
**Status final:** `aprovado`

**Próximo passo:**
1. Responder às questões em aberto (se houver).
2. Iniciar a primeira tarefa: `/sveflare-goal <título da Tarefa 1>`

---

## Histórico de versões

| Versão | Data | Autor | Mudanças |
|--------|------|-------|----------|
| 1.0 | <YYYY-MM-DD> | <autor> | Versão inicial |
| 1.1 | <YYYY-MM-DD> | <autor> | <mudanças> |

---

<!--
  CHECKLIST FINAL antes de marcar como `aprovado`:

  - [ ] Resumo executivo em 3-5 linhas.
  - [ ] Schema D1 documentado (ou "não aplicável").
  - [ ] Migration com rollback.
  - [ ] Cada endpoint tem request/response documentados.
  - [ ] Cada endpoint mapeia para pelo menos 1 CA do SPEC.
  - [ ] Estrutura de arquivos clara.
  - [ ] Componentes de UI descritos (ou "não aplicável").
  - [ ] Pelo menos 3 tarefas atômicas (ideal 6-12).
  - [ ] Cada CA do SPEC aparece em pelo menos 1 tarefa.
  - [ ] Cada tarefa é verificável em 1-2h.
  - [ ] Testes planejados (unit + e2e).
  - [ ] Riscos com probabilidade e impacto.
  - [ ] 8 Security Gates analisados.
  - [ ] Rollback documentado para deploy + migration + código.
  - [ ] Blast radius estimado.
  - [ ] Nenhum placeholder <...> restante.
  - [ ] Nenhuma decisão de implementação deixada em aberto.
-->
