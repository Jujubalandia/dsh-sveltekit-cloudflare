# USAGE.md — Como usar o harness no dia a dia

Este é o documento que você vai consultar **depois** de instalar o
harness. Ele responde "e agora, o que eu faço?".

Se você ainda não instalou o harness, comece por `docs/SETUP.md`.

**Público-alvo:** quem já tem o harness instalado e quer saber como
usá-lo para desenvolver features.

**Pré-requisitos:** `docs/SETUP.md` completo, `pnpm verify` verde,
harness registrado no DSH.

---

## Índice

1. [Primeiros 5 minutos](#1-primeiros-5-minutos)
2. [Como o harness funciona no dia a dia](#2-como-o-harness-funciona-no-dia-a-dia)
3. [Os 5 comandos](#3-os-5-comandos)
4. [Fluxo completo — feature nova do zero](#4-fluxo-completo--feature-nova-do-zero)
5. [Fluxo rápido — correção pontual](#5-fluxo-rápido--correção-pontual)
6. [Fluxo de refatoração](#6-fluxo-de-refatoração)
7. [Como invocar subagentes](#7-como-invocar-subagentes)
8. [Como carregar skills](#8-como-carregar-skills)
9. [UI: componentes e tema](#9-ui-componentes-e-tema)
10. [FAQ](#10-faq)
11. [Troubleshooting](#11-troubleshooting)

---

## 1. Primeiros 5 minutos

Após instalar o harness (via `dsh plugin add` ou via template), faça isto:

### 1.1 — Verificar que o harness carregou

Inicie uma sessão do DSH dentro do workspace do projeto:

```bash
cd /caminho/do/projeto
dsh web
```

Dentro da sessão, pergunte ao agente:

```text
Liste as skills disponíveis no seu catálogo.
```

**Esperado:** o agente deve listar as 13 skills do harness
(`cloudflare-d1`, `cloudflare-kv`, `cloudflare-r2`,
`cloudflare-ai-gateway`, `sveltekit-runes`, `sveltekit-auth`,
`shadcn-svelte`, `cloudflare-security`, `owasp-top10`, `security-leaks`,
`code-complexity`, `git-flow`, `agentic-code-review`).

Se ele não listar nada, verifique:
- O `cordis.patch.yml` está no bundle?
- Os `SKILL.md` em `.agents/skills/` têm frontmatter YAML com `name` e
  `description`? O provider `@deepseek-ai/dsh-skill-filesystem`, que o
  `dsh-base` já monta com `includeDefaultRoots: true`, varre
  `.agents/skills` sozinho — mas ignora em silêncio o arquivo sem esse
  cabeçalho.
- Você reiniciou o DSH após `dsh plugin add`?

### 1.2 — Verificar que os comandos estão disponíveis

Digite `/sveflare` no prompt e pressione Tab (ou abra o autocomplete).

**Esperado:** devem aparecer cinco comandos:

```
/sveflare-spec
/sveflare-plan
/sveflare-goal
/sveflare-verify
/sveflare-ship
```

Se não aparecerem, verifique se a linha `- insert:` de id
`sveflare-commands` (plugin `./lib/commands.mjs`) está no
`cordis.patch.yml` (ver seção 3 deste documento).

### 1.3 — Confirmar que o harness está lendo o AGENTS.md

Pergunte:

```text
Quantas Security Gates existem neste projeto?
```

**Esperado:** o agente deve responder "9" (ou o número correto do seu
`AGENTS.md`).

Se responder algo genérico, verifique se o `AGENTS.md` está no root do
projeto e se o DSH está sendo iniciado de dentro do workspace.

### 1.4 — Rodar o primeiro /sveflare-verify

```text
/sveflare-verify
```

Isso roda o pipeline completo (`pnpm verify` + `security:scan` +
`complexity:scan`). Use para confirmar que o projeto está saudável antes
de começar a trabalhar.

**Esperado:** todas as etapas verdes, ou avisos que você deve corrigir
antes de seguir.

### 1.5 — Pronto para começar

Agora você pode escolher:

- **Vai criar uma feature nova?** → `/sveflare-spec` (seção 4).
- **Vai corrigir um bug pontual?** → seção 5.
- **Vai refatorar?** → seção 6.

---

## 2. Como o harness funciona no dia a dia

### 2.1 — O que o harness faz por você

Você **não precisa lembrar** de rodar lint, type check, security scan
ou qualquer verificação. Elas disparam automaticamente:

| Momento | O que roda automaticamente |
|---------|----------------------------|
| Antes de editar arquivo | `pre-edit-check.sh` (avisa skill + gates, inclusive Gate 9 em UI) |
| Depois de editar arquivo | `post-edit-check.sh` (check + lint + test + `prettier --check` no arquivo, aviso) |
| Antes de commit | `pnpm lint` + `pnpm check` + gitleaks |
| Antes de abrir PR | `verify` + `security-scan` + `owasp` + `complexity` |
| Antes de deploy prod | `security-scan` + approval gate |
| Depois de deploy | `smoke-test` |

Você só precisa **decidir o que fazer** e **aprovar o que foi feito**.

### 2.2 — O que você continua fazendo

O harness não substitui você em:

- Decidir **o quê** construir (escopo, prioridade).
- Aprovar **mudanças críticas** (deploy prod, migrations).
- Revisar **PRs pesados** (auth, DB, R2, IA).
- Tomar decisões **arquiteturais**.

### 2.3 — Como o agente pensa

O agente do DSH não é um chatbot. Ele opera em **ciclos**:

```text
1. Ler contexto (AGENTS.md, skills, goals)
2. Planejar (decide quais tools usar)
3. Executar (chama edit, write, bash, etc.)
4. Verificar (hooks disparam automaticamente)
5. Reportar (o que fez, o que falhou)
```

Cada ciclo tem um **goal** associado. Sem goal claro, o agente "vaga".

### 2.4 — Por que os subagentes existem

Um agente único tem viés: ele tende a confirmar que sua própria saída
está correta. Por isso o harness usa **papéis separados**:

- **Drafter** — implementa. Otimista por natureza.
- **Verifier** — verifica. Cético por natureza. Não confia no Drafter.
- **Judge** — decide. Neutro. Baseia-se em evidências, não em opinião.
- **Security Auditor** — foca em segurança.
- **Complexity Auditor** — foca em qualidade estrutural.

---

## 3. Os 5 comandos

Os comandos são pontos de entrada para fluxos estruturados. Cada um
carrega um prompt especializado e ativa os subagentes apropriados.

### 3.1 — `/sveflare-spec`

**Propósito:** iniciar uma feature nova com especificação estruturada.

**O que faz:**
1. Carrega skills relevantes ao domínio.
2. Usa **Drafter** para gerar `docs/SPEC.md`.
3. Usa **Verifier** para revisar, procurando ambiguidades.
4. Apresenta o SPEC revisado para aprovação.

**Quando usar:** no início de qualquer feature que dure mais que
algumas horas.

**Saída:** `docs/SPEC.md` com visão, casos de uso, critérios de
aceitação testáveis e fora de escopo.

**Prompt do comando:** ver `.agents/commands/sveflare-spec.md`.

### 3.2 — `/sveflare-plan`

**Propósito:** converter uma spec aprovada em plano técnico.

**O que faz:**
1. Lê `docs/SPEC.md` e `AGENTS.md`.
2. Usa **Drafter** para gerar `docs/PLAN.md` com schema D1, contratos
   de API, estrutura de pastas e tarefas atômicas.
3. Usa **Complexity Auditor** para detectar complexidade excessiva.
4. Apresenta o PLAN para aprovação.

**Quando usar:** após `/sveflare-spec` ter sido aprovado.

**Saída:** `docs/PLAN.md` + migrations rascunho.

### 3.3 — `/sveflare-goal`

**Propósito:** travar o escopo de uma tarefa atômica.

**O que faz:**
1. Pede descrição da tarefa (1 frase).
2. Extrai critérios de aceitação mensuráveis.
3. Identifica skills necessárias.
4. Lista security gates aplicáveis.
5. Preenche `.agents/goals/current.md`.

**Quando usar:** antes de cada tarefa atômica da fase de execução.

**Saída:** `.agents/goals/current.md` preenchido.

**Nota:** o goal fica **travado** durante a execução. Se o escopo
mudar, abra um novo goal.

### 3.4 — `/sveflare-verify`

**Propósito:** rodar pipeline completo de verificação.

**O que faz:**
1. Executa `scripts/verify.sh` (check + lint + unit + build + e2e).
2. Executa `scripts/security-scan.sh` (gitleaks + audit + owasp + d1).
3. Executa `scripts/complexity-check.sh` (complexidade + duplicação).
4. Reporta resultados consolidados.

**Quando usar:**
- Antes de abrir PR.
- Antes de deploy.
- Quando suspeitar que algo quebrou.

**Saída:** relatório com status de cada gate.

### 3.5 — `/sveflare-ship`

**Propósito:** validar e preparar deploy.

**O que faz:**
1. Roda `/sveflare-verify`.
2. Usa **Security Auditor** para revisar o relatório.
3. Usa **Judge** para decidir se está pronto com base em evidências.
4. Se aprovado, faz deploy em staging e roda smoke test.
5. Pede aprovação humana para deploy em produção.

**Quando usar:** quando a feature está implementada e testada.

**Saída:** deploy em staging + decisão do Judge + gate de aprovação.

**Nota:** `/sveflare-ship` nunca faz deploy em produção sem sua
autorização explícita.

### 3.6 — Como os comandos são registrados

Os comandos `/sveflare-*` são definidos em `.agents/commands/` e
registrados no bundle via `cordis.patch.yml`. O DSH **não varre** esse
diretório: o `@deepseek-ai/dsh-commands` é um registry em que cada plugin
se registra por **código**, e ele não tem schema de configuração. Quem faz
a ponte entre os arquivos markdown e o registry é o `lib/commands.mjs`,
que este bundle publica. Quando o usuário roda
`dsh plugin --profile web add`, o DSH:

1. Lê o `cordis.patch.yml` do bundle.
2. Aplica a linha `- insert:` de id `sveflare-commands`.
3. Carrega o plugin `./lib/commands.mjs` (caminho resolvido pelo loader
   relativo ao próprio `cordis.patch.yml`).
4. O plugin lê cada arquivo declarado em `config.commands[].file` e
   registra o comando via `ctx.commands.register()` — o `name` da config
   é o que vira `/sveflare-spec`, `/sveflare-plan`, etc.
5. Na próxima sessão, os comandos aparecem no autocomplete.

Se os comandos não aparecerem, verifique:

```bash
# 1. Os arquivos existem?
ls .agents/commands/

# 2. O cordis.patch.yml tem a seção sveflare-commands?
grep -A 20 "sveflare-commands" cordis.patch.yml

# 3. O bundle foi reinstalado?
dsh plugin --profile web remove @seu-usuario/dsh-sveltekit-cloudflare
dsh plugin --profile web add @seu-usuario/dsh-sveltekit-cloudflare
dsh web
```

**Estrutura do arquivo de comando:**

Cada comando é um arquivo markdown em `.agents/commands/` com um
frontmatter YAML no topo:

```markdown
---
name: sveflare-spec
description: Inicia especificação estruturada (SPEC.md)
argument-hint: <descrição da feature em 1-3 frases>
allowed-tools: read, write, edit, grep, bash
model: deepseek-chat
---

# /sveflare-spec — Especificação estruturada de feature

<corpo do prompt...>
```

### 3.7 — Verificar que os comandos carregaram

```bash

# 1. Os arquivos existem?
ls .agents/commands/
# Esperado: sveflare-spec.md, sveflare-plan.md, sveflare-goal.md,
#           sveflare-verify.md, sveflare-ship.md

# 2. O cordis.patch.yml tem a linha sveflare-commands?
grep -A 12 "sveflare-commands" cordis.patch.yml
# Esperado: id: sveflare-commands, name: './lib/commands.mjs'
#           e config.commands com os 5 arquivos .agents/commands/*.md

# 3. Reinstalar o bundle
dsh plugin --profile web remove @seu-usuario/dsh-sveltekit-cloudflare
dsh plugin --profile web add @seu-usuario/dsh-sveltekit-cloudflare
dsh web
```


---

## 4. Fluxo completo — feature nova do zero

Cenário: você quer adicionar "sistema de comentários em posts".

### 4.1 — Iniciar com especificação

```text
/sveflare-spec Quero adicionar um sistema de comentários em posts.
Usuários autenticados podem comentar, editar seus comentários por 15
minutos, e deletar a qualquer momento. Admins podem deletar qualquer
comentário. Comentários suportam texto plano (sem markdown por
enquanto) e têm limite de 2000 caracteres.
```

O agente vai:
1. Carregar skills `sveltekit-auth`, `cloudflare-d1`, `owasp-top10`.
2. Invocar Drafter para gerar `docs/SPEC.md`.
3. Invocar Verifier para revisar.
4. Apresentar o SPEC para você.

**Sua vez:** revise o SPEC. Se algo estiver ambíguo, peça ajustes.
Quando estiver bom, diga "aprovo".

### 4.2 — Gerar plano técnico

```text
/sveflare-plan
```

O agente vai:
1. Ler `docs/SPEC.md`.
2. Invocar Drafter para gerar `docs/PLAN.md`.
3. Invocar Complexity Auditor.
4. Apresentar o PLAN.

**Sua vez:** revise o PLAN. Confirme que:
- O schema D1 faz sentido (tabelas, índices, foreign keys).
- Os endpoints cobrem todos os casos de uso da spec.
- As tarefas são pequenas o suficiente (cada uma verificável em 1–2h).
- Não há complexidade desnecessária.

### 4.3 — Executar tarefa por tarefa

Para cada tarefa do PLAN:

```text
/sveflare-goal Implementar endpoint POST /api/posts/:id/comments
```

Isso preenche o goal. Depois:

```text
Implemente o goal atual em .agents/goals/current.md.
```

O agente vai:
1. Ler o goal.
2. Carregar skills relevantes.
3. Editar arquivos (hooks disparam).
4. Rodar testes focados.
5. Reportar.

**Sua vez:** revise o que foi feito. Se OK, marque o goal como
concluído e passe para a próxima tarefa.

### 4.4 — Verificar tudo

Quando todas as tarefas estiverem concluídas:

```text
/sveflare-verify
```

O agente roda o pipeline completo. Corrija o que aparecer.

### 4.5 — Ship

```text
/sveflare-ship
```

O agente valida, faz deploy em staging, roda smoke, e pede sua
aprovação para produção.

---

## 5. Fluxo rápido — correção pontual

Cenário: você tem um bug de validação que aceita emails inválidos.

```text
/sveflare-goal Corrigir validação de email no endpoint POST /api/users
que está aceitando endereços sem TLD.
```

Depois:

```text
Implemente o goal atual.
```

O agente vai:
1. Carregar skill `owasp-top10` (validação).
2. Encontrar o arquivo de validação.
3. Corrigir a regex.
4. Rodar testes focados.
5. Reportar.

Você revisa, aprova, faz commit.

**Regra:** mesmo para correções pontuais, use `/sveflare-goal`. O goal
força o agente a declarar **o que** está sendo corrigido e **como** vai
validar. Sem isso, ele pode "consertar" outras coisas de passagem.

---

## 6. Fluxo de refatoração

Cenário: você quer extrair a lógica de cache de um arquivo grande para
um módulo dedicado.

```text
/sveflare-goal Extrair lógica de cache de src/routes/api/users/+server.ts
para src/lib/server/cache/users.ts. Sem mudança de comportamento.
Critério: todos os testes existentes passam.
```

Depois:

```text
Implemente o goal atual.
```

O agente vai:
1. Carregar skill `code-complexity`.
2. Mover o código.
3. Atualizar imports.
4. Rodar testes (que devem passar sem modificação).
5. Reportar.

**Regra importante:** refatorações **não devem mudar testes**. Se o
agente modificar um teste durante uma refatoração, é sinal de que o
comportamento mudou — o que viola o objetivo.

---

## 7. Como invocar subagentes

Os subagentes são ativados automaticamente pelos comandos. Mas você
pode invocá-los explicitamente quando quiser.

### 7.1 — Via linguagem natural

```text
Use o subagente Verifier para revisar o arquivo
src/routes/api/comments/+server.ts e me dizer se há problemas de
validação.
```

O agente vai:
1. Reconhecer "Verifier" no prompt.
2. Delegar a tarefa ao subagente apropriado.
3. Retornar o relatório do Verifier.

### 7.2 — Via referência direta

```text
@verifier revise src/lib/server/session.ts
```

Ou:

```text
@security_auditor rode uma auditoria dos últimos 3 commits
```

### 7.3 — Quando usar cada subagente

| Situação | Subagente recomendado |
|----------|----------------------|
| Implementar algo | Drafter (padrão) |
| Revisar o que foi implementado | Verifier |
| Decidir se está pronto | Judge |
| Auditar segurança | Security Auditor |
| Auditar complexidade | Complexity Auditor |
| Revisar antes de merge | Verifier + Security Auditor |
| Antes de deploy prod | Security Auditor + Judge |

### 7.4 — Subagentes em sequência

O padrão mais poderoso é **encadear**:

```text
Use o Drafter para implementar o goal atual.
Depois use o Verifier para revisar independentemente.
Depois use o Judge para decidir se está pronto.
```

Isso ativa a tríade completa — exatamente o modelo "um rascunha, outro
verifica" que o harness adota.

---

## 8. Como carregar skills

Skills são carregadas automaticamente quando o agente detecta o
contexto. Mas você pode carregar explicitamente.

### 8.1 — Carregamento automático

Quando você pede algo como:

```text
Adicione um endpoint que consulta D1.
```

O agente detecta que a tarefa toca D1 e carrega `cloudflare-d1`
automaticamente.

### 8.2 — Carregamento explícito

```text
Carregue a skill cloudflare-r2 e me explique como fazer upload
de arquivos com validação de tipo.
```

### 8.3 — Múltiplas skills

```text
Carregue as skills cloudflare-d1, sveltekit-auth e owasp-top10.
Vou precisar das três para a próxima tarefa.
```

### 8.4 — Regra de ouro

**2–3 skills por tarefa.** Mais que isso é sinal de que a tarefa
deveria ser dividida.

---

## 9. UI: componentes e tema

O kit inclui um app SvelteKit mínimo em `src/`, com **Tailwind CSS v4**
e **shadcn-svelte**. A UI não é um pacote separado: ela é código do
projeto em `src/lib/components/ui/`, gerado pelo CLI.

### 9.1 — Adicionar um componente

```bash
# Um componente
pnpm ui:add badge

# Vários de uma vez
pnpm ui:add card dialog table

# Conferir o que seria feito, sem escrever
pnpm ui:add badge --dry-run
```

O comando é um alias de `shadcn-svelte add`. Ele consulta
`components.json`, baixa o componente do registry oficial e escreve em
`src/lib/components/ui/<nome>/`. No código, importe pelo alias que o
próprio componente usa:

```svelte
<script lang="ts">
  import { Button } from '$lib/components/ui/button/index.js';
</script>

<Button variant="outline">Salvar</Button>
```

Depois de adicionar, trate como PR: leia o diff, confira se o CLI não
escreveu `"latest"` em dependências novas (re-pine) e rode `pnpm check`
+ `pnpm test:e2e`.

**Bits UI 2 (gotcha):** não existe mais `asChild` + `let:props`. Para
compor um trigger com o seu próprio botão, use o snippet `child`:

```svelte
<DialogTrigger>
  {#snippet child({ props })}
    <Button {...props}>Abrir</Button>
  {/snippet}
</DialogTrigger>
```

### 9.2 — Como o tema funciona

Há um único arquivo de tema: `src/app.css`. Não existe
`tailwind.config.js` nem `postcss.config.js` — no Tailwind v4 a
configuração é CSS, e o plugin `@tailwindcss/vite` está em
`vite.config.ts`.

O arquivo tem três blocos:

- `:root` — tokens do tema claro.
- `.dark` — tokens do tema escuro.
- `@theme inline` — mapeia os tokens para utilitários Tailwind
  (`--color-primary: var(--primary)` → `bg-primary`, `text-primary`).

Para mudar a cara do app, altere o token nos **dois** temas:

```css
:root {
  --primary: oklch(0.55 0.18 250);
  --radius: 0.625rem;
}

.dark {
  --primary: oklch(0.75 0.14 250);
}
```

Componentes em `ui/` não guardam cor: usam `bg-primary`,
`text-foreground`, `border-border`, etc. Ajuste o token, não o
componente.

### 9.3 — Dark mode

A fonte única de verdade é o `mode-watcher`:

- chave `mode-watcher-mode` no `localStorage` (`light`, `dark`, `system`);
- `ModeWatcher` montado no `src/routes/+layout.svelte`;
- `ThemeToggle` em `src/lib/components/theme-toggle.svelte`;
- script inline no `src/app.html` lê a **mesma** chave antes da primeira
  pintura, para não piscar tema claro em quem usa escuro.

Não crie uma segunda fonte de verdade (store própria, classe em outro
lugar, `prefers-color-scheme` duplicado). Se ligar CSP, o script inline
precisa de nonce.

### 9.4 — O que NÃO fazer

| Não faça | Por quê |
|----------|---------|
| Editar `src/lib/components/ui/**` à mão | É código regenerável; o próximo `add`/`--overwrite` sobrescreve |
| Criar `src/lib/utils/` (diretório) | `$utils` aponta para `src/lib/utils` e competiria com `src/lib/utils.ts` |
| Criar `tailwind.config.js`/`postcss.config.js` | Tailwind v4 se configura em `src/app.css` |
| Trocar `baseColor` só no `components.json` | Os tokens gerados continuam os antigos; recrie o tema |
| Deixar `"latest"` no `package.json` | O CLI escreve isso; re-pine (Gate 9) |
| Rodar `pnpm ui:init` sem revisar | Ele reescreve `src/app.css` |
| Colocar regra de negócio em `ui/` | Vai em `$lib/server` ou `$lib/` |

### 9.5 — Gate 9 na prática

Todo `pnpm ui:add` baixa **código executável** de um registry remoto.
Por isso: CLI em versão fixa, `components.json.registry` apontando para
`https://shadcn-svelte.com/registry`, diff revisado em PR e
`--overwrite` (`-o`) só com intenção. O `security-scan.sh` confere
registry e pin. O código de `ui/` fica fora de lint/cobertura, mas
continua em `svelte-check`, e2e e segurança.

---

## 10. FAQ

### "Preciso decorar os 5 comandos?"

Não. Use `/sveflare` + Tab para ver o autocomplete. Os nomes são
descritivos: `spec`, `plan`, `goal`, `verify`, `ship`.

### "Posso usar sem os comandos?"

Sim. Os comandos são apenas prompts estruturados. Você pode escrever
os prompts manualmente. Mas os comandos garantem que você não vai
esquecer etapas importantes.

### "Os subagentes são obrigatórios?"

Não. Para tarefas triviais, o Drafter sozinho basta. Mas o harness
foi desenhado para que o Verifier seja sempre acionado em PRs
normais ou maiores.

### "O agente vai commitar sozinho?"

Depende da configuração. Por padrão, **não**. Ele edita arquivos, mas
commit e push são ações que exigem sua confirmação (ou passam pelo
hook `PreCommit`).

### "Posso pular a fase de spec?"

Tecnicamente sim. Mas se a feature tem mais que 3 endpoints ou mais
que 2 tabelas, o SPEC paga por si mesmo. Sem ele, o agente tende a
tomar decisões de escopo que você não autorizou.

### "O que fazer quando o Verifier e o Drafter discordam?"

Você é o árbitro. Leia os argumentos dos dois, verifique as
evidências (comandos + saída), e decida. O Judge pode ajudar.

### "Posso adicionar meus próprios comandos?"

Sim. Crie o markdown em `.agents/commands/` seguindo o padrão dos
existentes e acrescente um par `name`/`file` em `config.commands`, na
linha `sveflare-commands` do `cordis.patch.yml`. O plugin
`lib/commands.mjs` lê os arquivos declarados e registra cada um — nada é
descoberto do disco.

### "O harness funciona em monorepos?"

Sim, mas cada pacote deve ter seu próprio `AGENTS.md` (regras
específicas) e herdar as regras globais de `$DSH_HOME/AGENTS.md`.

### "Como atualizo o harness instalado?"

```bash
dsh plugin --profile web remove @seu-usuario/dsh-sveltekit-cloudflare
dsh plugin --profile web add @seu-usuario/dsh-sveltekit-cloudflare
dsh web
```

---

## 11. Troubleshooting

Antes de tudo, rode o validador do próprio kit — ele checa os contratos
que o DSH exige e que falham em silêncio (linha de plugin fora do
`insert:`, skill sem frontmatter, script com sintaxe quebrada):

```bash
node scripts/validate-kit.mjs
```

E, para ver o que o DSH realmente carregou do bundle:

```bash
dsh --profile web --dump-config | grep sveflare
```

### Componente novo não aparece na página

**Causas prováveis:**
- O `pnpm ui:add <componente>` não rodou (ou rodou em outro diretório).
- O import usa um alias que não existe, ou aponta para um arquivo fora
  de `src/lib/components/ui/<nome>/`.
- O componente foi escrito, mas a página/rota não importa ele.

**Solução:**

```bash
# O componente existe?
ls src/lib/components/ui/<nome>/

# O CLI escreveria onde você espera?
pnpm ui:add <nome> --dry-run

# O import no seu arquivo está correto?
grep -rn "components/ui/<nome>" src/
```

Prefira o import que o código gerado usa:
`import { Button } from '$lib/components/ui/button/index.js'`. Se o
`pnpm dev` já estava rodando, salve o arquivo de novo para o HMR
reprocessar.

### Tema não é aplicado

**Causas prováveis:**
- `src/app.css` não é importado no `src/routes/+layout.svelte`.
- O plugin `@tailwindcss/vite` sumiu do `vite.config.ts`.
- Você editou o token só em `:root` (claro) e o app está em `.dark`.
- Tokens novos em `:root` sem o mapeamento correspondente em
  `@theme inline`.

**Solução:**

```bash
# O layout importa o CSS?
grep -n "app.css" src/routes/+layout.svelte

# O plugin está no Vite?
grep -n "tailwindcss" vite.config.ts

# Limpar cache do SvelteKit e subir de novo
rm -rf .svelte-kit
pnpm dev
```

Lembre: não existe `tailwind.config.js`; se você criou um, ele não é
lido. A configuração é o `src/app.css`.

### `pnpm dev` pede `CLOUDFLARE_API_TOKEN`

**Causa:** o `platformProxy` do adapter-cloudflare assume
`remoteBindings: true` por padrão. Com isso, o dev tenta resolver os
bindings na Cloudflare e exige token.

**Solução:** o kit fixa `remoteBindings: false` no `svelte.config.js`
para desenvolvimento local. Confirme:

```bash
grep -n "remoteBindings" svelte.config.js
# Esperado: remoteBindings: false
```

Se você mudou para `true` de propósito, o token passa a ser
obrigatório. Para o dia a dia local, volte para `false`.

### `"latest"` aparece no `package.json`

**Causa:** o CLI do shadcn-svelte escreve `"latest"` ao adicionar uma
dependência nova. Isso quebra reprodutibilidade e o Gate 9.

**Solução:**

```bash
# Veja o que ficou como latest
grep -n '"latest"' package.json

# Troque pela versão real instalada
pnpm list <pacote>
# edite package.json para a versão exata (ex: "^1.2.3")
pnpm install
```

Nunca commite `"latest"`. Se o CLI reintroduzir, re-pine antes do commit.

### Comandos `/sveflare-*` não aparecem no autocomplete

**Causas possíveis:**
- A linha `- insert:` de id `sveflare-commands` não está no
  `cordis.patch.yml`. Um `id` + `name` de topo, fora do `insert:` **não
  adiciona plugin nenhum** — é só uma asserção sobre uma linha que já
  existe, e apontando para um id inexistente vira no-op silencioso com o
  warning `patch: entry ... not found`.
- Um `config.commands[].file` aponta para um arquivo que não existe — o
  plugin loga `<arquivo> não encontrado` e pula só aquele comando.
- A camada do bundle não está instalada no profile.

**Solução:** confirme que a linha existe e que ela está **dentro** do
`insert:`:

```yaml
- insert:
    - id: sveflare-commands
      name: './lib/commands.mjs'
      config:
        commands:
          - name: sveflare-spec
            file: .agents/commands/sveflare-spec.md
```

Depois rode `node scripts/validate-kit.mjs` e
`dsh --profile web --dump-config | grep sveflare` para confirmar que a
linha entrou, e reinicie o DSH.

### Skills não aparecem no catálogo

**Causa mais comum:** o `SKILL.md` não tem frontmatter YAML com `name` e
`description` no topo. O `@deepseek-ai/dsh-skill-filesystem` — que o
`dsh-base` já monta com `includeDefaultRoots: true` — varre
`<projectRoot>/.agents/skills` e `<projectRoot>/.dsh/skills` sozinho, sem
nenhuma linha no bundle, mas **ignora com um warning** o arquivo sem esse
cabeçalho. O `name` também precisa casar com
`/^[a-z0-9]+(?:-[a-z0-9]+)*$/`.

**Outras causas:**
- O arquivo não está em `.agents/skills/<nome>/SKILL.md`.
- O bundle não foi reiniciado, ou o DSH foi iniciado fora do workspace.

**Solução:**

```bash
# O frontmatter está no topo de cada SKILL.md?
head -5 .agents/skills/*/SKILL.md

# Checagem completa (frontmatter, nomes válidos, patch, hooks, scripts)
node scripts/validate-kit.mjs

# Reiniciar
dsh web
```

### Agente ignora o AGENTS.md

**Causa:** o DSH foi iniciado fora do workspace do projeto.

**Solução:** sempre inicie o DSH de dentro do diretório do projeto:

```bash
cd /caminho/do/projeto
dsh web
```

### Hook não dispara

**Causa:** os scripts em `scripts/` não estão executáveis.

**Solução:**

```bash
chmod +x scripts/*.sh
```

### Goal fica "travado" e não consigo mudar

**Causa:** goal é intencionalmente imutável durante a execução.

**Solução:** abra um novo goal. O anterior fica registrado como
"abortado" com o motivo.

### "O agente não sabe usar o comando /sveflare-spec"

**Causa:** o arquivo `.agents/commands/sveflare-spec.md` não existe, ou o
caminho declarado em `config.commands[].file` não bate com o arquivo no
disco (o plugin loga um warning e não registra o comando).

**Solução:** confirme que o caminho em `cordis.patch.yml` existe
(`ls .agents/commands/`), que o arquivo tem frontmatter `---` com `name`
e `description` no topo, e que o corpo do prompt depois do frontmatter
não está vazio — é o corpo que o comando envia ao modelo.

---

## Referências

- `docs/SETUP.md` — configuração do ambiente.
- `docs/HARNESS.md` — arquitetura do harness.
- `docs/FEATURES.md` — inventário de componentes.
- `docs/DISTRIBUTION.md` — publicação e distribuição.
- `AGENTS.md` — regras operacionais do agente.
- `.agents/skills/*/SKILL.md` — skills por domínio.
- `.agents/commands/sveflare-*.md` — prompts dos comandos.
