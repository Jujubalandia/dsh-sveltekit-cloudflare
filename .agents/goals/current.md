# Goal atual

<!--
  Este arquivo é preenchido no INÍCIO de cada tarefa e permanece
  TRAVADO durante toda a execução. O agente deve consultá-lo antes
  de declarar uma tarefa "concluída".
-->

**ID da tarefa:** <!-- ex: DSH-2026-09-15-001 -->
**Data de abertura:** <!-- YYYY-MM-DD -->
**Executor:** <!-- nome do agente / sessão -->
**Status:** `em-andamento` <!-- em-andamento | bloqueado | concluído | abortado -->

---

## 1. Descrição da tarefa

<!-- Uma frase clara do que precisa ser feito. Sem ambiguidade. -->

> Exemplo: Adicionar endpoint POST /api/files/upload que recebe um arquivo,
> valida tipo e tamanho, e grava no R2, registrando metadados no D1.

---

## 2. Motivação

<!-- Por que isso é necessário? Link para issue, discussão ou requisito. -->

- Issue: #
- Contexto: 

---

## 3. Critérios de aceitação

<!--
  CRITÉRIOS MENSURÁVEIS. Cada item deve ser verificável de forma objetiva
  por um comando, teste ou inspeção. Nada de "ficou bom" ou "funcionou".
-->

- [ ] Critério 1 (ex: endpoint retorna 201 para arquivo válido)
- [ ] Critério 2 (ex: endpoint retorna 400 para content-type não permitido)
- [ ] Critério 3 (ex: arquivo >10MB retorna 413)
- [ ] Critério 4 (ex: metadados inseridos em `uploaded_files`)
- [ ] Critério 5 (ex: teste unitário cobre caso de sucesso e 2 erros)
- [ ] Critério 6 (ex: cobertura do arquivo ≥ 70%)

---

## 4. Não-objetivos

<!-- O que está EXPLICITAMENTE fora do escopo desta tarefa. -->

- Não implementar UI de upload nesta tarefa.
- Não implementar deleção nesta tarefa.
- Não alterar schema além do já migrado.

---

## 5. Skills necessárias

<!-- Carregar antes de começar. Ver .agents/skills/ -->

- [ ] `cloudflare-r2`
- [ ] `cloudflare-d1`
- [ ] `sveltekit-auth`
- [ ] `security-leaks`
- [ ] `owasp-top10`

---

## 6. Security gates aplicáveis

<!-- Consultar AGENT.md seção 5. -->

- [ ] Gate 1 — Secrets (nenhum hardcode)
- [ ] Gate 2 — Input (Zod obrigatório)
- [ ] Gate 3 — D1 (prepared statements)
- [ ] Gate 4 — R2 (bucket privado, signed URL ≤15min, validar tipo/tamanho)
- [ ] Gate 5 — AI Gateway (se aplicável)
- [ ] Gate 6 — OWASP Top 10
- [ ] Gate 7 — Prompt Injection (se input for para LLM)
- [ ] Gate 8 — Deploy (aprovação humana)

---

## 7. Subagentes

<!--
  Delegação por papel. "One sub-agent drafts the change.
  A separate one verifies it." — Addy Osmani
-->

- [ ] **Drafter** — implementou a mudança
- [ ] **Verifier** — confirmou independentemente (rodou testes, leu código)
- [ ] **Security Auditor** — rodou `scripts/owasp-check.sh` e `gitleaks`
- [ ] **Complexity Auditor** — rodou `scripts/complexity-check.sh`
- [ ] **Judge** — aprovou com base em evidências

---

## 8. Plano de execução

<!-- Passos atômicos. Cada passo produz um artefato verificável. -->

1. [ ] Criar migration (se aplicável)
2. [ ] Implementar validação Zod do payload
3. [ ] Implementar handler do endpoint
4. [ ] Escrever testes unitários
5. [ ] Escrever teste e2e
6. [ ] Rodar `pnpm verify`
7. [ ] Rodar `pnpm security:scan`
8. [ ] Rodar `pnpm complexity:scan`
9. [ ] Abrir PR com descrição de intenção

---

## 9. Evidências esperadas

<!--
  SEM evidência, não há conclusão. Cada item abaixo deve virar um
  artefato anexado ao PR ou à conversa.
-->

- [ ] Output de `pnpm verify` (verde)
- [ ] Output de `pnpm security:scan` (verde)
- [ ] Output de `pnpm complexity:scan`
- [ ] Output de `pnpm test:coverage` com % do arquivo novo
- [ ] Screenshots ou logs de smoke test (se aplicável)
- [ ] Output do subagente verifier (report de discrepâncias)
- [ ] Output do subagente judge (decisão final)

---

## 10. Riscos e mitigação

<!--
  O que pode dar errado? Como reverter?
-->

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Migration falha em produção | baixa | alto | Testar em staging primeiro |
| Upload lento com arquivos grandes | média | médio | Streaming; limite de 10MB |
| Vazamento de PII em log | baixa | alto | Redaction obrigatória |

**Rollback:**
- Deploy: `wrangler rollback --env production`
- Migration: reverter via migration de correção (`NNNN_fix.sql`)
- Código: `git revert <commit>`

---

## 11. Loops ativos

<!--
  Tipos de loop. Só use se critério de "done" for determinístico.
-->

- [ ] Goal loop — critério mensurável, máximo de N tentativas
  - Critério: `pnpm verify` verde por 3 execuções seguidas
  - Max tentativas: 5
- [ ] Time loop — verificar PR a cada 5min
- [ ] Proactive loop — agendado (habilitar manualmente)

---

## 12. Bloqueios

<!-- Preencher durante a execução se algo travar. -->

- _(vazio — nenhum bloqueio no início)_

---

## 13. Notas de execução

<!-- Adicionar descobertas, decisões e desvios durante a tarefa. -->

---

## 14. Fechamento

<!-- Preencher apenas ao concluir a tarefa. -->

**Concluído em:** <!-- YYYY-MM-DD HH:MM -->
**Subagente judge aprovou:** <!-- sim | não -->
**Evidências anexadas:** <!-- lista ou link -->
**PR:** <!-- #número -->

### Retrospectiva (breve)

- **O que funcionou bem:**
- **O que poderia melhorar:**
- **Lição aprendida (a persistir em memória):**
