# DISTRIBUTION.md — Publicação e distribuição do harness

Guia completo para publicar e distribuir este harness como um **bundle
DSH** (instalável via `dsh plugin add`) ou como **template de projeto**
(scaffold para novos repositórios).

**Público-alvo:** mantenedores do kit que querem publicá-lo para reuso
por outros times ou pela comunidade.

**Pré-requisitos:** ler `docs/HARNESS.md` (entender a arquitetura do
harness) e `docs/FEATURES.md` (saber o que está sendo distribuído).

---

## Índice

1. [Visão geral](#1-visão-geral)
2. [Fluxo A — Publicar como bundle](#2-fluxo-a--publicar-como-bundle)
3. [Fluxo B — Publicar como template](#3-fluxo-b--publicar-como-template)
4. [Publicação no npm](#4-publicação-no-npm)
5. [Submissão a marketplaces](#5-submissão-a-marketplaces)
6. [Versionamento e atualizações](#6-versionamento-e-atualizações)
7. [Checklist de publicação](#7-checklist-de-publicação)
8. [Referências](#8-referências)

---

## 1. Visão geral

### 1.1 — Dois fluxos, um repositório

Um mesmo repositório pode servir a dois propósitos:

| Fluxo | Para quem | Como instala | O que recebe |
|-------|-----------|--------------|--------------|
| **A — Bundle** | Quem já tem um projeto | `dsh plugin --profile web add github:user/repo` | Skills, hooks, subagentes (global) |
| **B — Template** | Quem quer começar projeto novo | `gh repo create --template` ou `degit` | Projeto completo + harness embutido |

O Fluxo A distribui apenas o **harness** (regras, skills, scripts,
docs). O Fluxo B distribui o **projeto inteiro** (SvelteKit +
Cloudflare + harness).

### 1.2 — O que é um bundle DSH

Um bundle é um **pacote npm que carrega uma camada de configuração**
(`cordis.patch.yml`). Quando instalado, o DSH lê essa camada e registra
os componentes no profile ativo.

> "DSH plugin 打包的本质是把你写好的插件变成一个携带配置层的 npm 包
> (bundle)：`package.json` 用 `dsh.bundle.patch` 指向一份
> `cordis.patch.yml`，这份 patch 里的插件行按包名引用模块；用户执行
> `dsh plugin --profile <name> add` 后，这一层被追加进 profile 的
> `dsh.profile.bundles`." [reference:0]

Os três arquivos mínimos de um bundle são:

```text
dsh-sveltekit-cloudflare/
├── package.json          # declara dsh.bundle.patch
├── cordis.patch.yml      # camada aplicada ao profile
└── index.js              # módulo referenciado pelo patch (opcional se só skills)
```

**Ponto crítico:** o campo `files` do `package.json` **deve incluir**
`cordis.patch.yml`. Se o arquivo não for publicado, o bundle é instalado
como dependência comum e nenhuma camada é ativada — o erro mais comum em
publicações de bundle. [reference:1]

### 1.3 — Bundle vs Profile

| Conceito | O que é | Campo no manifest |
|----------|---------|-------------------|
| **Bundle** | Pacote npm que contribui uma camada | `dsh.bundle` |
| **Profile** | Diretório `$DSH_HOME/profiles/<name>/` que combina bundles | `dsh.profile` |

Você **escreve e publica** o bundle. O usuário **roda** o profile. O
`dsh plugin` cria e mantém o profile automaticamente — nunca edite à mão.
[reference:2]

---

## 2. Fluxo A — Publicar como bundle

### 2.1 — Estrutura de arquivos

O repositório já está estruturado. Os arquivos relevantes para o bundle:

```text
dsh-sveltekit-cloudflare/
├── package.json          ← declara dsh.bundle.patch
├── cordis.patch.yml      ← camada de configuração
├── AGENTS.md             ← regras operacionais
├── harness.config.yml    ← config complementar
├── .agents/
│   ├── skills/           ← 12 SKILL.md
│   └── goals/            ← template de goal
├── scripts/              ← 8 scripts de verificação
└── docs/                 ← documentação
```

### 2.2 — `package.json` (já configurado)

O `package.json` do projeto já contém os campos necessários:

```json
{
  "name": "@seu-usuario/dsh-sveltekit-cloudflare",
  "version": "1.0.0",
  "description": "DSH harness for SvelteKit + Cloudflare",
  "license": "MIT",
  "repository": "github:seu-usuario/dsh-sveltekit-cloudflare",
  "keywords": ["dsh", "dsh-bundle", "sveltekit", "cloudflare", "harness"],

  "dsh": {
    "bundle": {
      "patch": "./cordis.patch.yml"
    }
  },

  "files": [
    "AGENTS.md",
    "cordis.patch.yml",
    ".agents/",
    "scripts/",
    "docs/",
    "harness.config.yml"
  ]
}
```

**Campos críticos:**

| Campo | Função |
|-------|--------|
| `dsh.bundle.patch` | Contrato que o DSH procura. Sem ele, o pacote não é um bundle. |
| `files` | Controla o que vai no `npm publish`. Deve incluir `cordis.patch.yml`. |
| `name` escopado | Evita colisão no npm. |
| `keywords` | Facilita descoberta (inclua `dsh-bundle`). |

### 2.3 — `cordis.patch.yml` (já criado)

O `cordis.patch.yml` é a camada que o DSH aplica quando o bundle entra em
`dsh.profile.bundles`. O dialeto é um array YAML de entradas de patch do
loader (`@deepseek-ai/cordis-plugin-include`), e só existem duas formas:

| Forma | Efeito |
|-------|--------|
| `- insert: [ {id, name, config} ]` | **Adiciona** linhas novas de plugin |
| `- id: <row-existente>` + `config` | **Sobrescreve** a config de uma linha existente |
| `- id: <row-existente>` + `name` | **Assere** o nome da linha alvo |

> ⚠️ `name` numa entrada de topo (sem `insert`) **não adiciona plugin**.
> É uma asserção de que a linha alvo já tem aquele nome. Um patch assim,
> apontando para um `id` que não existe, vira um no-op com o warning
> `patch: entry ... not found` — a instalação parece bem-sucedida e não
> registra nada.

Este kit insere **uma** linha: o bridge de hooks.

```yaml
- insert:
    - id: sveltekit-cloudflare-hooks
      name: '@deepseek-ai/dsh-hooks-claude-code'
      config:
        configPath: './.agents/hooks.json'
```

**Skills não precisam de linha.** O `dsh-base` já monta
`@deepseek-ai/dsh-skill-filesystem` com `includeDefaultRoots: true`, que
descobre `<projectRoot>/.agents/skills` automaticamente. Registrar um
provider próprio seria redundante — e `customSkillDirs` resolve contra o
cwd do processo, não contra a raiz do pacote instalado. O que cada skill
exige é frontmatter YAML com `name` e `description`; sem ele o arquivo é
ignorado com warning.

**Subagentes também não.** `@deepseek-ai/dsh-subagent` é o Service
Definition do seam `ctx.subagents` e não expõe config `agents`. Papéis
nomeados no DSH são **Agent Presets** (um diretório com `agent.cordis.yml`
descoberto pelos preset roots), não linhas de bundle.

**PreCommit e PrePR não são eventos do bridge de hooks.** Vivem nos hooks
de git: `.husky/pre-commit` e `.husky/pre-push`.

### 2.4 — Passo a passo de publicação

```bash
# 1. Verificar que os arquivos estão prontos
ls -la package.json cordis.patch.yml AGENTS.md

# 2. Testar a instalação localmente
dsh plugin --profile web add .

# 3. Verificar que a camada foi aplicada
dsh --profile web --dump-config | grep sveltekit-cloudflare

# 4. Se OK, remover a instalação local
dsh plugin --profile web remove @seu-usuario/dsh-sveltekit-cloudflare

# 5. Publicar no npm (ver seção 4)
npm publish --access public
```

### 2.5 — Instalação pelo usuário final

**Via GitHub (recomendado para open source):**

```bash
dsh plugin --profile web add github:seu-usuario/dsh-sveltekit-cloudflare
```

**Via npm (após publicar):**

```bash
dsh plugin --profile web add @seu-usuario/dsh-sveltekit-cloudflare
```

**Com versão fixada (para reprodutibilidade):**

```bash
dsh plugin --profile web add github:seu-usuario/dsh-sveltekit-cloudflare#v1.0.0
```

**Importante:** o DSH compõe as camadas de bundle **no boot**. Após o
`add`, reinicie o servidor:

```bash
dsh web
```

### 2.6 — Verificação pelo usuário

```bash
# Confirmar que a camada foi aplicada
dsh --profile web --dump-config | grep sveltekit-cloudflare

# Dentro de uma sessão do DSH:
# "Liste as skills disponíveis no seu catálogo."
```

As skills devem aparecer com o provider `sveltekit-cloudflare`.
[reference:4]

---

## 3. Fluxo B — Publicar como template

### 3.1 — Quando usar

O Fluxo B é para quem quer **começar um projeto novo** já com o harness
embutido. Diferente do bundle, o template entrega o projeto SvelteKit +
Cloudflare completo.

### 3.2 — Configuração no GitHub

1. Acesse **Settings** do repositório.
2. Marque **Template repository**.
3. Pronto — o repo está disponível como template.

### 3.3 — Como o usuário usa

**Via `gh` CLI (recomendado):**

```bash
gh repo create meu-novo-app \
  --template seu-usuario/dsh-sveltekit-cloudflare \
  --clone
cd meu-novo-app
```

**Via `degit` (sem histórico git, mais limpo):**

```bash
npx degit seu-usuario/dsh-sveltekit-cloudflare meu-novo-app
cd meu-novo-app
git init
```

**Via clone manual (menos elegante):**

```bash
git clone https://github.com/seu-usuario/dsh-sveltekit-cloudflare meu-novo-app
cd meu-novo-app
rm -rf .git && git init
```

### 3.4 — O que o template inclui

O template entrega o projeto inteiro:

```text
meu-novo-app/
├── AGENTS.md                    Regras do agente
├── harness.config.yml           Config do DSH
├── .agents/                     12 skills + goals
├── scripts/                     8 scripts de verificação
├── docs/                        SETUP, HARNESS, FEATURES, DISTRIBUTION
├── src/                         SvelteKit
├── workers/                     Workers
├── migrations/                  D1
├── tests/                       unit, e2e, mutation
├── wrangler.*.toml              Configs Cloudflare
├── .github/workflows/           CI/CD
└── .husky/pre-commit            Hook
```

Após clonar, o usuário segue `docs/SETUP.md` para configurar o ambiente.

### 3.5 — Template + Bundle no mesmo repo

Um único repositório pode ser **Template** (Fluxo B) **e** **bundle**
(Fluxo A) ao mesmo tempo:

- **Template:** marcado em Settings → Template repository.
- **Bundle:** `package.json` com `dsh.bundle.patch` + `cordis.patch.yml`.

O usuário escolhe o fluxo conforme a necessidade. Não há conflito.

---

## 4. Publicação no npm

### 4.1 — Pré-requisitos

```bash
# Verificar que está logado
npm whoami

# Se não, logar
npm login
```

### 4.2 — Verificar o que será publicado

Antes de publicar, simule o pacote:

```bash
npm pack --dry-run
```

Isso mostra exatamente quais arquivos vão para o npm. **Confirme que
`cordis.patch.yml` está na lista.** [reference:5]

### 4.3 — Publicar

```bash
npm publish --access public
```

**Nota sobre registry:** se seu npm local aponta para um mirror (ex:
Taobao), force o registry oficial:

```bash
npm publish --registry https://registry.npmjs.org --access public
```

[reference:6]

### 4.4 — Verificar

```bash
# Verificar que o pacote está no npm
npm view @seu-usuario/dsh-sveltekit-cloudflare

# Instalar em um profile de teste
dsh plugin --profile web add @seu-usuario/dsh-sveltekit-cloudflare
```

### 4.5 — Publicação automatizada via CI

Para automatizar, adicione `.github/workflows/publish.yml`:

```yaml
name: Publish to npm
on:
  push:
    tags: ['v*.*.*']

jobs:
  publish:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      id-token: write   # para OIDC trusted publishing
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 22
          registry-url: 'https://registry.npmjs.org'
      - run: npm ci
      - run: npm publish --access public
        env:
          NODE_AUTH_TOKEN: ${{ secrets.NPM_TOKEN }}
```

**Importante:** a tag deve corresponder exatamente à `version` do
`package.json`. [reference:7]

### 4.6 — `peerDependencies` e versão do DSH

Alinhe o `peerDependencies` à versão do DSH que você testou:

```json
{
  "peerDependencies": {
    "@deepseek-ai/dsh-base": "^0.1.0-rc.6"
  }
}
```

Quando o DSH for para versão estável, atualize. [reference:8]

---

## 5. Submissão a marketplaces

### 5.1 — Marketplaces disponíveis

O DSH não tem um marketplace oficial único. Há vários terceiros:

| Marketplace | Como submeter |
|-------------|---------------|
| **DSH-Store** (dsh.store) | Submeter GitHub project URL; bot lê arquivos [reference:9] |
| **dsh-plugin-marketplace** | Publicar no npm; aparece via GitHub topic `dsh-plugin` [reference:10] |
| **SkillHub** | Settings → Skill Market |
| **DSPlugin.app** | Catálogo web |

### 5.2 — Submissão ao DSH-Store

O DSH-Store é o marketplace canônico. Para submeter:

1. Publique o repositório no GitHub.
2. Acesse o DSH-Store e use **Submit project**.
3. O bot lê `package.json` e `cordis.patch.yml` automaticamente. [reference:11]

**Pré-requisitos:** DSH `0.1.0-rc.7` ou superior; Node.js `22.13.0`+.
[reference:12]

### 5.3 — Descoberta via GitHub topic

Adicione o topic `dsh-plugin` ao repositório no GitHub. O
`dsh-plugin-marketplace` busca esse topic automaticamente. [reference:13]

```bash
# Adicionar topic via gh CLI
gh repo edit --add-topic dsh-plugin
```

Outros topics úteis:
- `dsh-bundle`
- `dsh-skill`
- `agent-skills`

### 5.4 — Descoberta via npm keywords

As keywords do `package.json` são indexadas pelo npm. Inclua:

```json
"keywords": ["dsh", "dsh-bundle", "dsh-plugin", "sveltekit", "cloudflare"]
```

---

## 6. Versionamento e atualizações

### 6.1 — SemVer

Use [SemVer](https://semver.org/):

| Mudança | Versão |
|---------|--------|
| Breaking change (renomeia skill, remove hook) | `MAJOR` |
| Nova skill, novo subagente | `MINOR` |
| Correção de script, ajuste de doc | `PATCH` |

### 6.2 — Atualização pelo usuário

```bash
# Remover versão antiga
dsh plugin --profile web remove @seu-usuario/dsh-sveltekit-cloudflare

# Instalar nova versão
dsh plugin --profile web add @seu-usuario/dsh-sveltekit-cloudflare

# Reiniciar
dsh web
```

**Com versão fixada:**

```bash
dsh plugin --profile web add github:seu-usuario/dsh-sveltekit-cloudflare#v1.2.0
```

### 6.3 — CHANGELOG

Mantenha `CHANGELOG.md` atualizado. O workflow de release extrai a seção
da versão para criar a GitHub Release. Ver `docs/SETUP.md` para o formato.

---

## 7. Checklist de publicação

### Antes de publicar

- [ ] `package.json` com `dsh.bundle.patch` apontando para `cordis.patch.yml`
- [ ] `cordis.patch.yml` presente e válido
- [ ] `files` inclui `cordis.patch.yml`, `.agents/`, `scripts/`, `docs/`, `AGENTS.md`
- [ ] `name` escopado (`@seu-usuario/...`)
- [ ] `keywords` incluem `dsh-bundle` e `dsh-plugin`
- [ ] `version` segue SemVer
- [ ] `CHANGELOG.md` atualizado
- [ ] `npm pack --dry-run` mostra os arquivos corretos
- [ ] Testado localmente: `dsh plugin --profile web add .`
- [ ] `dsh --profile web --dump-config` mostra a camada
- [ ] Skills aparecem no catálogo da sessão
- [ ] Hooks disparam corretamente

### Após publicar

- [ ] `npm view @seu-usuario/dsh-sveltekit-cloudflare` retorna o pacote
- [ ] Instalação via npm funciona em profile limpo
- [ ] Instalação via GitHub funciona
- [ ] GitHub topic `dsh-plugin` adicionado
- [ ] Submetido ao DSH-Store (se aplicável)
- [ ] README atualizado com instruções de instalação
- [ ] GitHub Release criada com tag SemVer

### Manutenção contínua

- [ ] Atualizar `peerDependencies` quando o DSH mudar de versão
- [ ] Testar em cada RC do DSH
- [ ] Responder issues e PRs
- [ ] Manter docs sincronizadas

---

## 8. Referências

### Documentação oficial

- DSH Architecture: github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md
- DSH Publish Guide: github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/develop/basic/publish.md
- DSH Skill Filesystem: github.com/deepseek-ai/deepseek-harness/tree/master/packages/skill/skill-filesystem

### Bundles de referência

- Bundle base do DSH: github.com/deepseek-ai/deepseek-harness/tree/master/packages/bundle/base
- Bridge de hooks: github.com/deepseek-ai/deepseek-harness/tree/master/packages/hooks/hooks-claude-code
- `dsh-dream-skin`: github.com/RevolutionLA/dsh-dream-skin
- `dsh-plugin-marketplace`: github.com/Scorp1o117/dsh-plugin-marketplace
- `DSH-Store`: github.com/AI-Scarlett/DSH-Store

### Documentação interna

- `docs/SETUP.md` — configuração do ambiente
- `docs/HARNESS.md` — arquitetura do harness
- `docs/FEATURES.md` — inventário de componentes
- `AGENTS.md` — regras operacionais
- `CHANGELOG.md` — histórico de versões
