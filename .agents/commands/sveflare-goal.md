---
name: sveflare-goal
description: Trava o escopo de uma tarefa atômica em .agents/goals/current.md. Define critérios de aceitação mensuráveis, skills necessárias, security gates aplicáveis e evidências esperadas.
argument-hint: <descrição da tarefa em 1-2 frases>
allowed-tools: read, write, edit, grep, bash
model: deepseek-chat
---

# /sveflare-goal — Travar escopo de uma tarefa

Você está iniciando uma tarefa atômica. O objetivo é preencher
`.agents/goals/current.md` com um goal **claro, mensurável e imutável**
que guiará a implementação e a verificação.

Sem goal travado, o agente tende a tomar decisões de escopo que o
usuário não autorizou. Este comando força a explicitar o "contrato"
antes de tocar em código.

## Pré-requisitos

Confirme antes de prosseguir:

1. O workspace está com `pnpm verify` verde (rode `/sveflare-verify`
   se estiver em dúvida).
2. Não há goal em andamento em `.agents/goals/current.md`. Se houver,
   pergunte ao usuário se deve:
   - Marcar como concluído
   - Marcar como abortado
   - Cancelar o novo goal

Se houver goal ativo, **pare** e peça decisão.

## Argumento recebido

```
$ARGUMENTS
```

Se vazio, peça a descrição da tarefa (ver "Comportamento em casos
especiais").

## Restrições desta sessão

- NÃO escreva código de implementação.
- NÃO altere arquivos fora de `.agents/goals/`.
- NÃO invente critérios de aceitação que o usuário não aprovou.
- Se o argumento for vago, **peça esclarecimento** antes de inventar.
- Se a tarefa for grande demais (>2h), sugira dividir.
- Peça aprovação do goal antes de travá-lo.

## Fluxo de execução

### Passo 1 — Preparação

1. Leia `AGENTS.md` para relembrar:
   - Code Rules (seção 4).
   - Security Gates (seção 5).
   - Regras Críticas (seção 12).
2. Leia `.agents/goals/current.md` para verificar se está vazio.
3. Se houver `docs/PLAN.md` em andamento, leia a tarefa correspondente
   para alinhar o goal com o plano.
4. Identifique quais skills são relevantes para esta tarefa.
   Carregue no máximo 3 (ver tabela na seção 7 deste comando).
5. Identifique quais Security Gates aplicam (ver seção 6).

### Passo 2 — Estruturar o goal

Antes de escrever, valide que o argumento:

- [ ] Está em 1-2 frases.
- [ ] Descreve uma tarefa atômica (não uma feature inteira).
- [ ] Tem um resultado verificável.
- [ ] Não depende de decisões não tomadas.

Se algum item falhar, use "Comportamento em casos especiais" antes de
prosseguir.

### Passo 3 — Preencher `.agents/goals/current.md`

Substitua o conteúdo do arquivo pela estrutura abaixo, preenchendo
cada seção. **Não deixe placeholders** — se não souber algo, pergunte
ao usuário.

```markdown
# Goal atual

**ID da tarefa:** <formato: G-YYYYMMDD-NNN>
**Data de abertura:** <YYYY-MM-DD HH:MM>
**Executor:** <sessão DSH atual>
**Status:** `em-andamento`

---

## 1. Descrição da tarefa

<1-2 frases. Uma única responsabilidade. Sem "e" conectando dois
objetivos.>

> Exemplo: Adicionar endpoint `POST /api/files/upload` que recebe
> arquivo, valida tipo e tamanho, grava em R2 e registra metadados
> em `uploaded_files`.

---

## 2. Motivação

<Por que isso é necessário? Link para spec, issue ou plano.>

- Spec relacionada: `docs/SPEC.md`, CA-<N>
- Plano relacionado: `docs/PLAN.md`, Tarefa <N>
- Issue: #

---

## 3. Critérios de aceitação

<Cada critério é VERIFICÁVEL por comando, teste ou inspeção.
Mínimo 3, ideal 5-8. Formato Dado/Quando/Então.>

- [ ] **CA-1**: DADO <contexto>, QUANDO <ação>, ENTÃO <resultado
      observável>.
- [ ] **CA-2**: ...
- [ ] **CA-3**: ...

---

## 4. Não-objetivos

<O que está EXPLICITAMENTE fora do escopo desta tarefa. Mínimo 2
itens. Previne scope creep.>

- Não implementar <X>.
- Não alterar <Y>.
- Não otimizar <Z>.

---

## 5. Skills necessárias

<Marque as que serão carregadas. 2-3 no máximo.>

- [ ] `cloudflare-d1`
- [ ] `cloudflare-kv`
- [ ] `cloudflare-r2`
- [ ] `cloudflare-ai-gateway`
- [ ] `sveltekit-runes`
- [ ] `sveltekit-auth`
- [ ] `cloudflare-security`
- [ ] `owasp-top10`
- [ ] `security-leaks`
- [ ] `code-complexity`
- [ ] `git-flow`
- [ ] `agentic-code-review`

---

## 6. Security Gates aplicáveis

<Marque os que aplicam a esta tarefa.>

- [ ] Gate 1 — Secrets (nunca hardcode)
- [ ] Gate 2 — Input (Zod obrigatório)
- [ ] Gate 3 — D1 (prepared statements)
- [ ] Gate 4 — R2 (privado, signed URL ≤15min, validar tipo/tamanho)
- [ ] Gate 5 — AI Gateway (guardrails, rate limit, redaction)
- [ ] Gate 6 — OWASP Top 10
- [ ] Gate 7 — Prompt Injection (input sanitizado)
- [ ] Gate 8 — Deploy (staging → smoke → aprovação → prod)

---

## 7. Subagentes

<Marque conforme necessidade.>

- [ ] **Drafter** — implementa a mudança
- [ ] **Verifier** — verifica independentemente
- [ ] **Judge** — decide com base em evidências
- [ ] **Security Auditor** — roda OWASP + gitleaks
- [ ] **Complexity Auditor** — analisa complexidade

---

## 8. Plano de execução

<Passos atômicos. Cada passo produz um artefato verificável.>

1. [ ] <passo 1>
2. [ ] <passo 2>
3. [ ] <passo 3>

---

## 9. Evidências esperadas

<Cada item abaixo deve virar um artefato verificável.>

- [ ] Output de `pnpm check`
- [ ] Output de `pnpm lint`
- [ ] Output de `pnpm test` (ou teste focado)
- [ ] Output de `pnpm security:scan` (se aplicável)
- [ ] Output de `pnpm complexity:scan` (se aplicável)
- [ ] Relatório do Verifier
- [ ] Decisão do Judge

---

## 10. Riscos e mitigação

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| <risco 1> | baixa/média/alta | baixo/médio/alto | <mitigação> |

**Rollback:**
- Código: `<estratégia>`
- Migration: `<estratégia>` (se aplicável)

---

## 11. Loops ativos

<Habilite apenas se o critério de "done" for determinístico.>

- [ ] **Goal loop** — repetir até CA-<N> passar, máximo <N> tentativas.
- [ ] **Time loop** — verificar <recurso> a cada <N> minutos.

---

## 12. Bloqueios

- _(vazio no início)_

---

## 13. Notas de execução

<Preenchido DURANTE a execução. Descobertas, decisões, desvios.>

---

## 14. Fechamento

<Preenchido APENAS ao concluir.>

**Concluído em:** <YYYY-MM-DD HH:MM>
**Status final:** `concluído` / `abortado`
**Subagente Judge aprovou:** sim / não
**Evidências anexadas:** <lista>
**PR:** #<número>

### Retrospectiva breve

- **O que funcionou bem:**
- **O que poderia melhorar:**
- **Lição aprendida (a persistir em memória):**
```

### Passo 4 — Validar o goal

Antes de travar, verifique:

- [ ] Descrição tem uma única responsabilidade.
- [ ] Pelo menos 3 critérios de aceitação, todos testáveis.
- [ ] Pelo menos 2 não-objetivos.
- [ ] Skills carregadas condizem com a tarefa.
- [ ] Security Gates aplicáveis estão marcados.
- [ ] Plano de execução tem passos concretos.
- [ ] Evidências esperadas são verificáveis.
- [ ] Riscos principais listados.
- [ ] Rollback documentado.

Se algo falhar, ajuste antes de travar.

### Passo 5 — Apresentar e travar

Apresente o goal ao usuário:

```markdown
## Goal pronto para travamento

**Tarefa:** <descrição curta>
**Critérios de aceitação:** <N>
**Skills:** <lista>
**Gates aplicáveis:** <lista>
**Subagentes:** <lista>

**Arquivo:** `.agents/goals/current.md`

**Pontos que precisam de decisão:**
1. <questão 1, se houver>
2. <questão 2, se houver>

**Este goal ficará travado durante a execução.** Se o escopo mudar,
será necessário abrir um novo goal (o atual será marcado como
`abortado`).

Aprovar e travar? [s/n]
```

Após aprovação, escreva o arquivo em disco e confirme:

```text
✅ Goal travado.

Próximos passos:
- Implemente: "Implemente o goal atual em .agents/goals/current.md."
- Ao final, verifique com `/sveflare-verify`.
- Quando concluído, rode `/sveflare-goal` novamente para a próxima
  tarefa (ou marque o atual como concluído manualmente).
```

## Comportamento em casos especiais

### Se o argumento estiver vazio

Pergunte:

```text
Qual tarefa você quer executar? Descreva em 1-2 frases:
- O que precisa ser feito?
- Como você saberá que está pronto?
```

### Se a tarefa for grande demais

Se o argumento descrever mais que 2h de trabalho ou mais que 5
critérios de aceitação, avise:

```text
Esta tarefa parece grande demais para um único goal (estimativa >2h
ou >5 critérios). Considere dividir em:

a) <subtarefa 1>
b) <subtarefa 2>
c) Prosseguir como está (aceito o risco)

Recomendo dividir. O que prefere?
```

### Se a tarefa estiver vaga

Exemplo: "melhorar a performance".

Pergunte:

```text
Sua descrição está vaga. Preciso de critérios mensuráveis:
1. Qual métrica deve melhorar? (ex: latência p95)
2. De quanto para quanto? (ex: de 800ms para <200ms)
3. Em qual endpoint/cenário?
4. Como medir isso?
```

### Se já houver goal ativo

Pare e pergunte:

```text
Já existe um goal ativo em `.agents/goals/current.md`:

**ID:** <id>
**Tarefa:** <descrição>
**Status:** em-andamento

O que fazer com ele?

a) Marcar como concluído e abrir novo goal
b) Marcar como abortado e abrir novo goal
c) Cancelar este novo goal e continuar o atual
d) Voltar (não fazer nada)

Escolha uma opção.
```

### Se o goal exigir uma migration

Adicione um campo extra na seção 10:

```markdown
**Migration:**
- Arquivo: `migrations/000N_<nome>.sql`
- Rollback: `migrations/000N+1_<nome>_rollback.sql`
- Aplicada em staging: sim / não
- Requer aprovação humana para produção: sim
```

### Se o goal envolver AI Gateway

Adicione um campo extra na seção 9:

```markdown
- [ ] Guardrails ativos no AI Gateway
- [ ] Rate limit por usuário configurado
- [ ] Prompt sanitizado antes da chamada
- [ ] Logs com redaction de PII
```

### Se o goal tocar auth

Adicione um campo extra na seção 9:

```markdown
- [ ] Cookie httpOnly + secure + sameSite
- [ ] Sessão com expires_at explícito
- [ ] Rate limit em endpoint de login
- [ ] Mensagem de erro genérica
```

## Evidências de conclusão

Antes de declarar o comando concluído:

- [ ] `.agents/goals/current.md` escrito em disco.
- [ ] Nenhum placeholder `<...>` restante.
- [ ] Todos os critérios de aceitação são testáveis.
- [ ] Não-objetivos listados (≥2).
- [ ] Skills e Gates marcados.
- [ ] Plano de execução com passos concretos.
- [ ] Evidências esperadas listadas.
- [ ] Riscos e rollback documentados.
- [ ] Usuário aprovou o goal.
- [ ] Goal está travado (imutável).

## Exemplos de uso

### Exemplo 1 — Implementar endpoint

```text
/sveflare-goal Adicionar endpoint POST /api/files/upload que recebe
arquivo, valida tipo (png/jpeg/pdf) e tamanho (≤10MB), grava em R2 e
registra metadados em uploaded_files.
```

**Resultado:** goal com ~6 CAs, skills `cloudflare-r2` +
`cloudflare-d1` + `owasp-top10`, gates 2, 3, 4.

### Exemplo 2 — Corrigir bug

```text
/sveflare-goal Corrigir validação de email em POST /api/users que está
aceitando endereços sem TLD.
```

**Resultado:** goal com ~3 CAs, skills `owasp-top10`, gates 2, 6.

### Exemplo 3 — Refatoração

```text
/sveflare-goal Extrair lógica de cache de src/routes/api/users/+server.ts
para src/lib/server/cache/users.ts. Sem mudança de comportamento.
```

**Resultado:** goal com ~4 CAs (todos os testes existentes passam),
skills `code-complexity`, sem gates de segurança (refatoração neutra).

## Diferença entre SPEC, PLAN e GOAL

| Aspecto | SPEC | PLAN | GOAL |
|---------|------|------|------|
| Escopo | Feature inteira | Feature inteira | 1 tarefa atômica |
| Foco | Produto (o quê) | Técnico (como) | Contrato de execução |
| Imutável? | Após aprovação | Após aprovação | Durante execução |
| Duração | 1 sessão | 1 sessão | 1-2h |
| Aprovação | Product owner | Tech lead | Quem executa |
| Revisa com | Verifier | Complexity Auditor | Ninguém (é um contrato) |
| Modelo | deepseek-chat | deepseek-reasoner | deepseek-chat |

## Referências

- `.agents/templates/GOAL.md` — template base (opcional).
- `.agents/commands/sveflare-spec.md` — comando anterior no fluxo.
- `.agents/commands/sveflare-plan.md` — comando anterior no fluxo.
- `.agents/commands/sveflare-verify.md` — próximo comando no fluxo.
- `AGENTS.md` — regras operacionais e Security Gates.
- `.agents/skills/code-complexity/SKILL.md` — thresholds.
- `docs/USAGE.md` — fluxo completo de uso.
