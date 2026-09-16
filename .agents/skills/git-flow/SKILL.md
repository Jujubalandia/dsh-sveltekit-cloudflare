---
name: git-flow
description: "Fluxo Git do projeto: branches por tarefa, commits atômicos, sincronização com develop e main, abertura de PR, release com tag e hotfix de produção. Use ao criar branch, commitar, abrir PR ou preparar um release."
---

# Skill: git-flow

## Quando usar

Carregue esta skill ao trabalhar com:
- Criar branch para nova tarefa
- Fazer commits atômicos
- Sincronizar com develop/main
- Abrir PR contra develop
- Fazer release (tag em main)
- Corrigir hotfix em produção
- Resolver conflitos de merge/rebase
- Investigar histórico Git

## Objetivo

Manter histórico limpo e auditável. Em projetos assistidos por IA,
o fluxo Git é a principal linha de defesa contra mudanças
descontroladas: commits pequenos, PRs revisáveis, releases rastreáveis.

Citação relevante (AkitaOnRails, "Boas práticas open source com LLM"):
> "O mínimo que você precisa é de CI confiável, release por tag,
> e um CHANGELOG que se mantém."

## Modelo de branches

```text
main        ← produção. Protegida. Requer PR + CI verde.
  ↑
  │ (release PR)
  │
develop     ← integração. Base para features.
  ↑
  │ (feature branches)
  │
feat/xxx    ← nova funcionalidade
fix/xxx     ← correção de bug (não urgente)
chore/xxx   ← manutenção (deps, config, docs)
docs/xxx    ← apenas documentação
test/xxx    ← apenas testes
refactor/xxx ← refatoração sem mudança de comportamento

main
  ↑
  │ (hotfix direto)
  │
hotfix/xxx  ← correção urgente em produção
```

### Regras de branch

| Branch | Base | Merge em | Proteção |
|--------|------|----------|----------|
| `main` | — | — | Protegida, PR obrigatório, CI verde, revisão |
| `develop` | `main` | `main` (release) | Protegida, PR obrigatório |
| `feat/*` | `develop` | `develop` (squash) | — |
| `fix/*` | `develop` | `develop` (squash) | — |
| `chore/*` | `develop` | `develop` (squash) | — |
| `docs/*` | `develop` | `develop` (squash) | — |
| `test/*` | `develop` | `develop` (squash) | — |
| `refactor/*` | `develop` | `develop` (squash) | — |
| `hotfix/*` | `main` | `main` + `develop` (merge) | — |

## Conventional Commits

Formato:

```text
<tipo>(<escopo opcional>): <descrição curta>

[corpo opcional]

[footer opcional]
```

### Tipos

| Tipo | Uso |
|------|-----|
| `feat` | Nova funcionalidade (bump MINOR) |
| `fix` | Correção de bug (bump PATCH) |
| `chore` | Manutenção, dependências, config |
| `docs` | Apenas documentação |
| `test` | Adicionar ou corrigir testes |
| `refactor` | Refatoração sem mudança de comportamento |
| `perf` | Melhoria de performance |
| `ci` | Mudanças em CI/CD |
| `build` | Mudanças em build ou deps de build |
| `style` | Formatação (sem mudança de lógica) |
| `revert` | Reverter commit anterior |

### Breaking changes

Adicione `!` após o tipo ou `BREAKING CHANGE:` no footer:

```text
feat!: remove endpoint legado /api/v1/users

BREAKING CHANGE: o endpoint foi removido em favor de /api/v2/users.
Clientes precisam migrar.
```

### Exemplos bons

```text
feat(auth): adiciona login com Google OAuth

fix(upload): corrige validação de tamanho em arquivos PDF

chore(deps): atualiza SvelteKit para 2.8.1

docs(readme): adiciona instruções de setup local

test(api): adiciona testes de erro 429 em rate limit

refactor(db): extrai queries de usuário para módulo dedicado
```

### Exemplos ruins

```text
❌ "fix"                                    # vago
❌ "wip"                                    # nunca
❌ "atualizações"                           # vago
❌ "feat: adiciona validação, refatora db,
   corrige bug e melhora UI"                # múltiplas coisas
❌ "Merge branch 'main' into develop"       # evitar merge commits
```

## Fluxo por tarefa

### 1. Iniciar nova feature

```bash
# Sincronizar develop
git checkout develop
git pull --ff-only origin develop

# Criar branch
git checkout -b feat/upload-r2
```

Ou via script:

```bash
./scripts/git-flow.sh start feat/upload-r2
```

### 2. Desenvolver com commits atômicos

Faça commits pequenos e independentes. Cada commit deve:
- Compilar (`pnpm check` verde).
- Passar lint (`pnpm lint` verde).
- Passar testes relacionados.
- Ter uma única intenção declarada.

```bash
git add src/routes/api/files/+server.ts
git commit -m "feat(api): adiciona endpoint de upload"

git add src/lib/server/r2.ts
git commit -m "feat(r2): adiciona helper de validação de arquivo"

git add tests/unit/r2.test.ts
git commit -m "test(r2): cobre validação de tipo e tamanho"
```

Ou via script:

```bash
./scripts/git-flow.sh commit "feat(api): adiciona endpoint de upload"
# (o script roda lint + check + gitleaks antes de commitar)
```

### 3. Verificar antes de push

```bash
pnpm verify
```

Ou:

```bash
./scripts/git-flow.sh verify
```

### 4. Push e PR

```bash
git push -u origin feat/upload-r2
```

Abrir PR via `gh`:

```bash
gh pr create --base develop --head feat/upload-r2 \
  --title "feat: adiciona endpoint de upload R2" \
  --body "..."
```

Ou:

```bash
./scripts/git-flow.sh push
./scripts/git-flow.sh pr
```

## Template de PR

Use este template em todos os PRs (o script `git-flow.sh pr` já o injeta):

```markdown
## O quê
Descrição em 1-2 frases do que a mudança faz.

## Por quê
Motivação. Link para issue/discussão/requisito.

## Como testar
Passos reproduzíveis para verificar a mudança:
1. `pnpm install`
2. `pnpm dev`
3. Acessar http://localhost:5173/upload
4. Enviar arquivo X
5. Verificar Y

## Evidências
- [ ] `pnpm verify` verde
- [ ] `pnpm security:scan` verde
- [ ] `pnpm complexity:scan` verde
- [ ] Screenshots (se UI)
- [ ] Output de testes

## Impacto
- **Blast radius:** baixo / médio / alto
- **Rollback:** `<comando ou processo>`
- **Migration D1:** sim / não (se sim, qual)

## Checklist
- [ ] Commits atômicos e descritivos
- [ ] Sem secrets
- [ ] Sem testes reescritos para passar
- [ ] CI não enfraquecido (lint/coverage mantidos)
- [ ] Diff < 400 linhas (ou justificado)
- [ ] Documentação atualizada (se aplicável)
```

## Release

### Fluxo completo

```text
1. develop está estável (CI verde, PRs mergeados)
2. Atualizar CHANGELOG.md com nova versão
3. Commit "chore(release): prepare vX.Y.Z"
4. Abrir PR develop → main
5. Após merge, criar tag em main
6. Push da tag dispara .github/workflows/release.yml
7. Pipeline cria GitHub Release com notas do CHANGELOG
```

### Comandos

```bash
# 1. Atualizar CHANGELOG manualmente
$EDITOR CHANGELOG.md

# 2. Commit e PR
git checkout develop
git add CHANGELOG.md
git commit -m "chore(release): prepare v1.2.3"
git push origin develop

gh pr create --base main --head develop \
  --title "release: v1.2.3" \
  --body "Promove develop para main para release v1.2.3."

# 3. Após merge, criar tag
git checkout main
git pull --ff-only origin main
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin v1.2.3
```

Ou via script:

```bash
./scripts/git-flow.sh release v1.2.3
# e após merge do PR:
./scripts/git-flow.sh release v1.2.3 --tag-only
```

### SemVer

- `MAJOR.MINOR.PATCH`
- **MAJOR**: breaking changes.
- **MINOR**: nova funcionalidade compatível.
- **PATCH**: correção compatível.

Pré-releases:
- `v1.2.3-rc.1` — release candidate.
- `v1.2.3-beta.1` — beta.
- `v1.2.3-alpha.1` — alpha.

## Hotfix

Correção urgente em produção:

```bash
# 1. Branch a partir de main (não develop!)
git checkout main
git pull --ff-only origin main
git checkout -b hotfix/critical-auth-bug

# 2. Corrigir com commit mínimo
git commit -m "fix(auth): corrige bypass em validação de sessão"

# 3. Verificar
pnpm verify

# 4. Push e PR contra main
git push origin hotfix/critical-auth-bug
gh pr create --base main --head hotfix/critical-auth-bug \
  --title "hotfix: corrige bypass de autenticação" \
  --body "..."

# 5. Após merge em main, aplicar em develop também
git checkout develop
git cherry-pick <commit-do-hotfix>
# ou
git merge main
git push origin develop

# 6. Nova tag
git checkout main && git pull
git tag -a v1.2.4 -m "Hotfix v1.2.4"
git push origin v1.2.4
```

Ou via script:

```bash
./scripts/git-flow.sh hotfix critical-auth-bug
```

## Sincronização e conflitos

### Atualizar branch com develop

```bash
git fetch origin develop
git rebase origin/develop
```

Prefira `rebase` a `merge` para manter histórico linear.

Se houver conflitos:

```bash
# 1. Resolver manualmente os arquivos em conflito
git status                # lista arquivos

# 2. Após resolver
git add <arquivo-resolvido>
git rebase --continue

# 3. Se der errado
git rebase --abort
```

### Nunca fazer

```bash
❌ git push --force origin main
❌ git push --force origin develop
❌ git rebase em branch compartilhada já pushed

✅ git push --force-with-lease   # apenas em branch pessoal
```

`--force-with-lease` falha se alguém empurrou algo entre o último fetch
e o push — evita sobrescrever trabalho alheio.

## Comandos úteis

### Investigar

```bash
# Quem escreveu essa linha?
git blame src/routes/+page.svelte

# Quando isso mudou?
git log -p src/lib/server/session.ts

# Buscar commit por mensagem
git log --grep="upload R2"

# Buscar commit que introduziu bug (bisect)
git bisect start
git bisect bad HEAD
git bisect good v1.2.0
# (git testa automaticamente)
git bisect reset
```

### Desfazer

```bash
# Descartar mudança em arquivo (não commitada)
git checkout -- arquivo.ts

# Desfazer último commit (mantém mudanças)
git reset --soft HEAD~1

# Desfazer último commit (descarta mudanças)
git reset --hard HEAD~1   # CUIDADO

# Reverter commit já pushed (cria novo commit)
git revert <hash>
```

### Limpar

```bash
# Remover branches locais já mergeadas
git branch --merged develop | grep -v develop | xargs git branch -d

# Remover branches remotas órfãs
git fetch --prune

# Ver branches com tracking
git branch -vv
```

## Anti-patterns

### 1. Commit gigante

```text
❌ Commit com 50 arquivos alterados, 3000 linhas de diff.
✅ Commits atômicos, cada um < 400 linhas idealmente.
```

### 2. Commit "WIP" mergeado

```text
❌ "wip" / "temp" / "fix" / "asdf" mergeados em main.
✅ Squash antes do merge para manter histórico limpo.
```

### 3. Push direto em main/develop

```bash
❌ git push origin main
✅ gh pr create --base main
```

### 4. Force push em branch compartilhada

```bash
❌ git push --force origin feat/compartilhada
✅ git push --force-with-lease origin feat/minha-branch-pessoal
```

### 5. Merge de main em vez de rebase

```bash
❌ git checkout feat/x && git merge main
✅ git checkout feat/x && git rebase main
```

### 6. Ignorar CI vermelho

```text
❌ Mergear PR com CI vermelho "porque é urgente".
✅ Corrigir CI. Se for urgente, hotfix com CI verde mínimo.
```

### 7. Commitar arquivos gerados

```bash
❌ git add .svelte-kit/ build/ node_modules/
✅ .gitignore correto + git add <arquivos específicos>
```

### 8. Reescrever histórico público

```bash
❌ git filter-branch em branch já compartilhada
✅ Coordene com o time antes de reescrever
```

## Proteção de branch (configurar no GitHub)

### main

- [x] Require pull request before merging.
- [x] Require approvals: 1.
- [x] Dismiss stale approvals on new commits.
- [x] Require status checks: `CI / ci-success`.
- [x] Require conversation resolution.
- [x] Require linear history (squash ou rebase).
- [x] Do not allow force pushes.
- [x] Do not allow deletions.
- [x] Restrict pushes to specific users/teams.

### develop

- [x] Require pull request before merging.
- [x] Require status checks: `CI / ci-success`.
- [x] Do not allow force pushes.

## Checklist antes de cada operação

### Antes de `start`

- [ ] `develop` está atualizado localmente
- [ ] Working tree limpo
- [ ] Nome da branch segue convenção (`feat/`, `fix/`, etc.)

### Antes de `commit`

- [ ] `pnpm lint` verde
- [ ] `pnpm check` verde
- [ ] `gitleaks protect --staged` verde
- [ ] Mensagem segue Conventional Commits
- [ ] Commit tem uma única intenção
- [ ] Sem arquivos gerados (`dist/`, `.svelte-kit/`)
- [ ] Sem `.env` ou secrets

### Antes de `push`

- [ ] `pnpm verify` verde
- [ ] Branch tem upstream configurado
- [ ] Sem commits em main/develop direto

### Antes de `pr`

- [ ] Título descreve a mudança
- [ ] Descrição preenchida (o quê, por quê, como testar)
- [ ] Evidências anexadas
- [ ] Blast radius avaliado
- [ ] Rollback documentado
- [ ] Diff < 400 linhas (ou justificado)

### Antes de `release`

- [ ] `develop` está estável
- [ ] CHANGELOG.md atualizado
- [ ] Versão segue SemVer
- [ ] CI verde em develop
- [ ] Migrations de D1 prontas (se aplicável)

### Antes de `hotfix`

- [ ] Bug confirmado em produção
- [ ] Impacto avaliado
- [ ] Fix mínimo (sem refatoração)
- [ ] Aplicar em `main` E `develop`

## Referências

- Conventional Commits: https://www.conventionalcommits.org/
- SemVer: https://semver.org/
- Keep a Changelog: https://keepachangelog.com/
- Git book: https://git-scm.com/book/pt-br/v2
- GitHub branch protection: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches
- AGENT.md — seção 6, Fluxo Git
- Scripts: `scripts/git-flow.sh`, `.husky/pre-commit`, `.github/workflows/ci.yml`, `.github/workflows/release.yml`
