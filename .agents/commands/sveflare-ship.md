---
name: sveflare-ship
description: Valida a feature com Security Auditor e Judge, faz deploy em staging, roda smoke test, e pede aprovação humana para produção. Último comando do fluxo SDLC.
argument-hint: [--skip-verify] [--staging-only] [--no-approval-gate]
allowed-tools: bash, read, grep
model: deepseek-reasoner
---

# /sveflare-ship — Validar e preparar deploy

Você está no último passo do fluxo SDLC. O objetivo é:

1. Confirmar que a feature está pronta (via subagentes independentes).
2. Fazer deploy em **staging** e validar com smoke test.
3. Pedir **aprovação humana explícita** antes de tocar em produção.
4. Se aprovado, fazer deploy em **produção** com observabilidade.
5. Monitorar produção por 15 minutos.

Este comando é o **único** que faz deploy. Não use para testar. Não use
para desenvolvimento iterativo. Use quando a feature está concluída e
verificada.

## Pré-requisitos

Confirme antes de prosseguir:

1. `.agents/goals/current.md` está preenchido e marcado como
   `concluído` (ou está pronto para ser marcado).
2. `/sveflare-verify` foi rodado e retornou **VERDE** (não amarelo,
   não vermelho).
3. Todos os critérios de aceitação do goal foram atendidos.
4. Não há alterações não commitadas pendentes (`git status` limpo).
5. O usuário está presente para aprovar o deploy de produção.

Se algum item falhar, **pare** e informe o usuário.

## Argumentos recebidos

```
$ARGUMENTS
```

Flags suportadas:

- `--skip-verify` — assume que `/sveflare-verify` já rodou (pula
  re-execução). Use com cuidado.
- `--staging-only` — faz deploy apenas em staging, sem produção.
- `--no-approval-gate` — **NÃO USE**. Reservado para automação
  confiável em pipelines internos. Requer que o usuário tenha
  explicitamente configurado approval automático.

Se a flag for desconhecida, ignore e pergunte.

## Restrições

- NUNCA faça deploy em produção sem aprovação humana explícita.
- NUNCA force push, rebase, ou altere histórico Git.
- NUNCA faça commit sem autorização.
- NUNCA pule o staging.
- NUNCA ignore bloqueantes reportados pelo Security Auditor.
- NUNCA prossiga se o Judge reprovar.
- SEMPRE monitore produção por 15 min após deploy.
- SEMPRE documente o rollback plan antes de tocar em produção.

## Fluxo de execução

### Passo 1 — Confirmação inicial

Pergunte ao usuário:

```text
Você está prestes a fazer deploy. Confirme:

1. Estamos em uma janela segura para deploy? (não em horário de pico)
2. Há algum deploy em andamento de outro time?
3. Você revisou o diff completo das mudanças?
4. Você tem o rollback plan em mãos?

Responda com "sim" para cada item, ou cancele agora.
```

Se o usuário não confirmar os 4 itens, **pare**.

### Passo 2 — Verificação pré-deploy

Se `--skip-verify` não foi passado, rode `/sveflare-verify` e aguarde.

Se o status não for **VERDE**, pare imediatamente:

```text
❌ /sveflare-verify retornou <status>. Não é seguro prosseguir com
deploy. Corrija os bloqueantes listados e rode novamente.

Bloqueantes:
<lista>
```

### Passo 3 — Security Auditor

Invoque o subagente **Security Auditor** com o seguinte prompt:

```text
Você é um auditor de segurança. Revise o estado atual do projeto
antes do deploy em produção.

CONTEXTO:
- Feature: <cole a descrição do goal>
- Goal: <cole o conteúdo de .agents/goals/current.md>
- Status da verificação: <resumo do relatório de /sveflare-verify>

TAREFAS:

1. Rode `./scripts/security-scan.sh` e analise a saída.
2. Rode `./scripts/owasp-check.sh` e analise a saída.
3. Verifique os 8 Security Gates do AGENTS.md:
   - Gate 1 (Secrets): gitleaks rodou? Sem findings?
   - Gate 2 (Input): todos os endpoints validam com Zod?
   - Gate 3 (D1): todas as queries usam .bind()?
   - Gate 4 (R2): buckets privados? Signed URLs ≤15min?
   - Gate 5 (AI Gateway): guardrails + rate limit ativos?
   - Gate 6 (OWASP): check verde?
   - Gate 7 (Prompt Injection): input sanitizado antes de LLM?
   - Gate 8 (Deploy): staging validado? Aprovação registrada?

4. Revise o diff contra a branch principal:
   `git diff origin/develop...HEAD`

5. Procure por:
   - Secrets hardcoded (gitleaks deve pegar, mas confirme)
   - PII em logs (grep por console.log com email/token/cpf)
   - Chamadas diretas a providers LLM (api.openai.com, etc.)
   - CORS wildcard em produção (origin: '*')
   - Stack traces em respostas de erro
   - Queries D1 sem .bind()
   - input do usuário sem sanitização indo para prompt

REPORTE:
- Status: APROVADO / APROVADO COM AVISOS / REPROVADO
- Bloqueantes encontrados (se houver)
- Avisos (se houver)
- Recomendação: prosseguir / corrigir primeiro

Seja conservador. Em dúvida, reprove.
```

**Se o Security Auditor reportar REPROVADO:** pare.

```text
❌ Security Auditor reprovou o deploy.

Bloqueantes:
<lista>

Corrija os itens acima e rode `/sveflare-ship` novamente.
```

**Se reportar APROVADO COM AVISOS:** pergunte ao usuário:

```text
⚠️  Security Auditor aprovou com N avisos:

1. <aviso 1>
2. <aviso 2>

Você aceita os avisos e prossegue? [s/n]
```

Se o usuário não aceitar, pare.

### Passo 4 — Judge decide

Invoque o subagente **Judge** com o seguinte prompt:

```text
Você é o juiz final antes do deploy. Decida se a feature está pronta
para produção.

CONTEXTO:
- Goal: <cole .agents/goals/current.md>
- Relatório de verificação: <resumo do /sveflare-verify>
- Relatório do Security Auditor: <resumo do passo 3>
- Diff da feature: <estatísticas do git diff>

CRITÉRIOS DE DECISÃO:

1. Critérios de aceitação
   - Todos os CAs do goal estão marcados como concluídos?
   - Cada CA tem evidência concreta (teste, comando, inspeção)?

2. Evidências
   - Todas as evidências esperadas foram produzidas?
   - Nenhuma evidência é "manual sem registro"?

3. Verificação independente
   - O Verifier foi acionado?
   - O Security Auditor aprovou?

4. Segurança
   - Todos os Security Gates aplicáveis estão atendidos?
   - Há avisos não aceitos?

5. Rollback
   - O rollback plan está documentado?
   - É executável em <5 min?

6. Blast radius
   - Baixo / Médio / Alto?
   - Se Alto, há mitigação?

DECISÃO:
- APROVADO — pode ir para staging
- APROVADO COM RESSALVAS — pode ir, mas com atenção
- REPROVADO — corrija antes

Baseie-se EXCLUSIVAMENTE em evidências. Não emita opinião sem
evidência. Se algo não está claro, marque como REPROVADO até ser
esclarecido.
```

**Se o Judge REPROVAR:** pare.

```text
❌ Judge reprovou o deploy.

Motivos:
<lista>

Corrija e rode `/sveflare-ship` novamente.
```

**Se o Judge aprovar (com ou sem ressalvas):** prossiga.

### Passo 5 — Confirmar staging

Antes de fazer deploy em staging:

```text
Pronto para deploy em staging.

Confirme:
1. Staging está acessível? (https://myapp-staging.pages.dev)
2. Há deploys em andamento em staging?
3. A migration de D1 (se houver) foi revisada?

Rollback plan (staging):
- Reverter deploy: `wrangler rollback --env staging`
- Reverter migration: <estratégia>

Prosseguir? [s/n]
```

### Passo 6 — Deploy em staging

Execute:

```bash
# Aplicar migration em staging (se houver)
pnpm wrangler d1 migrations apply DB --env staging

# Deploy do Worker
pnpm deploy:staging
```

Capture a saída e registre a versão deployada.

### Passo 7 — Smoke test em staging

Execute:

```bash
pnpm smoke staging
```

Se o smoke test falhar:

```text
❌ Smoke test em staging falhou.

Detalhes:
<output>

Ações:
1. Reverter o deploy: `wrangler rollback --env staging`
2. Investigar o erro.
3. Corrigir e rodar `/sveflare-ship` novamente.
```

Pare e aguarde o usuário.

Se passar, continue.

### Passo 8 — Validação manual em staging (opcional)

Pergunte:

```text
✅ Smoke test passou. Quer validar manualmente em staging antes de
produção?

URL: https://myapp-staging.pages.dev

Roteiro sugerido:
1. <passo 1>
2. <passo 2>
3. <passo 3>

Quando terminar, responda "aprovado" ou "reprovado".
```

Se o usuário não quiser validar manualmente, prossiga.

### Passo 9 — Aprovação para produção

A menos que `--no-approval-gate` tenha sido passado (não recomendado),
**exija aprovação humana explícita**:

```text
═══════════════════════════════════════════════════════════
  APROVAÇÃO PARA DEPLOY EM PRODUÇÃO
═══════════════════════════════════════════════════════════

Feature: <nome>
Blast radius: <baixo/médio/alto>
Security Auditor: ✅ aprovado
Judge: ✅ aprovado
Smoke test (staging): ✅ passou

Rollback plan:
  - Deploy: `wrangler rollback --env production`
  - Migration: <estratégia>
  - Duração estimada do rollback: <X min>

Janela de deploy: <data/hora atual>
Monitoramento pós-deploy: 15 minutos via `wrangler tail`

Para autorizar, digite exatamente:

  DEPLOY PRODUÇÃO <ID da tarefa>

Ex: DEPLOY PRODUÇÃO G-20260915-001

Para cancelar, qualquer outra resposta.
═══════════════════════════════════════════════════════════
```

Se a resposta não corresponder exatamente, **cancele**:

```text
Deploy cancelado. Nenhuma alteração foi feita em produção.
```

Se corresponder, prossiga.

### Passo 10 — Deploy em produção

Execute:

```bash
# Aplicar migration em produção
pnpm wrangler d1 migrations apply DB --env production

# Deploy do Worker
pnpm deploy:prod
```

Capture a saída e registre:
- Versão deployada
- Timestamp
- Hash do commit

### Passo 11 — Monitoramento pós-deploy

Inicie o monitoramento:

```bash
# Em background
wrangler tail --env production --format json > /tmp/sveflare-tail.log &

# Registrar PID
echo $! > /tmp/sveflare-tail.pid
```

Anuncie:

```text
✅ Deploy em produção concluído.

Monitorando por 15 minutos. Vou reportar:
- Erros 5xx
- Latência anormal (p95 > 2s)
- Taxa de erro por endpoint
- Chamadas LLM com falha (se aplicável)

Você pode continuar trabalhando enquanto isso.
```

Enquanto monitora, a cada 3 minutos, reporte:

```text
📊 Status aos <N> minutos:
- Erros 5xx: <N>
- Latência p95: <X>ms
- Endpoints com falha: <lista ou "nenhum">
```

Se detectar anomalia (>5 erros 5xx em 1 min, ou p95 > 2s
sustentado):

```text
🚨 ANOMALIA DETECTADA

- Erro: <descrição>
- Frequência: <N> ocorrências em <janela>
- Endpoint: <path>

Recomendação:
a) Reverter imediatamente: `wrangler rollback --env production`
b) Investigar por mais 2 minutos antes de decidir
c) Ignorar (aceito o risco)

O que fazer?
```

Aguarde decisão do usuário.

### Passo 12 — Encerrar monitoramento

Após 15 minutos sem anomalias:

```bash
# Encerrar o tail
kill $(cat /tmp/sveflare-tail.pid) 2>/dev/null || true
```

Reporte:

```text
✅ Monitoramento concluído — 15 minutos sem anomalias.

Estatísticas do período:
- Requests totais: <N>
- Erros 5xx: <N> (<percentual>%)
- Latência p95: <X>ms
- Latência p99: <Y>ms

Deploy considerado bem-sucedido.
```

### Passo 13 — Fechar o goal

Atualize `.agents/goals/current.md`:

```markdown
## 14. Fechamento

**Concluído em:** <YYYY-MM-DD HH:MM>
**Status final:** `concluído`
**Subagente Judge aprovou:** sim
**Security Auditor aprovou:** sim
**Evidências anexadas:**
- Relatório de /sveflare-verify (VERDE)
- Relatório do Security Auditor
- Decisão do Judge
- Smoke test staging (passou)
- Deploy produção (versão <X>, commit <hash>)
- Monitoramento 15min (sem anomalias)
**PR:** #<número>

### Retrospectiva breve

- **O que funcionou bem:** <preenchido pelo usuário>
- **O que poderia melhorar:** <preenchido pelo usuário>
- **Lição aprendida:** <preenchido pelo usuário>
```

Pergunte ao usuário:

```text
Deploy em produção concluído com sucesso.

Última etapa: retrospectiva breve.

1. O que funcionou bem nesta feature?
2. O que poderia melhorar?
3. Alguma lição para registrar em $DSH_HOME/memory/?

Responda (ou digite "pular" para finalizar sem retrospectiva).
```

Se o usuário responder, registre. Se pular, finalize.

### Passo 14 — Relatório final

Apresente:

```markdown
# Deploy concluído — <nome da feature>

**Data:** <YYYY-MM-DD HH:MM>
**Duração total do /sveflare-ship:** <X> minutos

## Resumo

| Etapa | Status | Duração |
|-------|--------|---------|
| Security Auditor | ✅ aprovado | Xs |
| Judge | ✅ aprovado | Xs |
| Deploy staging | ✅ concluído | Xs |
| Smoke staging | ✅ passou | Xs |
| Aprovação humana | ✅ obtida | — |
| Deploy produção | ✅ concluído | Xs |
| Monitoramento 15min | ✅ sem anomalias | 15min |

## Artefatos

- **Commit:** <hash>
- **Versão deployada:** <versão>
- **URL produção:** https://myapp.pages.dev
- **PR:** #<número>

## Próximos passos

1. Comunique o time que a feature está em produção.
2. Monitore o dashboard nas próximas 24h.
3. Se houver issue, use o rollback plan documentado.
4. Registre lições em $DSH_HOME/memory/ (se houver).
5. Abra o próximo goal em `.agents/goals/current.md`.
```

## Comportamento em casos especiais

### Se o usuário não estiver presente para aprovação

Pare em `APROVAÇÃO PARA DEPLOY EM PRODUÇÃO` e aguarde. Não prossiga
sem resposta.

Se após 5 minutos não houver resposta, cancele:

```text
⏱️ Timeout de 5 minutos sem resposta. Deploy cancelado.

Rode /sveflare-ship novamente quando estiver pronto para aprovar.
```

### Se o deploy em staging falhar

```text
❌ Deploy em staging falhou.

Saída:
<trecho relevante>

Investigue:
1. Logs do wrangler
2. Configuração do wrangler.staging.toml
3. Se a migration falhou, verifique se o schema está correto

Após corrigir, rode /sveflare-ship novamente.
```

Pare.

### Se a migration de produção for irreversível

Se a migration inclui `DROP TABLE` ou `DROP COLUMN`:

```text
⚠️  ATENÇÃO: A migration contém operações irreversíveis:

<lista de operações>

Antes de prosseguir:
1. Faça backup do banco: `wrangler d1 export DB --env production --output backup.sql`
2. Confirme que o backup é válido
3. Documente o plano de restauração

Autorizar mesmo assim? Digite:

  DEPLOY PRODUÇÃO IRREVERSÍVEL <ID da tarefa>
```

Exija dupla confirmação.

### Se o smoke test retornar avisos

Se o smoke test passar mas com avisos (headers ausentes, latência
alta):

```text
⚠️  Smoke test passou com avisos:

<lista>

Avisos não bloqueiam o deploy, mas devem ser registrados como
débito técnico. Continuar? [s/n]
```

### Se houver `--no-approval-gate`

Se o usuário passou essa flag:

```text
⚠️  Você desativou o approval gate. Isso é perigoso.

Confirme duas vezes:

1. Você tem autorização do time para fazer deploy automático?
2. Há monitoramento automático que fará rollback se algo falhar?

Digite "CONFIRMO DEPLOY AUTOMÁTICO" para prosseguir.
```

Registre essa decisão no log e no goal.

### Se o usuário pedir rollback pós-deploy

Se após o deploy o usuário reportar problema:

```text
Executando rollback...

1. `wrangler rollback --env production`
2. Reverter migration (se aplicável):
   `wrangler d1 execute DB --env production --command "<SQL de rollback>"`
3. Confirmar com smoke test: `pnpm smoke production`

Aguarde...
```

Após rollback, rode smoke test e reporte.

## Evidências de conclusão

Antes de declarar o comando concluído:

- [ ] Pré-deploy confirmado (4 itens).
- [ ] `/sveflare-verify` retornou VERDE (ou --skip-verify passado).
- [ ] Security Auditor aprovou.
- [ ] Judge aprovou.
- [ ] Deploy em staging concluído.
- [ ] Smoke test em staging passou.
- [ ] Aprovação humana obtida (ou --no-approval-gate confirmado).
- [ ] Deploy em produção concluído.
- [ ] Monitoramento 15 min executado.
- [ ] Sem anomalias (ou rollback executado).
- [ ] Goal marcado como `concluído`.
- [ ] Retrospectiva registrada (ou pulada).
- [ ] Relatório final apresentado.
- [ ] `.agents/goals/current.md` atualizado.
- [ ] Log de deploy salvo em `/tmp/sveflare-deploy.log`.

## Exemplos de uso

### Exemplo 1 — Fluxo completo

```text
/sveflare-ship
```

**Resultado:** valida, faz deploy em staging, roda smoke, pede
aprovação, faz deploy em produção, monitora 15 min.

### Exemplo 2 — Apenas staging

```text
/sveflare-ship --staging-only
```

**Resultado:** valida e faz deploy em staging, mas para antes da
aprovação de produção.

### Exemplo 3 — Pular verify (assumindo que já rodou)

```text
/sveflare-ship --skip-verify
```

**Resultado:** pula a re-execução do `/sveflare-verify`, assumindo que
o usuário rodou recentemente e nada mudou.

### Exemplo 4 — Após correção

```text
/sveflare-ship
```

**Resultado:** re-valida tudo desde o início.

## Fluxo completo do SDLC

```text
1. /sveflare-spec   → docs/SPEC.md
2. /sveflare-plan   → docs/PLAN.md
3. /sveflare-goal   → .agents/goals/current.md (por tarefa)
4. (implementação)
5. /sveflare-verify → relatório de verificação
6. /sveflare-ship   → deploy + monitoramento
```

## Diferença entre `/sveflare-verify` e `/sveflare-ship`

| Aspecto | `/sveflare-verify` | `/sveflare-ship` |
|---------|---------------------|-------------------|
| Propósito | Rodar verificações | Decidir e deployar |
| Chama subagentes? | Não | Sim (Security Auditor, Judge) |
| Faz deploy? | Não | Sim (staging + prod com aprovação) |
| Requer aprovação humana? | Não | Sim (para prod) |
| Monitora pós-deploy? | Não | Sim (15 min) |
| Quando usar | A cada iteração | Ao final da feature |

## Referências

- `scripts/verify.sh` — pipeline principal.
- `scripts/security-scan.sh` — segurança.
- `scripts/owasp-check.sh` — OWASP Top 10.
- `scripts/complexity-check.sh` — complexidade.
- `scripts/smoke-test.sh` — smoke pós-deploy.
- `.agents/commands/sveflare-verify.md` — comando anterior.
- `.agents/skills/security-leaks/SKILL.md` — categorias de vazamento.
- `.agents/skills/cloudflare-security/SKILL.md` — hardening.
- `AGENTS.md` — Security Gates e Step Verification.
- `docs/SETUP.md` — seção 9 (verificação) e 10 (troubleshooting).
- `docs/USAGE.md` — fluxo completo de uso.
