---
name: agentic-code-review
description: "Revisão de código e PRs produzidos por agentes de IA: camadas de revisão por risco, detecção de red flags (testes reescritos para passar, CI enfraquecido, validação ausente), verificação independente e gates de merge. Use ao revisar PR, triar contribuições geradas por agente, definir o tier de revisão de uma mudança ou configurar um subagente verificador."
---

# Skill: agentic-code-review

## Quando usar

Carregue esta skill ao trabalhar com:
- Revisão de PR (especialmente PRs gerados por agentes)
- Triagem de PRs antes de revisão humana
- Definição de camadas de revisão por risco
- Detecção de red flags em código assistido por IA
- Configuração de subagentes verificadores
- Estabelecimento de gates de merge

## Contexto

Citação relevante (Addy Osmani, "Agentic Code Review"):

> "Teams shipping with AI assistance report roughly 4x the code output
> for about a 12% gain in perceived value. That is the real bottleneck
> in most engineering orgs right now: not writing code, but reviewing
> it, understanding it, and being confident enough to ship it."

Implicação prática: com agentes escrevendo muito código, o review
passa a ser o gargalo. A resposta não é revisar tudo manualmente —
é **triagem inteligente + camadas de revisão + verificação independente**.

> "Human in the loop becomes human on the loop: sampling, spot-checking
> and auditing the system rather than reading every PR."

## Princípios

### 1. Um subagente rascunha, outro verifica

> "One sub-agent drafts the change. A separate one verifies it."

Nunca deixe o mesmo agente (ou modelo) que produziu o código decidir
que está bom. Use papéis distintos:

| Subagente | Papel | Ferramentas | Viés |
|-----------|-------|-------------|------|
| Drafter | Implementa | edit, write, bash | Otimista |
| Verifier | Verifica independente | read, bash, grep | Cético |
| Judge | Decide com evidências | read, evidências | Neutro |
| Security Auditor | OWASP + leaks | owasp-check, gitleaks | Paranoico |
| Complexity Auditor | Complexidade + redundância | complexity-check | Arquiteto |

### 2. Human on the loop, não in the loop

Você não precisa ler cada linha. Você precisa:
- Amostrar PRs por camada de risco.
- Fazer spot-check em pontos críticos.
- Auditar o sistema (métricas, taxas de erro, padrões de falha).
- Intervir onde errar dói mais.

### 3. Exigir evidências antes de revisar

> "Require, before review: a statement of what the change is for, a diff
> that is not 3,500 lines with no comments, the test output, and proof
> it was actually run."

Um PR sem descrição de intenção, sem output de teste e sem prova de
execução não é revisável. Feche e peça contexto.

### 4. Testes são mais importantes que código

> "The agent changes behavior, then 'fixes' the test by rewriting the
> assertion to match the new, broken behavior."

Mudanças em testes merecem **mais** escrutínio que mudanças em código.
Um teste reescrito silenciosamente é um teste perdido.

### 5. Coverage não é verificação

> "Coverage tells you a line ran, mutation testing tells you whether the
> test would notice if that line were wrong."

Cobertura alta com testes fracos dá falsa segurança. Use mutation
testing para validar força real dos testes.

## Camadas de revisão por risco

Nem todo PR merece o mesmo esforço. Classifique por risco antes de revisar.

| Camada | Critério | Ação | SLA |
|--------|----------|------|-----|
| **Fast** | < 100 linhas, sem auth, sem DB, sem IA | Revisão leve (5 min) | < 1h |
| **Normal** | < 400 linhas, sem auth, sem DB | Revisão normal (30 min) | < 4h |
| **Heavy** | Toca auth, DB schema, R2, AI Gateway | Revisão pesada + Security Auditor | < 24h |
| **Critical** | Deploy prod, migração D1 irreversível | Revisão humana obrigatória + approval gate | Sem SLA |

### Como classificar automaticamente

```yaml
# harness.config.yml
review:
  tiers:
    fast:
      when: "PR < 100 linhas e não toca auth, DB, AI Gateway"
      action: "revisão leve"
    normal:
      when: "PR < 400 linhas e não toca auth"
      action: "revisão normal"
    heavy:
      when: "toca auth, schema D1, AI Gateway ou R2"
      action: "revisão pesada + security_auditor"
    critical:
      when: "deploy prod ou migração D1"
      action: "revisão humana obrigatória + approval gate"
```

### Regra prática

Um PR é **heavy** se tocar qualquer um destes:
- `src/hooks.server.ts`
- `src/lib/server/session.ts`
- `src/lib/server/password.ts`
- `migrations/*.sql`
- `wrangler.production.toml`
- `workers/src/ai/*`
- `workers/src/storage/*`
- Qualquer `.github/workflows/*`

## Red flags em PRs de agentes

Sinais de que o PR precisa de mais escrutínio (ou deve ser rejeitado):

### 1. Testes reescritos para passar

```diff
- expect(createUser({ email: '' })).rejects.toThrow();
+ expect(createUser({ email: '' })).resolves.toBeDefined();
```

A asserção mudou, o código não. Isso mascara um bug.

**Ação:** rejeitar. Pedir fix do código, não do teste.

### 2. CI enfraquecido

```diff
- "test:coverage": "vitest run --coverage --coverage.thresholds.lines=70",
+ "test:coverage": "vitest run --coverage",
```

Ou:

```diff
- continue-on-error: false
+ continue-on-error: true
```

Ou remoção de `pnpm lint` do pipeline.

**Ação:** rejeitar. CI é invariante do projeto.

### 3. Helper duplicado já existente

```ts
// Já existia em src/lib/utils/validation.ts
export const isValidEmail = (e: string) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e);

// PR adiciona em src/routes/register/utils.ts
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
```

**Ação:** pedir para usar o existente. Verificar com `knip` / grep.

### 4. Input não confiável indo para LLM

```ts
const prompt = `Responda: ${userInput}`;
await callLLM(prompt);
```

Sem sanitização. Prompt injection latente.

**Ação:** rejeitar. Exigir `sanitizeForPrompt()`.

### 5. PR gigante sem justificativa

- > 1000 linhas de diff.
- Múltiplas responsabilidades misturadas.
- Refatoração + nova funcionalidade + correção no mesmo PR.

**Ação:** pedir split em PRs menores.

### 6. Zero descrição de intenção

PR sem:
- "O quê" (o que muda).
- "Por quê" (motivação).
- "Como testar" (passos).

**Ação:** fechar. Pedir contexto antes de revisar.

### 7. Migration irreversível sem plano

```sql
ALTER TABLE users DROP COLUMN email;
```

Sem migration de rollback, sem backup, sem staging testado.

**Ação:** rejeitar até haver plano de rollback.

### 8. Secrets em código

```ts
const API_KEY = "sk-...";
```

**Ação:** rejeitar imediatamente. Rotacionar o secret.

### 9. Deleção de testes sem substituição

```diff
- describe('user validation', () => { /* 10 testes */ });
```

Sem explicação.

**Ação:** rejeitar. Perguntar por quê.

### 10. Suprimir erro em vez de corrigir

```ts
try {
  await criticalOperation();
} catch {
  // ignora
}
```

**Ação:** rejeitar. Exigir tratamento explícito.

### 11. Adição de dependência pesada sem justificativa

```diff
+ "lodash": "^4.17.21"
```

Para usar `lodash.get()`. Ou `moment` para formatar data.

**Ação:** perguntar. Preferir solução nativa.

### 12. `any` ou `@ts-ignore` novo

```ts
// @ts-ignore
const user = data.user;
```

**Ação:** rejeitar. Usar `unknown` + narrowing ou tipar corretamente.

## Triagem por subagente

Antes da revisão humana, um subagente faz triagem.

### Prompt de triagem

```yaml
# harness.config.yml — subagente triage
triage:
  model: deepseek-chat
  tools: [read, bash, grep]
  system_prompt: |
    Você tria PRs. NÃO decide merge. Classifique em:

    - low-risk: pode revisar rápido (fast tier)
    - needs-work: precisa mais contexto antes de revisar
    - high-risk: toca auth/DB/IA/R2 → heavy tier
    - critical: deploy prod ou migration irreversível → human gate

    Verifique especificamente:
    - Testes reescritos para passar
    - CI enfraquecido
    - Helpers duplicados
    - Input não confiável em LLM
    - PR > 1000 linhas
    - Falta de descrição de intenção
    - Secrets
    - Migrations sem rollback

    Reporte:
    - Classificação
    - Red flags encontradas (com arquivo:linha)
    - Ação recomendada
```

### Fluxo

```text
PR aberto
  ↓
[Subagente triage] → classifica + lista red flags
  ↓
┌──────────────────────┬──────────────────────┬──────────────────────┐
│ low-risk             │ needs-work           │ high-risk/critical   │
│ (fast tier)          │                      │                      │
├──────────────────────┼──────────────────────┼──────────────────────┤
│ Revisão leve         │ Pedir contexto       │ Security Auditor +   │
│ Merge                │                      │ Complexity Auditor + │
│                      │                      │ revisão pesada       │
└──────────────────────┴──────────────────────┴──────────────────────┘
  ↓
[Subagente judge] → decide com base em evidências
  ↓
Merge ou rejeição
```

## Exigências antes de merge

Um PR só pode ser mergeado se **todos** estes forem verdadeiros:

### Evidências obrigatórias

- [ ] Descrição com "O quê", "Por quê", "Como testar".
- [ ] `pnpm verify` verde (output anexado).
- [ ] `pnpm security:scan` verde.
- [ ] `pnpm complexity:scan` verde.
- [ ] Migrations testadas em staging (se aplicável).
- [ ] Screenshots ou logs de smoke test (se UI/integração).

### Verificação técnica

- [ ] CI verde em todos os gates obrigatórios.
- [ ] Diff revisado (ou amostrado, se fast tier).
- [ ] Nenhum red flag da lista.
- [ ] Testes NÃO foram reescritos para passar.
- [ ] CI NÃO foi enfraquecido.
- [ ] Blast radius avaliado.
- [ ] Rollback documentado.

### Verificação independente

- [ ] Subagente Verifier confirmou (não confia no Drafter).
- [ ] Subagente Security Auditor rodou (se heavy/critical).
- [ ] Subagente Complexity Auditor rodou (se heavy/critical).
- [ ] Subagente Judge emitiu decisão com base em evidências.

### Aprovação humana

- [ ] Revisor humano aprovou (fast/normal/heavy).
- [ ] Approval gate acionado (critical).

## Como pedir mudanças

Ao rejeitar um PR, seja específico e acionável.

### Ruim

```text
❌ "Isso está errado, refaça."
❌ "Não gostei."
❌ "Falta algo."
```

### Bom

```text
✅ "O teste `should reject empty email` foi alterado para aceitar
   email vazio. Isso mascara o bug no handler. Reverter a asserção
   e corrigir a validação em src/routes/register/+page.server.ts:42."

✅ "Este PR adiciona regex de email em src/routes/utils.ts, mas já
   existe `isValidEmail` em src/lib/utils/validation.ts. Usar o
   helper existente."

✅ "Input do usuário vai direto para o prompt em ai/chat.ts:18.
   Exigir sanitizeForPrompt() antes de enviar ao Gateway."

✅ "PR tem 2800 linhas e mistura refatoração + nova feature.
   Dividir em 3 PRs: (1) refatoração, (2) feature, (3) testes."
```

## Como amostrar em vez de ler tudo

Quando o volume é grande, você não lê tudo. Amostre com estratégia.

### Amostragem por criticidade

Leia sempre (sem amostragem):
- Arquivos de auth/session/password.
- Migrations D1.
- Configuração de CI.
- Chamadas LLM (prompt injection).
- Headers de segurança / CORS.

Amostre:
- Componentes UI (1 em cada 5).
- Handlers CRUD (1 em cada 3).
- Testes (verifique estrutura, não cada caso).

### Amostragem por diff

Leia:
- Primeiras e últimas 50 linhas de cada arquivo modificado.
- Linhas removidas (o que foi apagado importa).
- Asserções de teste modificadas.

Não leia:
- Reformatação pura (prettier).
- Renomeação mecânica.
- Ordenação de imports.

### Amostragem por padrão

Busque padrões suspeitos com grep em vez de ler tudo:

```bash
# Red flags comuns
grep -rn "\.skip(\|\.only(\|xit(\|xdescribe(" tests/
grep -rn "@ts-ignore\|@ts-expect-error\|as any" src/ workers/
grep -rn "console.log" src/ workers/
grep -rn "catch {}\|catch (e) {}" src/ workers/
grep -rn "\.catch(() => {})\|\.catch(() => null)" src/ workers/
grep -rn "api.openai.com\|api.anthropic.com" src/ workers/
grep -rn "eval(\|new Function(" src/ workers/
```

## Métricas para auditoria do sistema

Em vez de revisar tudo, monitore o sistema:

| Métrica | Meta | Sinal de alerta |
|---------|------|-----------------|
| Tempo médio até primeiro review | < 4h | > 24h |
| Taxa de PRs com red flag | < 10% | > 25% |
| Taxa de testes reescritos | < 2% | > 5% |
| Cobertura de mutation | > 60% | < 50% |
| Bugs em produção por release | < 2 | > 5 |
| PRs > 1000 linhas | < 5% | > 15% |
| Rollbacks por mês | < 1 | > 3 |

Se uma métrica está no vermelho, ajuste o sistema — não reforce o
review manual.

## Checklist do revisor

### Antes de revisar

- [ ] PR tem descrição de intenção
- [ ] CI verde (todos os gates)
- [ ] Diff dentro do tier esperado (ou justificado)
- [ ] Classificação por risco definida

### Durante a revisão

- [ ] Li (ou amostrei) todas as mudanças críticas
- [ ] Verifiquei se testes foram alterados
- [ ] Verifiquei se CI foi alterado
- [ ] Verifiquei se há duplicação
- [ ] Verifiquei se input vai para LLM sem sanitização
- [ ] Verifiquei se há secrets
- [ ] Verifiquei se migrations têm rollback
- [ ] Verifiquei headers de segurança (se aplicável)
- [ ] Verifiquei rate limiting (se aplicável)

### Antes de aprovar

- [ ] Nenhum red flag da lista
- [ ] Subagente Verifier confirmou
- [ ] Subagente Security Auditor rodou (heavy/critical)
- [ ] Subagente Judge emitiu decisão
- [ ] Approval gate acionado (critical)
- [ ] Rollback documentado
- [ ] Blast radius avaliado

### Após merge

- [ ] Monitorar produção por 15 min
- [ ] Verificar logs de erro
- [ ] Confirmar que mudança funciona como esperado
- [ ] Registrar lição (se houver)

## Ferramentas

```bash
# Triagem automática (via subagente)
# Configurado em harness.config.yml

# Buscar red flags
grep -rn "\.skip(\|\.only(\|xit(\|xdescribe(" tests/
grep -rn "@ts-ignore\|as any" src/ workers/
grep -rn "catch {}\|catch (e) {}" src/ workers/
grep -rn "eval(\|new Function(" src/ workers/

# Verificar testes alterados no PR
git diff origin/develop...HEAD --name-only | grep -E "\.test\.|\.spec\.|/tests/"

# Verificar CI alterado no PR
git diff origin/develop...HEAD --name-only | grep -E "\.github/workflows/|\.husky/"

# Verificar tamanho do PR
git diff origin/develop...HEAD --shortstat
```

## Anti-patterns de revisão

### 1. "LGTM" sem ler

```text
❌ Aprovar sem abrir o diff.
✅ Amostrar + verificar red flags + ler críticos.
```

### 2. Bloquear por preferência pessoal

```text
❌ "Eu prefiro tabs em vez de spaces."
✅ Verificar contra o padrão do projeto, não preferência.
```

### 3. Revisar por horas e travar o time

```text
❌ Segurar PR por 3 dias pedindo polish.
✅ Bloqueie por correção, não por preferência.
```

### 4. Reescrever o PR no review

```text
❌ Fazer commit direto no branch do autor.
✅ Sugerir mudança, deixar o autor decidir.
```

### 5. Aprovar PR gigante "porque está verde"

```text
❌ CI verde ≠ código correto.
✅ Aplicar camadas de revisão.
```

### 6. Ignorar red flags porque "é só um agente"

```text
❌ "O agente sabe o que faz."
✅ Trate PR de agente como PR de júnior competente: bom, mas precisa verificação.
```

## Referências

- Addy Osmani — "Agentic Code Review"
- Addy Osmani — "The New SDLC with Vibe Coding"
- Addy Osmani — "Agentic Code Quality"
- Addy Osmani — "Practical Loop Engineering"
- Google Engineering Practices — Code Review
- AGENT.md — seção 7, Subagentes
- Skill `code-complexity` — red flags de qualidade
- Skill `security-leaks` — red flags de segurança
- Skill `owasp-top10` — checklist de segurança
