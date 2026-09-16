# Instruções de publicação — `@jujubalandia/dsh-sveltekit-cloudflare`

Guia para publicar este bundle DSH e para instalá-lo. O bundle é uma
**camada de configuração**: ele insere a linha do bridge de hooks e
depende do `dsh-base` já montar o provider de skills.

- Pacote npm: `@jujubalandia/dsh-sveltekit-cloudflare`
- Repositório: https://github.com/Jujubalandia/dsh-sveltekit-cloudflare
- Versão atual: `1.0.0`

---

## 0. Antes de publicar

```bash
# Confirme que a árvore está limpa e no commit certo
git status
git log --oneline -1

# Confira o que o npm vai empacotar (rode a partir da raiz do repo)
npm pack --dry-run
```

O `npm pack --dry-run` deve listar no mínimo:

- `package.json`
- `cordis.patch.yml`
- `lib/` (o plugin dos comandos `/sveflare-*`)
- `.agents/` (as 12 skills + `hooks.json` + `commands/` + `templates/`)
- `scripts/` (os 8 `.sh` + `hook-dispatch.mjs` + `validate-kit.mjs`)
- `docs/`
- `AGENTS.md`
- `harness.config.yml`

Se algum desses faltar, ajuste o campo `files` do `package.json`.

> O campo `files` não inclui `test-install.sh`, `.husky/`, `.github/`,
> `tests/`, `migrations/` nem os `wrangler*.toml`. Isso é intencional:
> são artefatos do repositório-projeto, não do bundle. Quem quiser o kit
> completo (como scaffold de projeto SvelteKit) deve clonar o repositório
> em vez de instalar o pacote npm.

---

## 1. Publicar no npm

> ⚠️ `npm publish` é irreversível para a versão publicada. O nome já
> existe na sua conta? Confirme com `npm view @jujubalandia/dsh-sveltekit-cloudflare`.

```bash
# 1. Autentique-se (uma vez)
npm login

# 2. Confirme quem você é
npm whoami

# 3. Publique como pacote público e escopado
npm publish --access public
```

`--access public` é obrigatório para pacotes escopados (`@usuario/...`),
que por padrão são privados — e um bundle privado não serve para
distribuição.

Para publicar uma nova versão depois:

```bash
npm version patch    # ou minor / major
git push --follow-tags
npm publish --access public
```

---

## 2. Instalar via GitHub

```bash
dsh plugin --profile web add github:Jujubalandia/dsh-sveltekit-cloudflare
```

### A armadilha do build em instalação via git

Uma instalação via git baixa **fontes, não artefatos prontos**. Nada roda
o seu script `build`. Este bundle **não tem código de plugin para compilar**
(ele só referencia plugins por nome e entrega skills/config), então em
princípio não precisa de build.

Ainda assim, o pnpm ≥ 10 pode recusar rodar scripts de instalação de
dependência git até que você permita. Se o primeiro `add` falhar, copie a
chave de pacote que o `dsh`/pnpm imprimir para o `pnpm-workspace.yaml` do
profile:

```yaml
allowBuilds:
  '@jujubalandia/dsh-sveltekit-cloudflare': true
```

e rode o `add` de novo.

Trate essa permissão como **permissão para executar código do pacote na sua
máquina em tempo de instalação**, fora de qualquer sandbox do agente. Fixe
um commit para que um push posterior não mude o que roda:

```bash
dsh plugin --profile web add github:Jujubalandia/dsh-sveltekit-cloudflare#<sha>
```

---

## 3. Instalar via npm

```bash
dsh plugin --profile web add @jujubalandia/dsh-sveltekit-cloudflare
```

Esta é a forma recomendada: o npm entrega o pacote pré-compilado e nenhuma
permissão de build é necessária.

---

## 4. Verificar a instalação

```bash
# A camada do bundle deve aparecer com um comentário "# == ..."
dsh --profile web --dump-config | grep -i sveflare

# As duas linhas inseridas pelo bundle devem estar na árvore
dsh --profile web --dump-config | grep sveflare-commands
dsh --profile web --dump-config | grep sveflare-hooks

# O bridge de hooks deve estar montado com o nome real do pacote
dsh --profile web --dump-config | grep dsh-hooks-claude-code
```

O que você deve ver:

```yaml
- id: sveflare-commands
  name: './lib/commands.mjs'
  config:
    commands:
      - name: sveflare-spec
        file: .agents/commands/sveflare-spec.md
      # ... plan, goal, verify, ship

- id: sveflare-hooks
  name: '@deepseek-ai/dsh-hooks-claude-code'
  config:
    configPath: './.agents/hooks.json'
```

Com o bundle ativo, os cinco comandos aparecem na sessão:

```text
/sveflare-spec     /sveflare-plan   /sveflare-goal
/sveflare-verify   /sveflare-ship
```

**Sinais de problema:**

| Sintoma | Causa provável |
|---|---|
| `patch: entry ... not found` | linha de patch de topo sem `insert:` |
| camada não aparece no dump | `dsh.bundle.patch` ausente/errado no `package.json` |
| `could not load hook config` | `configPath` não resolve contra o cwd do processo DSH |
| nenhuma skill no catálogo | `SKILL.md` sem frontmatter `name` + `description` |
| `/sveflare-*` não aparecem | linha `sveflare-commands` ausente, ou `config.commands[].file` apontando para arquivo inexistente |
| `lib/commands.mjs` não resolve | o diretório `lib/` ficou fora do campo `files` do `package.json` |

Antes de publicar, valide a integridade do kit — esse script pega
justamente os erros silenciosos acima:

```bash
node scripts/validate-kit.mjs
```

Teste automatizado de instalação:

```bash
./test-install.sh
```

Ele instala num profile dedicado (`sveltekit-bundle-test`), roda essas
verificações e limpa no final — sem tocar no seu profile `web`.

---

## 5. Remover o bundle

```bash
dsh plugin --profile web remove @jujubalandia/dsh-sveltekit-cloudflare
```

Isso remove a dependência **e** a camada de `dsh.profile.bundles`. Vale
tanto para instalações via npm quanto via git (use o mesmo specifier que
você passou no `add`).

---

## 6. O que o bundle faz — e o que ele não faz

**Faz:**

- Insere a linha `sveflare-commands`, montando o plugin `lib/commands.mjs`
  que registra os cinco comandos `/sveflare-*` a partir dos prompts em
  `.agents/commands/*.md`.
- Insere a linha `sveflare-hooks`, montando
  `@deepseek-ai/dsh-hooks-claude-code` apontando para `.agents/hooks.json`.
- Entrega 12 skills em `.agents/skills/`, descobertas pelo
  `@deepseek-ai/dsh-skill-filesystem` que o `dsh-base` já monta com
  `includeDefaultRoots: true`.

**Por que os comandos precisam de um plugin:** o `@deepseek-ai/dsh-commands`
é um registry em que cada plugin se registra **por código**
(`ctx.commands.register(definition)`). Ele não tem schema de configuração e
**nada no DSH varre `.agents/commands/`** — por isso o bundle traz
`lib/commands.mjs`, que lê os prompts e os registra.

**Não faz (e por quê):**

- **Não registra um provider de skills próprio.** Seria redundante: o
  `dsh-base` já descobre `<projectRoot>/.agents/skills`.
- **Não define subagentes.** `@deepseek-ai/dsh-subagent` é o Service
  Definition do seam `ctx.subagents` e não expõe config `agents`. Papéis
  nomeados no DSH são **Agent Presets**: um diretório com `agent.cordis.yml`
  descoberto pelos preset roots — não uma linha de bundle.
- **Não registra PreCommit nem PrePR.** Esses não são eventos do bridge de
  hooks do DSH. Eles vivem nos hooks de git: `.husky/pre-commit` e
  `.husky/pre-push`.

---

## 7. Checklist de publicação

- [ ] `git status` limpo, no commit desejado
- [ ] `node scripts/validate-kit.mjs` passa sem falhas
- [ ] `npm pack --dry-run` lista `cordis.patch.yml`, `lib/` e `.agents/`
- [ ] `./test-install.sh` passa num ambiente com `dsh` no PATH
- [ ] `npm view @jujubalandia/dsh-sveltekit-cloudflare` ainda não existe (ou a versão é nova)
- [ ] `npm publish --access public`
- [ ] `dsh plugin --profile web add @jujubalandia/dsh-sveltekit-cloudflare` funciona a partir de outro diretório
- [ ] Os cinco `/sveflare-*` aparecem na sessão após a instalação
- [ ] Repositório no GitHub marcado como **Template** se você quiser que ele sirva de scaffold
