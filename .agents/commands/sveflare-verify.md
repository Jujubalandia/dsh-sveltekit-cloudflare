---
name: sveflare-verify
description: Roda o pipeline completo de verificação (check, lint, testes, build, e2e, security, complexity) e consolida os resultados em um relatório. Consulta o goal ativo para validar que as evidências esperadas foram produzidas.
argument-hint: [--fast] [--security-only] [--complexity-only]
allowed-tools: bash, read, grep
model: deepseek-chat
---

# /sveflare-verify — Pipeline completo de verificação

Você está rodando a verificação completa do projeto. O objetivo é
executar todas as camadas de validação e apresentar um relatório
consolidado que permita ao usuário (ou ao Judge) decidir se o
trabalho está pronto.

Este comando é **determinístico**: não toma decisões, apenas executa
scripts e reporta.

## Pré-requisitos

Confirme antes de prosseguir:

1. `node_modules/` está instalado (`pnpm install` já rodou).
2. Os scripts em `scripts/` estão executáveis (`chmod +x`).
3. Você está no root do projeto (onde está o `package.json`).

Se algum item falhar, pare e informe.

## Argumentos recebidos

```
$ARGUMENTS
```

Flags suportadas:

- `--fast` — roda check + lint + unit + build, pulando e2e.
- `--security-only` — roda apenas `security-scan.sh`.
- `--complexity-only` — roda apenas `complexity-check.sh`.
- (vazio) — roda tudo.

Se a flag for desconhecida, ignore e rode tudo.

## Restrições

- NÃO altere arquivos (nem código, nem config).
- NÃO corrija problemas automaticamente. Apenas reporte.
- NÃO faça commit nem push.
- NÃO faça deploy.
- Se um script falhar, **continue** rodando os outros (não aborte).
- Se um script travar (>5 min), registre timeout e siga.

## Fluxo de execução

### Passo 1 — Ler o goal ativo

Leia `.agents/goals/current.md` para saber:

- Qual tarefa está em execução.
- Quais evidências são esperadas (seção 9).
- Quais gates são aplicáveis (seção 6).
- Quais skills foram carregadas (seção 5).

Se o goal estiver vazio ou não existir, avise:
```text
⚠️  Nenhum goal ativo em .agents/goals/current.md. A verificação será
executada sem critério de comparação.
```
E prossiga mesmo assim.

### Passo 2 — Determinar escopo

Conforme o argumento:

| Argumento | Etapas executadas |
|-----------|-------------------|
| (vazio) | verify.sh + security-scan.sh + complexity-check.sh |
| `--fast` | verify.sh --fast + security-scan.sh + complexity-check.sh |
| `--security-only` | security-scan.sh |
| `--complexity-only` | complexity-check.sh |

### Passo 3 — Executar verificações

Para cada etapa, anuncie antes:

```text
▶ Executando: <nome do script>
```

Redirecione a saída para arquivos temporários para poder consolidar:

```bash
./scripts/verify.sh <flags> > /tmp/sveflare-verify.log 2>&1
echo "exit_code=$?"
```

Mesmo se um script falhar (exit != 0), continue para o próximo.

Registre para cada etapa:
- Nome
- Exit code
- Duração (segundos)
- Caminho do log
- Status (passou / falhou / timeout)

### Passo 4 — Comparar com o goal

Se havia goal ativo, valide:

1. **Evidências esperadas (seção 9):** cada item foi produzido?
   - `pnpm check` rodou? Passou?
   - `pnpm lint` rodou? Passou?
   - Testes rodaram? Passaram?
   - `security:scan` rodou (se aplicável)? Passou?
   - `complexity:scan` rodou (se aplicável)? Passou?

2. **Critérios de aceitação (seção 3):** para cada CA:
   - Existe teste que valida?
   - Se sim, o teste passou?

3. **Security Gates (seção 6):** para cada gate marcado:
   - A verificação automatizada correspondente passou?
   - Se não há verificação automatizada, sinalize como "não verificável
     automaticamente".

### Passo 5 — Consolidar relatório

Apresente o seguinte formato:

```markdown
# Relatório de verificação

**Data:** <YYYY-MM-DD HH:MM>
**Goal ativo:** <ID> — <descrição curta> (ou "nenhum")
**Escopo:** <verify completo | --fast | --security-only | --complexity-only>

---

## Etapas executadas

| Etapa | Comando | Status | Duração |
|-------|---------|--------|---------|
| Type check | `pnpm check` | ✅ / ❌ | Xs |
| Lint | `pnpm lint` | ✅ / ❌ | Xs |
| Unit tests | `pnpm test:coverage` | ✅ / ❌ | Xs |
| Build | `pnpm build` | ✅ / ❌ | Xs |
| E2E | `pnpm test:e2e` | ✅ / ❌ | Xs |
| Secrets scan | `gitleaks` | ✅ / ❌ | Xs |
| Dependency audit | `pnpm audit` | ✅ / ⚠️ / ❌ | Xs |
| OWASP check | `owasp-check.sh` | ✅ / ⚠️ / ❌ | Xs |
| Complexity check | `complexity-check.sh` | ✅ / ⚠️ / ❌ | Xs |

**Legenda:**
- ✅ passou
- ⚠️  passou com avisos
- ❌ falhou
- ⏱️ timeout
- ⏭️ pulado (conforme flag)

---

## Resultado consolidado

**Status geral:** ✅ VERDE / ⚠️ AMARELO / ❌ VERMELHO

- **VERDE:** todas as etapas ✅.
- **AMARELO:** pelo menos uma ⚠️, nenhuma ❌.
- **VERMELHO:** pelo menos uma ❌.

---

## Problemas encontrados

### Bloqueantes (❌)

1. **<etapa>: <descrição>**
   - Localização: `<arquivo:linha>` (se aplicável)
   - Comando para reproduzir: `<comando>`
   - Saída relevante:
     ```text
     <trecho da saída>
     ```
   - Sugestão de correção: `<sugestão>`

2. ...

### Avisos (⚠️)

1. **<etapa>: <descrição>**
   - Impacto: <baixo | médio | alto>
   - Recomendação: <ação>

2. ...

---

## Comparação com o goal

**Goal ativo:** <ID>

### Evidências esperadas

- [x] `pnpm check` — produzida, passou
- [x] `pnpm lint` — produzida, passou
- [ ] `pnpm test:coverage` — produzida, **falhou** em <arquivo>
- [x] `security:scan` — produzida, passou
- [x] Relatório do Verifier — **ainda não executado**

### Critérios de aceitação

| CA | Testável? | Passou? | Evidência |
|----|-----------|---------|-----------|
| CA-1 | sim | ✅ | `tests/unit/upload.test.ts:42` |
| CA-2 | sim | ❌ | teste `should reject invalid type` falhou |
| CA-3 | parcial | ⚠️ | apenas teste manual |

### Security Gates

| Gate | Aplicável | Verificado | Status |
|------|-----------|-----------|--------|
| Gate 1 (Secrets) | sim | sim | ✅ |
| Gate 2 (Input) | sim | sim | ✅ |
| Gate 3 (D1) | sim | sim | ✅ |
| Gate 4 (R2) | sim | parcial | ⚠️  falta validar ownership |

---

## Próximos passos recomendados

Se **VERDE**:
1. Se o goal está completo, marque-o como `concluído` em
   `.agents/goals/current.md`.
2. Se há subagente Verifier disponível, rode-o para verificação
   independente antes de declarar conclusão.
3. Quando pronto, rode `/sveflare-ship` para validar e deployar.

Se **AMARELO**:
1. Revise os avisos listados.
2. Se algum aviso é aceitável no contexto, documente a decisão em
   `.agents/goals/current.md`, seção 13 (Notas de execução).
3. Rode `/sveflare-verify` novamente após os ajustes.

Se **VERMELHO**:
1. NÃO prossiga para `/sveflare-ship`.
2. Corrija os bloqueantes listados.
3. Rode `/sveflare-verify` novamente.

---

## Logs completos

Logs salvos em:
- `/tmp/sveflare-verify.log` — verify.sh
- `/tmp/sveflare-security.log` — security-scan.sh
- `/tmp/sveflare-complexity.log` — complexity-check.sh

Para inspecionar: `cat /tmp/sveflare-verify.log`
```

## Comportamento em casos especiais

### Se o goal não existir

Ainda rode a verificação, mas omita a seção "Comparação com o goal"
do relatório e adicione:

```text
⚠️  Nenhum goal ativo. A verificação foi executada em modo
"diagnóstico" — sem critérios de comparação.
```

### Se um script não existir

Se `scripts/verify.sh` (ou outro) não estiver presente:

```text
⏭️  scripts/verify.sh não encontrado. Pulando esta etapa.
```

Registre no relatório como `⏭️ pulado (script ausente)`.

### Se um script não for executável

Se `chmod +x` ainda não foi feito:

```text
⚠️  scripts/verify.sh não é executável. Rodando via `bash scripts/verify.sh`.
```

Tente executar com `bash <script>` como fallback.

### Se `pnpm` não estiver disponível

```text
❌ pnpm não encontrado no PATH. Não é possível rodar as verificações.

Soluções:
- Instale pnpm: `corepack enable && corepack prepare pnpm@9 --activate`
- Ou rode em um ambiente com pnpm disponível.
```

Pare o comando.

### Se um script travar (>5 min)

Use timeout:

```bash
timeout 300 ./scripts/verify.sh || echo "TIMEOUT após 300s"
```

Registre como `⏱️ timeout`.

### Se o goal tiver CAs não cobertos por teste

Para cada CA sem teste correspondente:

```text
⚠️  CA-<N> não tem teste automatizado. Verificação manual necessária:
   <descrição do que inspecionar>
```

Registre como `⚠️ parcial` na tabela de CAs.

### Se houver goal com loop ativo

Se a seção 11 do goal tem "Goal loop" habilitado:

- Rode a verificação.
- Se falhar, **não pare**. Registre no relatório:
  ```text
  🔁 Loop ativo: tentativa <N>/<max>. Repetindo após correção.
  ```
- Aguarde o usuário corrigir e rode novamente.

### Se houver suspeita de falso positivo em `pnpm audit`

Se o único bloqueante for `pnpm audit`:

```text
⚠️  pnpm audit reportou vulnerabilidades. Antes de tratar como
bloqueante, verifique se são exploráveis no contexto do projeto:
- A dependência é usada em runtime ou apenas em dev?
- A vulnerabilidade tem exploit conhecido no nosso caso?
- Há fix disponível? Se sim, qual?

Se não for explorável, documente a decisão em .agents/goals/current.md
e marque como aviso, não bloqueante.
```

## Evidências de conclusão

Antes de declarar o comando concluído:

- [ ] Todas as etapas do escopo foram executadas (ou registradas como
      puladas).
- [ ] Logs salvos em `/tmp/sveflare-*.log`.
- [ ] Relatório consolidado apresentado ao usuário.
- [ ] Status geral calculado (VERDE / AMARELO / VERMELHO).
- [ ] Comparação com o goal feita (se goal existia).
- [ ] Próximos passos recomendados conforme status.
- [ ] Nenhum arquivo do projeto foi alterado.
- [ ] Nenhum commit ou deploy foi feito.

## Exemplos de uso

### Exemplo 1 — Verificação completa

```text
/sveflare-verify
```

**Resultado:** roda tudo (check + lint + test + build + e2e + security
+ complexity), consolidando em um relatório.

### Exemplo 2 — Verificação rápida (sem e2e)

```text
/sveflare-verify --fast
```

**Resultado:** pula e2e, roda o resto. Útil durante desenvolvimento
iterativo.

### Exemplo 3 — Apenas segurança

```text
/sveflare-verify --security-only
```

**Resultado:** roda `security-scan.sh` apenas.

### Exemplo 4 — Antes de deploy

```text
/sveflare-verify
```

**Resultado esperado:** VERDE. Se AMARELO ou VERMELHO, corrija antes de
`/sveflare-ship`.

## Diferença entre `/sveflare-verify` e `/sveflare-ship`

| Aspecto | `/sveflare-verify` | `/sveflare-ship` |
|---------|---------------------|-------------------|
| Propósito | Rodar verificações | Decidir e deployar |
| Determina status? | Sim (VERDE/AMARELO/VERMELHO) | Sim, mas com Judge |
| Faz deploy? | Não | Sim (staging + prod com aprovação) |
| Chama subagentes? | Não | Sim (Security Auditor, Judge) |
| Requer aprovação humana? | Não | Sim (para prod) |
| Quando usar | A cada iteração | Ao final da feature |
| Duração | 1-3 min | 5-15 min |

## Referências

- `scripts/verify.sh` — pipeline principal.
- `scripts/security-scan.sh` — verificação de segurança.
- `scripts/owasp-check.sh` — OWASP Top 10.
- `scripts/complexity-check.sh` — complexidade.
- `.agents/commands/sveflare-goal.md` — comando que trava o goal.
- `.agents/commands/sveflare-ship.md` — próximo comando no fluxo.
- `AGENTS.md` — Step Verification (seção 9).
- `docs/USAGE.md` — fluxo completo de uso.
