---
name: sveflare-plan
description: Converte uma spec aprovada (docs/SPEC.md) em plano técnico (docs/PLAN.md) com schema D1, contratos de API, estrutura de pastas e tarefas atômicas. Revisa com Complexity Auditor.
argument-hint: [opcional] caminho da spec, se não for docs/SPEC.md
allowed-tools: read, write, edit, grep, bash
model: deepseek-reasoner
---

# /sveflare-plan — Plano técnico a partir de uma spec

Você está convertendo uma especificação aprovada em um plano técnico
acionável. O objetivo é produzir `docs/PLAN.md` — um documento que
qualquer engenheiro (humano ou agente) possa seguir passo a passo sem
tomar decisões arquiteturais não autorizadas.

## Pré-requisitos

Antes de prosseguir, confirme:

1. `docs/SPEC.md` existe e foi aprovado pelo usuário.
2. O usuário respondeu às questões em aberto do SPEC.
3. Não há `/sveflare-plan` em andamento para a mesma spec.

Se qualquer pré-requisito falhar, **pare** e informe o usuário.

## Argumento recebido

O usuário pode opcionalmente apontar para uma spec alternativa:

```
$ARGUMENTS
```

Se vazio, use `docs/SPEC.md` como padrão.

## Restrições desta sessão

- NÃO escreva código de implementação (endpoints, componentes,
  migrations finais).
- NÃO execute migrations nem comandos que tocam banco de dados.
- NÃO altere arquivos fora de `docs/`, `migrations/` (rascunho) e
  `.agents/goals/`.
- NÃO decida bibliotecas ou frameworks além do que já está no projeto.
- Peça aprovação explícita antes de qualquer transição de fase.
- Se a spec estiver incompleta, **volte para `/sveflare-spec`** em vez
  de inventar o que falta.

## Fluxo de execução

### Passo 1 — Preparação

1. Leia `docs/SPEC.md` integralmente.
2. Leia `AGENTS.md` para relembrar:
   - Code Rules (seção 4).
   - Security Gates (seção 5).
   - Step Verification (seção 9).
3. Leia o estado atual do projeto:
   - Estrutura de `src/routes/` e `workers/src/`.
   - `migrations/` existentes (para saber o que já está no schema).
   - `package.json` (dependências disponíveis).
4. Identifique as skills relevantes para **as decisões técnicas**
   desta spec. Carregue no máximo 3:
   - Schema/D1 → `cloudflare-d1`
   - Endpoints/auth → `sveltekit-auth`
   - Upload/arquivos → `cloudflare-r2`
   - Cache/config → `cloudflare-kv`
   - IA → `cloudflare-ai-gateway`
   - Componentes → `sveltekit-runes`
   - Complexidade → `code-complexity`
5. Reporte ao usuário quais skills você carregou e por quê.

### Passo 2 — Drafter gera o plano

Invoque o subagente **Drafter** com o seguinte prompt:

```text
Você é um arquiteto de software sênior. Converta a especificação
abaixo em um plano técnico acionável (`docs/PLAN.md`) para o stack
SvelteKit + Cloudflare.

SPEC:
<cole aqui o conteúdo de docs/SPEC.md>

CONTEXTO DO PROJETO:
- Stack: SvelteKit 2 + Svelte 5 + TypeScript strict
- Runtime: Cloudflare Workers (via @sveltejs/adapter-cloudflare)
- Bindings: D1 (SQL), KV (cache), R2 (objetos), AI Gateway
- Regras: ver AGENTS.md
- Skills carregadas: [liste]

ESTRUTURA OBRIGATÓRIA DO PLAN.md:

# PLAN — <nome da feature>

## 1. Resumo executivo
<3-5 linhas: o que será construído, principais decisões técnicas,
impacto estimado em arquivos/migrations.>

## 2. Schema D1
<Se a feature requer mudanças no banco:>

### Tabelas novas
```sql
-- migrations/000N_<nome>.sql
CREATE TABLE ... ;
CREATE INDEX ... ;
```

### Alterações em tabelas existentes
<Cada alteração com justificativa. Se não houver, escreva "nenhuma".>

### Estratégia de migração
<Como aplicar sem downtime? Há dados a migrar? Há rollback?>

## 3. Contratos de API
<Para cada endpoint novo ou alterado:>

### `METHOD /path`

**Request:**
- Body (Zod schema): `<schema>`
- Query params: `<params>`
- Headers: `<headers>`

**Response:**
- `200`: `<shape>`
- `400`: `<motivo>`
- `401`: `<motivo>`
- `403`: `<motivo>`
- `404`: `<motivo>`
- `500`: `<motivo>`

**Regras aplicáveis:** <quais CAs do SPEC este endpoint satisfaz>

**Segurança:** <quais Security Gates aplicam e como são atendidos>

## 4. Estrutura de arquivos

```text
src/
├── routes/
│   └── api/<feature>/
│       ├── +server.ts        # <propósito>
│       └── ...
├── lib/
│   └── server/
│       └── <feature>/
│           ├── index.ts      # <propósito>
│           └── ...
workers/src/
└── <feature>/
    └── ...
```

## 5. Componentes de UI
<Se a feature tem UI:>
- `<ComponentName>` em `<path>`: <propósito>
- Estado gerenciado via `<runes ou store>`.
- Dados vindos de `<load function>`.

Se não houver UI, escreva "não aplicável".

## 6. Tarefas atômicas

<Cada tarefa deve ser verificável em 1-2h, ter entrada/saída claras,
e produzir um artefato concreto. Mínimo 3, ideal 6-12.>

### Tarefa 1: <título>
**Objetivo:** <1 frase>
**Artefatos:**
- `<arquivo>` — <o que faz>
**Critérios de verificação:**
- [ ] <teste/comando que valida>
**Dependências:** <nenhuma | tarefa N>

### Tarefa 2: <título>
...

## 7. Testes planejados

### Unit
- `<arquivo>.test.ts` — <o que cobre>

### E2E
- `<cenário>` — <o que valida>

### Mutation (opcional)
- `<módulo>` — <por que é crítico>

## 8. Riscos técnicos
<Cada risco com: probabilidade (baixa/média/alta), impacto
(baixo/médio/alto), mitigação.>

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| ...   | ...           | ...     | ...       |

## 9. Impacto em segurança
<Para cada Security Gate do AGENTS.md que **aplica**, diga como o
plano atende:>

- **Gate 1 (Secrets):** <como>
- **Gate 2 (Input):** <como>
- ...

Para os que não aplicam, escreva "não aplicável".

## 10. Rollback

**Se o deploy falhar:**
- Deploy: `<comando>`
- Migration: `<estratégia>`
- Código: `<estratégia>`

## 11. Estimativa de blast radius

**Baixo / Médio / Alto** — <justificativa>

RESTRIÇÕES:
- NÃO implemente código. Apenas planeje.
- NÃO invente dependências que não estão no package.json.
- NÃO proponha bibliotecas externas sem justificar.
- NÃO deixe endpoints sem tratamento de erro especificado.
- NÃO deixe tarefas vagas ("implementar backend").
- Cada endpoint deve mapear para pelo menos 1 critério de aceitação
  do SPEC.
- Cada critério de aceitação do SPEC deve aparecer em pelo menos 1
  tarefa.

Entregue o PLAN.md completo.
```

Salve a saída como rascunho interno.

### Passo 3 — Complexity Auditor revisa

Invoque o subagente **Complexity Auditor** com o seguinte prompt:

```text
Você é um arquiteto sênior com foco em simplicidade. Revise o plano
técnico abaixo procurando por complexidade desnecessária.

PLANO:
<cole aqui o rascunho do PLAN.md>

SPEC (para contexto):
<cole aqui o SPEC.md>

PROJETO:
<estrutura atual de src/ e workers/src/>

VERIFIQUE ESPECIFICAMENTE:

1. SCHEMA D1
   - Há tabelas/colunas que a spec não exige?
   - Há índices redundantes ou faltando?
   - Há foreign keys com ON DELETE inadequado?
   - Há tipos errados (TEXT onde INTEGER, etc.)?

2. ENDPOINTS
   - Há endpoints que fazem coisas demais?
   - Há endpoints que poderiam ser combinados?
   - Há endpoints duplicando funcionalidade existente?
   - O tratamento de erro cobre os casos da spec?

3. ESTRUTURA DE ARQUIVOS
   - Há arquivos que fazem coisas demais?
   - Há profundidade de pastas excessiva?
   - Há arquivos que deveriam ser módulos separados?
   - Há duplicação de lógica com o que já existe?

4. TAREFAS
   - Há tarefas grandes demais (>2h de trabalho)?
   - Há tarefas vagas demais (não verificáveis)?
   - Há dependências circulares entre tarefas?
   - Cada tarefa produz um artefato concreto?

5. COBERTURA DA SPEC
   - Cada critério de aceitação aparece em pelo menos 1 tarefa?
   - Cada endpoint mapeia para pelo menos 1 critério?
   - Há endpoints sem critério correspondente (feature creep)?

6. SIMPLICIDADE
   - Há alguma solução mais simples que resolveria o mesmo problema?
   - Há alguma abstração prematura?
   - Há alguma otimização que a spec não exige?

REPORTE:
- Para cada problema: seção do PLAN.md, problema concreto, sugestão.
- Classifique: BLOQUEANTE / IMPORTANTE / MENOR.
- Se algo estiver OK, diga explicitamente "OK".
- NÃO reescreva o plano. Apenas reporte.
```

### Passo 4 — Consolidação

1. Se houver BLOQUEANTES, invoque o Drafter novamente com o feedback
   e gere a segunda versão.
2. Repita Drafter → Complexity Auditor até não haver BLOQUEANTES
   (máximo 3 iterações).
3. Quando estável, escreva `docs/PLAN.md`.
4. Escreva o rascunho da primeira migration em
   `migrations/000N_<nome>.sql.rascunho` (extensão `.rascunho` para
   deixar claro que não deve ser aplicada ainda).
5. Se o `/sveflare-goal` ainda não foi rodado, crie uma seção
   preliminar em `.agents/goals/current.md` listando as tarefas
   (será substituída quando o usuário rodar `/sveflare-goal` por
   tarefa).

### Passo 5 — Apresentação ao usuário

Apresente:

```markdown
## PLAN.md pronto para revisão

**Resumo executivo:**
- Feature: <nome>
- Tabelas novas/alteradas: <N>
- Endpoints: <N>
- Arquivos a criar/modificar: <N>
- Tarefas atômicas: <N>
- Iterações Drafter↔Complexity Auditor: <N>
- Blast radius: <baixo/médio/alto>

**Arquivo:** `docs/PLAN.md`
**Rascunho de migration:** `migrations/000N_<nome>.sql.rascunho`

**Pontos que precisam da sua decisão:**
1. <questão 1>
2. <questão 2>

**Próximos passos:**
- Revise o PLAN e confirme as decisões técnicas.
- Quando aprovar, comece pela Tarefa 1:
  `/sveflare-goal <título da tarefa 1>`
```

## Comportamento em casos especiais

### Se `docs/SPEC.md` não existir

Pare imediatamente e diga:

```text
Não encontrei `docs/SPEC.md`. Você precisa rodar `/sveflare-spec`
primeiro para criar a especificação.

Alternativa: se você já tem uma spec em outro arquivo, me diga o
caminho e eu uso.
```

### Se o SPEC tiver questões em aberto não respondidas

Pare e diga:

```text
O SPEC tem N questões em aberto que ainda não foram respondidas:

1. <questão 1>
2. <questão 2>

Essas questões impactam decisões técnicas do plano. Responda-as antes
de prosseguir, ou me diga explicitamente para assumir uma decisão
padrão.
```

### Se o SPEC for grande demais (>15 CAs)

Avise:

```text
Este SPEC tem N critérios de aceitação. Um plano para todos eles
resultaria em muitas tarefas (>15) e alto risco de scope creep.

Recomendo:
a) Dividir a spec em 2-3 partes menores
b) Prosseguir e gerar o plano (aceito o risco)

O que prefere?
```

### Se a feature exigir dependência nova

Se o Drafter ou o Complexity Auditor concluírem que é necessária uma
biblioteca nova, **pare** e peça autorização:

```text
O plano técnico proposto requer a dependência `<nome>` para
<propósito>. Isso adiciona ~X KB ao bundle e uma nova superfície de
ataque.

Alternativas consideradas:
1. <alternativa 1>
2. <alternativa 2>

Autoriza adicionar `<nome>`?
```

## Evidências de conclusão

Antes de declarar o comando concluído:

- [ ] `docs/SPEC.md` foi lido e estava aprovado.
- [ ] Skills relevantes foram carregadas.
- [ ] Drafter gerou rascunho completo com as 11 seções.
- [ ] Complexity Auditor revisou sem BLOQUEANTES (ou resolvidos).
- [ ] `docs/PLAN.md` escrito em disco.
- [ ] Rascunho de migration em `migrations/*.sql.rascunho` (se
      aplicável).
- [ ] Cada critério de aceitação do SPEC aparece em pelo menos uma
      tarefa.
- [ ] Cada endpoint mapeia para pelo menos um critério de aceitação.
- [ ] Blast radius estimado.
- [ ] Rollback documentado.
- [ ] Usuário foi apresentado ao resumo executivo.

## Exemplo de uso

```text
/sveflare-plan
```

(Ou, se a spec está em outro lugar:)

```text
/sveflare-plan docs/specs/comentarios.md
```

**Resultado esperado:** após 1-3 iterações Drafter↔Complexity Auditor,
um `docs/PLAN.md` com schema D1, ~4 endpoints, ~8 tarefas atômicas, e
uma estimativa de blast radius.

## Diferença entre SPEC e PLAN

| Aspecto | SPEC | PLAN |
|---------|------|------|
| Foco | O QUÊ e POR QUÊ | COMO |
| Contém código? | Não | SQL, tipos TypeScript, esboços |
| Critérios | De aceitação (produto) | De verificação (técnico) |
| Aprovação | Product owner | Tech lead |
| Revisa com | Verifier | Complexity Auditor |
| Modelo | deepseek-chat | deepseek-reasoner |
| Duração esperada | 1 sessão | 1 sessão |

## Referências

- `.agents/templates/PLAN.md` — template base do documento.
- `.agents/commands/sveflare-spec.md` — comando anterior no fluxo.
- `.agents/commands/sveflare-goal.md` — próximo comando no fluxo.
- `AGENTS.md` — regras operacionais e Security Gates.
- `.agents/skills/code-complexity/SKILL.md` — thresholds e padrões.
- `.agents/skills/cloudflare-d1/SKILL.md` — padrões de schema.
- `docs/USAGE.md` — fluxo completo de uso.
