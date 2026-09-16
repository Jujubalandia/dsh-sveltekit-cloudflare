# HARNESS.md — Harness de agentes com DeepSeek

Guia completo sobre o harness de agentes deste projeto: o que é, como
funciona, como configurar no DeepSeek Harness (DSH), como estender, e
como reutilizar em novos projetos.

**Público-alvo:**
- Desenvolvedores que querem entender o sistema de agentes.
- Times avaliando adotar o harness em outros repositórios.
- Quem quer estender (novas skills, subagentes, hooks).

**Tempo de leitura:** ~30 minutos.

**Pré-requisitos:** ter completado `docs/SETUP.md`.

---

## Índice

1. [O que é um harness](#1-o-que-é-um-harness)
2. [Arquitetura](#2-arquitetura)
3. [Instalação do DSH](#3-instalação-do-dsh)
4. [Como o harness carrega os arquivos](#4-como-o-harness-carrega-os-arquivos)
5. [Configuração: harness.config.yml](#5-configuração-harnessconfigyml)
6. [Fluxo do agente](#6-fluxo-do-agente)
7. [Como criar uma nova skill](#7-como-criar-uma-nova-skill)
8. [Como adicionar um subagente](#8-como-adicionar-um-subagente)
9. [Bootstrap em novo projeto](#9-bootstrap-em-novo-projeto)
10. [Checklist de adoção](#10-checklist-de-adoção)

---

## 1. O que é um harness

### Definição

Um **harness** é a infraestrutura ao redor de um modelo de linguagem
que o transforma de "chatbot" em "agente que executa tarefas de
engenharia com segurança".

> "Agente = modelo + harness. O modelo é 10% do resultado; o harness
> é 90%." — Addy Osmani, *The New SDLC with Vibe Coding*

### Sem harness

```text
Você → LLM → resposta em texto → você aplica manualmente
```

Problemas:
- Sem verificação automática.
- Sem restrição de escrita.
- Sem memória entre sessões.
- Sem auditoria do que foi feito.
- Resultado depende da sua disciplina.

### Com harness

```text
Você → DSH → [router → skills → hooks → tools → verifier] → resultado auditável
```

Vantagens:
- **Skills** carregadas sob demanda (contexto especializado).
- **Hooks** que rodam verificação antes/depois de cada edição.
- **Subagentes** com papéis distintos (drafter vs verifier).
- **Gates** que bloqueiam ações inseguras (secrets, deploy em prod).
- **Memória** que acumula aprendizado entre sessões.
- **Goals** versionados que travam o critério de "concluído".

### Por que este stack

SvelteKit + Cloudflare (Workers, D1, KV, R2, AI Gateway) é um stack
moderno, distribuído, com múltiplas superfícies de segurança. Sem
harness, é fácil introduzir bugs de segurança (SQL injection em D1,
PII em logs, secrets hardcoded) e difícil garantir qualidade.

O harness deste kit cobre especificamente:

| Área | Como o harness protege |
|------|------------------------|
| Secrets | `gitleaks` no pre-commit e CI, mais `security-leaks` skill |
| SQL injection | Skill `cloudflare-d1` + OWASP check A03 |
| PII em logs | Skill `security-leaks` + OWASP check A09 |
| Prompt injection | Skill `cloudflare-ai-gateway` + OWASP check A03 |
| Complexidade | `complexity-check.sh` com thresholds |
| Código morto | `knip` no complexity check |
| Testes fracos | Mutation testing com Stryker |
| Deploy inseguro | Approval gate + staging obrigatório |
| Review de agentes | Skill `agentic-code-review` + subagente verificador |

---

## 2. Arquitetura

### Camadas

```text
┌─────────────────────────────────────────────────────────────┐
│  Sistema / Developer instructions (DSH)                     │
├─────────────────────────────────────────────────────────────┤
│  AGENTS.md (project root)                                   │
│    → regras operacionais do projeto                         │
├─────────────────────────────────────────────────────────────┤
│  .agents/skills/*/SKILL.md                                  │
│    → contexto especializado carregado sob demanda           │
├─────────────────────────────────────────────────────────────┤
│  .agents/goals/current.md                                   │
│    → critérios de aceitação versionados por tarefa          │
├─────────────────────────────────────────────────────────────┤
│  harness.config.yml                                         │
│    → subagentes, hooks, sandbox, review tiers               │
├─────────────────────────────────────────────────────────────┤
│  scripts/*.sh                                               │
│    → verificações determinísticas (verify, security, etc.)  │
├─────────────────────────────────────────────────────────────┤
│  .github/workflows/*.yml                                    │
│    → gates no CI (invariantes do projeto)                   │
└─────────────────────────────────────────────────────────────┘
```

**Regra de ouro:** cada camada **influencia** o comportamento, mas só
as duas últimas (scripts + CI) **forçam**. Documentação é intenção;
enforcement é o que executa.

### Hierarquia de precedência (quando há conflito)

```text
System/Developer (DSH)
  > Direct user request
    > AGENTS.md global ($DSH_HOME)
      > AGENTS.md do projeto
        > AGENTS.md aninhado (subdiretório)
          > Skill carregada explicitamente
```

Quando uma skill conflita com o `AGENTS.md` do projeto, o `AGENTS.md`
ganha. Skills são **especializações**, não overrides.

### Componentes

| Componente | Onde fica | Papel |
|------------|-----------|-------|
| AGENTS.md | `./AGENTS.md` | Regras operacionais do projeto |
| Skills | `.agents/skills/*/SKILL.md` | Contexto especializado |
| Goals | `.agents/goals/current.md` | Critérios versionados por tarefa |
| Config | `harness.config.yml` | Subagentes, hooks, sandbox |
| Scripts | `scripts/*.sh` | Verificações determinísticas |
| CI | `.github/workflows/*.yml` | Gates de merge |

---

## 3. Instalação do DSH

### 3.1 — O que é o DSH

DeepSeek Harness (DSH) é o ambiente que executa o agente. Ele carrega
o `AGENTS.md`, as skills, os hooks e os subagentes definidos neste kit.

**Nota:** o DSH é instalado como ferramenta separada (não via `pnpm`).
Consulte a documentação oficial do DeepSeek Harness para o método
de instalação atualizado.

### 3.2 — Estrutura do `$DSH_HOME`

O DSH armazena configuração global em `$DSH_HOME` (por padrão
`~/.deepseek-harness/` ou similar):

```text
$DSH_HOME/
├── AGENTS.md                  # regras globais (todos os projetos)
├── config.yml                 # config global
├── skills/                    # skills globais
├── projects/
│   ├── sveltekit-cloudflare/
│   │   └── harness.config.yml # copiado deste kit
│   └── outro-projeto/
│       └── harness.config.yml
└── memory/
    ├── INDEX.md               # índice de memória
    └── cards/                 # cartões de memória (decisões, lições)
```

### 3.3 — Configurar o projeto no DSH

**Passo 1:** criar diretório do projeto no DSH

```bash
mkdir -p $DSH_HOME/projects/sveltekit-cloudflare
```

**Passo 2:** copiar o `harness.config.yml`

```bash
cp harness.config.yml $DSH_HOME/projects/sveltekit-cloudflare/
```

**Passo 3:** verificar que o DSH encontra o `AGENTS.md` do projeto

O DSH detecta automaticamente o `AGENTS.md` no root do repositório
quando você inicia uma sessão dentro dele. Não é preciso copiar.

```bash
cd /caminho/do/projeto
ls -la AGENTS.md   # deve existir
```

**Passo 4:** configurar permissões de hooks (se o DSH pedir)

Alguns hooks podem exigir aprovação explícita na primeira execução.
Verifique a documentação do DSH sobre "trusted hooks".

### 3.4 — Verificar

Inicie uma sessão do DSH dentro do projeto:

```bash
cd /caminho/do/projeto
dsh    # ou o comando que o DSH expõe
```

Dentro da sessão, pergunte ao agente:

```text
Leia AGENTS.md e me diga quantas Security Gates existem.
```

Se o agente responder "8 gates" (ou o número correto do seu
`AGENTS.md`), o harness está carregando.

---

## 4. Como o harness carrega os arquivos

### 4.1 — Ordem de carregamento

Quando você inicia uma sessão, o DSH carrega:

```text
1. System prompt (DSH internals)
2. Developer instructions (config DSH)
3. $DSH_HOME/AGENTS.md (regras globais)
4. ./AGENTS.md (regras do projeto) ← este kit fornece
5. ./subdir/AGENTS.md (se você navegar em subdiretório)
```

Skills **não** são carregadas automaticamente. Elas são carregadas
sob demanda:
- Explicitamente: `useSkill('cloudflare-d1')`.
- Automaticamente: o agente detecta o contexto (ex: editando arquivo em
  `workers/src/db/`) e carrega a skill correspondente.

### 4.2 — O que é carregado quando

| Momento | O que é carregado |
|---------|-------------------|
| Início da sessão | System + AGENTS.md global + AGENTS.md do projeto |
| Entrada em subdiretório | AGENTS.md aninhado (se existir) |
| Tarefa de domínio específico | Skill relevante |
| Início de tarefa | `.agents/goals/current.md` |
| Antes de editar arquivo | `scripts/pre-edit-check.sh` |
| Depois de editar arquivo | `scripts/post-edit-check.sh` |
| Antes de PR | `scripts/verify.sh` + `security-scan.sh` + `owasp-check.sh` + `complexity-check.sh` |
| Antes de deploy prod | `security-scan.sh` + approval gate |
| Depois de deploy | `scripts/smoke-test.sh` |

### 4.3 — Custo de contexto

Skills são carregadas sob demanda justamente para não inflar o
contexto. Carregar todas as 12 skills de uma vez consumiria ~15k
tokens. Carregar 2–3 por tarefa mantém o contexto enxuto.

**Regra prática:** 2–3 skills por tarefa. Se precisar de mais, é sinal
de que a tarefa deveria ser dividida.

### 4.4 — Precedência em conflito

Se uma skill disser "sempre use prepared statements" e o `AGENTS.md`
disser "para queries internas, use template strings", o `AGENTS.md`
ganha. **Skills são especializações, não overrides.**

Exceção: se você carregar uma skill **explicitamente** e ela contradiz
o `AGENTS.md` **nessa tarefa específica**, prevalece a skill — mas o
agente deve sinalizar o conflito.

---

## 5. Configuração: harness.config.yml

O `harness.config.yml` define como o harness se comporta. Está
organizado em 6 seções.

### 5.1 — project

```yaml
project:
  name: sveltekit-cloudflare
  root: .
  agent_file: AGENTS.md
  skills_dir: .agents/skills
  goals_dir: .agents/goals
```

Metadados. Aponta para onde estão os arquivos. Se você renomear
`AGENTS.md` para `AGENT.md`, atualize `agent_file` aqui.

### 5.2 — subagents

Define os papéis de agentes que cooperam numa tarefa.

```yaml
subagents:
  drafter:
    model: deepseek-chat
    tools: [edit_file, write_file, bash]
    description: "Implementa a mudança"

  verifier:
    model: deepseek-chat
    tools: [read_file, bash, grep]
    description: "Verifica independentemente. Não confia no drafter."
    system_prompt: |
      Você é um verificador independente. Nunca assuma que o drafter
      está correto. Execute os testes, leia o código, procure por
      testes reescritos para passar, CI enfraquecido, validação
      faltando, secrets hardcoded e input não confiável indo para LLM.

  judge:
    model: deepseek-reasoner
    tools: [read_file, read_evidence]
    description: "Decide se a tarefa está pronta com base em evidências."
```

**Princípio:** "One sub-agent drafts the change. A separate one
verifies it." — Addy Osmani.

> **Nota sobre o DSH real:** papéis nomeados como estes **não** são
> declarados em `harness.config.yml`. O `@deepseek-ai/dsh-subagent` é o
> Service Definition do seam `ctx.subagents` e não expõe config `agents`.
> O mecanismo nativo para papéis é **Agent Presets** — um diretório com
> `agent.cordis.yml`, descoberto pelos preset roots. O bloco abaixo
> documenta a **intenção de design** (um rascunha, outro verifica), que na
> prática se realiza chamando a tool `subagent` com prompts distintos.

**Escolha de modelo:**
- `deepseek-chat` — rápido, bom para drafting e verificação.
- `deepseek-reasoner` — mais lento, melhor para juiz (decisões
  complexas com base em evidências).

### 5.3 — hooks

Os hooks deste kit são registrados pelo bridge
`@deepseek-ai/dsh-hooks-claude-code`, inserido como linha de bundle em
`cordis.patch.yml` e configurado por `.agents/hooks.json`:

```yaml
- insert:
    - id: sveltekit-cloudflare-hooks
      name: '@deepseek-ai/dsh-hooks-claude-code'
      config:
        configPath: './.agents/hooks.json'
```

O arquivo usa o formato do Claude Code. O payload do evento chega como
**JSON no stdin** do comando — não como argumento posicional. Por isso os
comandos chamam `scripts/hook-dispatch.mjs`, que extrai
`tool_input.file_path` e injeta a saída do check no contexto do modelo via
`hookSpecificOutput.additionalContext`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "edit|write|str_replace",
        "hooks": [
          {
            "type": "command",
            "command": "node \"$CLAUDE_PROJECT_DIR/scripts/hook-dispatch.mjs\" \"$CLAUDE_PROJECT_DIR/scripts/pre-edit-check.sh\"",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

**Eventos suportados pelo bridge:**

| Hook | Quando dispara |
|------|----------------|
| `SessionStart` | Ao iniciar a sessão |
| `UserPromptSubmit` | Quando você envia uma mensagem |
| `PreToolUse` | Antes de uma tool call |
| `PostToolUse` | Depois de uma tool call |
| `Stop` | Ao encerrar o turno |
| `SubagentStart` | Ao iniciar um subagente |
| `SubagentStop` | Ao encerrar um subagente |

O matcher casa contra o **nome da tool** (`edit`, `write`, ...), e
`CLAUDE_PROJECT_DIR` é exportado no ambiente do processo do hook.

**Contrato de saída:** exit `2` **bloqueia**, com o stderr virando o
motivo; qualquer outro exit é erro não-bloqueante. Os checks deste kit são
guias, não gates rígidos — `hook-dispatch.mjs` sempre sai com código 0.

**PreCommit, PrePR, PreDeploy e PostDeploy não são eventos do bridge.**
Eles vivem onde a ação realmente acontece:

| Gate | Onde vive |
|------|-----------|
| PreCommit | `.husky/pre-commit` |
| PrePR | `.husky/pre-push` |
| PreDeploy / PostDeploy | `.github/workflows/` |

**Regra:** hooks devem ser **rápidos**. Verificações longas (lint, testes,
scan de segurança) vão para os hooks de git ou para o CI.

### 5.4 — goals

```yaml
goals:
  verification:
    enabled: true
    criteria_file: .agents/goals/current.md
    require_evidence: true
    require_independent_verification: true
  loops:
    goal: { enabled: true, max_attempts: 5 }
    time: { enabled: true, default_interval: 5m }
    proactive: { enabled: false }
```

**Verificação:** o agente não pode declarar "concluído" sem:
1. Critérios de aceitação atendidos.
2. Evidências registradas (outputs, screenshots).
3. Verificação independente por subagente.

**Loops:**
- **Goal** — repete até critério determinístico ou N tentativas.
- **Time** — verifica PR/CI a cada X minutos.
- **Proactive** — triagem agendada (desabilitado por padrão).

### 5.5 — sandbox

```yaml
sandbox:
  allowed_write_paths:
    - "src/"
    - "workers/"
    - "tests/"
    - "migrations/"
    - "scripts/"
    - ".agents/skills/"
    - ".agents/goals/"
    - "docs/"
  deny_write_paths:
    - ".env"
    - ".env.*"
    - "wrangler.toml"
    - "wrangler.production.toml"
    - ".github/workflows/deploy-production.yml"
    - ".gitleaks.toml"
  network: false
  allow_shell: true
  allow_git: true
```

**Objetivo:** limitar o raio de ação do agente. Mesmo que ele "queira"
editar `.env`, o sandbox bloqueia.

**`deny_write_paths`** inclui arquivos críticos que exigem revisão
humana mesmo se o agente quiser modificá-los.

### 5.6 — review

```yaml
review:
  tiers:
    fast:     { when: "PR < 100 linhas, sem auth/DB/IA", action: "revisão leve" }
    normal:   { when: "PR < 400 linhas, sem auth", action: "revisão normal" }
    heavy:    { when: "toca auth/D1/IA/R2", action: "revisão pesada + security_auditor" }
    critical: { when: "deploy prod ou migração D1", action: "revisão humana + approval gate" }
  red_flags:
    - "testes reescritos para passar"
    - "CI enfraquecido"
    - "helper duplicado"
    - "input não confiável indo para LLM"
    - "PR > 1000 linhas sem justificativa"
    - "PR sem descrição de intenção"
```

Baseado em *Agentic Code Review* de Addy Osmani. Classifica PRs por
risco e aplica nível de revisão proporcional.

---

## 6. Fluxo do agente

### 6.1 — Ciclo completo de uma tarefa

```text
┌──────────────────────────────────────────────────────────────┐
│ 1. PLANNING                                                  │
│    - Router classifica a tarefa                              │
│    - Carrega skills relevantes                               │
│    - Preenche .agents/goals/current.md                       │
│    - Trava critérios de aceitação                            │
├──────────────────────────────────────────────────────────────┤
│ 2. IMPLEMENTATION                                            │
│    - PreToolUse hook: lê arquivo, verifica gates             │
│    - Drafter edita                                           │
│    - PostToolUse hook: check + lint + test focado            │
├──────────────────────────────────────────────────────────────┤
│ 3. TESTING                                                   │
│    - pnpm verify (check + lint + unit + build + e2e)         │
│    - pnpm test:mutation (opcional, para módulos críticos)    │
├──────────────────────────────────────────────────────────────┤
│ 4. SECURITY                                                  │
│    - pnpm security:scan (gitleaks + audit + owasp + d1)      │
│    - pnpm complexity:scan                                    │
├──────────────────────────────────────────────────────────────┤
│ 5. VERIFICATION                                              │
│    - Subagente verifier confirma independentemente           │
│    - Subagente judge decide com base em evidências           │
├──────────────────────────────────────────────────────────────┤
│ 6. REVIEW                                                    │
│    - Classificação por risco (fast/normal/heavy/critical)    │
│    - Revisão humana (se heavy ou critical)                   │
├──────────────────────────────────────────────────────────────┤
│ 7. STAGING                                                   │
│    - Deploy em staging                                       │
│    - Smoke test                                              │
├──────────────────────────────────────────────────────────────┤
│ 8. APPROVAL GATE                                             │
│    - Aprovação humana obrigatória                            │
├──────────────────────────────────────────────────────────────┤
│ 9. PRODUCTION                                                │
│    - Deploy em produção                                      │
│    - Observability ativa                                     │
│    - wrangler tail por 15 min                                │
├──────────────────────────────────────────────────────────────┤
│ 10. RETRO                                                    │
│    - Registrar lição em $DSH_HOME/memory/                    │
│    - Atualizar AGENTS.md se padrão novo emergiu              │
└──────────────────────────────────────────────────────────────┘
```

### 6.2 — Exemplo prático: adicionar endpoint de upload

**Prompt inicial:**

```text
Adicione um endpoint POST /api/files/upload que:
- Recebe um arquivo via multipart/form-data
- Valida tipo (image/png, image/jpeg, application/pdf) e tamanho (≤10MB)
- Grava no R2
- Registra metadados em uploaded_files
```

**O que o harness faz:**

1. **Router:** classifica como "feature backend" → carrega skills
   `cloudflare-r2`, `cloudflare-d1`, `sveltekit-auth`.

2. **Planning:** preenche `.agents/goals/current.md` com critérios.

3. **Implementação:**
   - `pre-edit-check.sh` avisa: "server-only, valide Zod, prepared statements".
   - Drafter cria `src/routes/api/files/upload/+server.ts`.
   - `post-edit-check.sh` roda `pnpm check` + `pnpm lint`.

4. **Testing:** `pnpm verify` roda. Se falhar, corrige.

5. **Security:**
   - `gitleaks` — sem secrets.
   - `owasp-check.sh` — validação Zod presente, sem SQL concatenado.
   - `complexity-check.sh` — funções abaixo do threshold.

6. **Verification:**
   - **Verifier** lê o código e roda testes. Pode descobrir que a
     validação de tamanho é feita após leitura do stream (falha de
     segurança — deveria ser no `Content-Length`).
   - **Judge** decide: "não está pronto; verifier encontrou problema".

7. **Review:** classificada como "heavy" (toca R2 + D1). Revisão humana.

8. **Staging:** deploy + smoke.

9. **Approval:** humano aprova.

10. **Production:** deploy com `wrangler tail` monitorado.

### 6.3 — Exemplo de goal travado

`.agents/goals/current.md` preenchido:

```markdown
## Tarefa
Adicionar endpoint POST /api/files/upload.

## Critérios de aceitação
- [ ] Endpoint retorna 201 para arquivo válido
- [ ] Retorna 400 para content-type não permitido
- [ ] Retorna 413 para arquivo >10MB
- [ ] Metadados em uploaded_files
- [ ] Ownership verificado em GET /api/files/:id
- [ ] Cobertura ≥70% no novo arquivo
- [ ] Sem regressão nos testes existentes

## Skills necessárias
- [x] cloudflare-r2
- [x] cloudflare-d1
- [x] sveltekit-auth
- [x] security-leaks

## Security gates aplicáveis
- [x] Gate 1 (Secrets)
- [x] Gate 2 (Input — Zod)
- [x] Gate 3 (D1 — .bind())
- [x] Gate 4 (R2 — validar tipo/tamanho)

## Subagentes
- [x] Drafter
- [x] Verifier
- [ ] Security Auditor
- [ ] Judge (pendente)

## Evidências esperadas
- [ ] Output de pnpm verify
- [ ] Output de pnpm security:scan
- [ ] Screenshot do upload em staging
```

Se o agente tentar declarar "pronto" com `Judge` não marcado, o
harness bloqueia.

---

## 7. Como criar uma nova skill

### 7.1 — Quando criar

Crie uma skill nova quando:

- Um **domínio específico** aparece com frequência em tarefas.
- Há **padrões** que precisam ser seguidos consistentemente.
- Há **anti-patterns** específicos do domínio que causam bugs.
- O contexto é **grande demais** para caber no `AGENTS.md`.

**Não crie skill para:**
- Regras gerais (vão no `AGENTS.md`).
- Coisas que mudam toda semana (documente em PR/issue).
- Conhecimento já coberto por outra skill.

### 7.2 — Template

Crie `.agents/skills/<nome>/SKILL.md`:

````markdown
# Skill: <nome>

## Quando usar

Carregue esta skill ao trabalhar com:
- <situação 1>
- <situação 2>
- <situação 3>

## Contexto

<Breve explicação do domínio. 1–2 parágrafos.>

## Padrões corretos

### <Padrão 1>

```ts
// ✅ código correto
```

### <Padrão 2>

```ts
// ✅ código correto
```

## Anti-patterns (proibidos)

### <Anti-pattern 1>

```ts
// ❌ NUNCA
```

### <Anti-pattern 2>

```ts
// ❌ NUNCA
```

## Comandos

```bash
# comandos relacionados
```

## Checklist antes de finalizar

- [ ] <item 1>
- [ ] <item 2>
- [ ] <item 3>

## Referências

- <link 1>
- <link 2>
- AGENTS.md — seção X
