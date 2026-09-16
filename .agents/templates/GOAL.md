# Goal atual

<!--
  TEMPLATE — não edite este arquivo.

  Este é o molde que o comando `/sveflare-goal` usa para preencher
  `.agents/goals/current.md`. O arquivo ativo é sempre
  `.agents/goals/current.md`; este aqui existe para que o molde não se
  perca entre tarefas.

  Regras ao preencher o goal ativo:
  - NÃO deixe placeholders `<...>` — se não souber algo, pergunte.
  - Mínimo 3 critérios de aceitação, ideal 5-8.
  - Mínimo 2 não-objetivos (previne scope creep).
  - No máximo 2-3 skills.
  - Peça aprovação do usuário ANTES de travar o goal.
-->

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
