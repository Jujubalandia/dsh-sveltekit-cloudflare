#!/usr/bin/env bash
# ==============================================================
# scripts/git-flow.sh — fluxo Git guiado para agentes
#
# Uso:
#   ./scripts/git-flow.sh <ação> [args]
#
# Ações:
#   start <tipo>/<nome>    Cria branch a partir de develop
#   commit '<mensagem>'    Roda lint+check+secrets, então commita
#   amend                  Amend do último commit (reroda checks)
#   sync                   Atualiza branch atual com develop
#   verify                 Roda pipeline de verificação
#   push                   Push da branch atual
#   pr                     Cria PR via gh CLI contra develop
#   release <vX.Y.Z>       Cria tag de release a partir de main
#   hotfix <nome>          Cria branch de hotfix a partir de main
#   status                 Estado atual (branch, dirty, ahead/behind)
#   help                   Exibe esta ajuda
# ==============================================================

set -euo pipefail

# --------------------------------------------------------------
# Cores
# --------------------------------------------------------------
if [ -t 1 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""; BOLD=""; NC=""
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# --------------------------------------------------------------
# Helpers
# --------------------------------------------------------------
info()  { echo "${BLUE}▶${NC} $1"; }
ok()    { echo "${GREEN}✅${NC} $1"; }
warn()  { echo "${YELLOW}⚠${NC}  $1"; }
error() { echo "${RED}❌${NC} $1" >&2; }

require_clean() {
  if [ -n "$(git status --porcelain)" ]; then
    error "Working tree sujo. Faça commit ou stash antes."
    exit 1
  fi
}

require_branch() {
  local expected="$1"
  local current
  current=$(git branch --show-current)
  if [ "$current" != "$expected" ]; then
    error "Esperado estar em '$expected', mas está em '$current'."
    exit 1
  fi
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    error "$1 não encontrado. Instale antes de continuar."
    exit 1
  }
}

# --------------------------------------------------------------
# Ações
# --------------------------------------------------------------
action_start() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    error "Uso: git-flow.sh start <tipo>/<nome>"
    error "Tipos válidos: feat, fix, chore, docs, test, refactor, hotfix"
    exit 2
  fi

  # Valida prefixo
  case "$name" in
    feat/*|fix/*|chore/*|docs/*|test/*|refactor/*|hotfix/*) ;;
    *)
      error "Prefixo inválido em '$name'. Use feat/, fix/, chore/, docs/, test/, refactor/."
      exit 2 ;;
  esac

  require_clean

  info "Atualizando develop..."
  git checkout develop
  git pull --ff-only origin develop

  info "Criando branch $name a partir de develop"
  git checkout -b "$name"

  ok "Branch '$name' criada. Faça as mudanças, depois:"
  echo "   ./scripts/git-flow.sh commit '<mensagem>'"
  echo "   ./scripts/git-flow.sh verify"
  echo "   ./scripts/git-flow.sh push"
}

action_commit() {
  local msg="${1:-}"
  if [ -z "$msg" ]; then
    error "Uso: git-flow.sh commit '<mensagem>'"
    error "Formato: <tipo>: <descrição>   ex: feat: adiciona upload R2"
    exit 2
  fi

  # Valida Conventional Commits
  if ! echo "$msg" | grep -qE '^(feat|fix|chore|docs|test|refactor|perf|ci|build|style|revert)(\(.+\))?: .+'; then
    warn "Mensagem não segue Conventional Commits."
    warn "Exemplo: 'feat: adiciona endpoint de upload'"
    read -rp "Continuar assim mesmo? [y/N] " ans
    case "$ans" in
      y|Y|yes|YES) ;;
      *) error "Abortado."; exit 1 ;;
    esac
  fi

  info "Rodando lint..."
  pnpm lint

  info "Rodando type check..."
  pnpm check

  # Secrets scan apenas nos arquivos staged (se gitleaks disponível)
  git add -A
  if command -v gitleaks >/dev/null 2>&1; then
    info "Secrets scan nos arquivos staged..."
    if ! gitleaks protect --staged --redact --config .gitleaks.toml --verbose; then
      error "Secret detectado. Remova antes de commitar."
      git reset >/dev/null 2>&1 || true
      exit 1
    fi
  else
    warn "gitleaks não instalado — secrets scan será feito pelo CI."
  fi

  git commit -m "$msg"
  ok "Commit criado: $msg"
}

action_amend() {
  info "Re-rodando checks antes do amend..."
  pnpm lint
  pnpm check
  git add -A
  git commit --amend --no-edit
  ok "Amend concluído."
}

action_sync() {
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" = "develop" ] || [ "$branch" = "main" ]; then
    error "Não sincronize develop/main aqui. Use pull direto."
    exit 1
  fi
  info "Sincronizando '$branch' com develop..."
  git fetch origin develop
  git rebase origin/develop
  ok "Rebase concluído."
}

action_verify() {
  info "Rodando pipeline de verificação..."
  ./scripts/verify.sh
  ok "verify OK"
}

action_push() {
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" = "develop" ] || [ "$branch" = "main" ]; then
    error "Push direto para '$branch' não é permitido. Abra PR."
    exit 1
  fi
  info "Push de '$branch' para origin..."
  git push -u origin "$branch"
  ok "Push concluído."
  echo ""
  echo "Próximo: ./scripts/git-flow.sh pr"
}

action_pr() {
  require_tool gh
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" = "develop" ] || [ "$branch" = "main" ]; then
    error "Não abrir PR a partir de '$branch'."
    exit 1
  fi

  info "Verificando se há commits não enviados..."
  if ! git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    warn "Branch sem upstream. Faça push primeiro: ./scripts/git-flow.sh push"
    exit 1
  fi

  # Título: usa o último commit como base
  local title
  title=$(git log -1 --pretty=%s)

  echo ""
  echo "${BOLD}Resumo dos commits desta branch (vs develop):${NC}"
  git log --oneline origin/develop..HEAD | sed 's/^/  /'
  echo ""
  echo "${BOLD}Arquivos alterados (vs develop):${NC}"
  git diff --stat origin/develop...HEAD | sed 's/^/  /'
  echo ""

  local default_body
  default_body=$(cat <<'BODY'
## O quê
(descreva a mudança)

## Por quê
(motivação, issue relacionada)

## Como testar
(passos reproduzíveis)

## Evidências
- [ ] `pnpm verify` verde
- [ ] `pnpm security:scan` verde
- [ ] Screenshots (se UI)

## Impacto
- Blast radius: baixo / médio / alto
- Rollback: (como reverter)

## Checklist
- [ ] Commits atômicos
- [ ] Sem secrets
- [ ] Sem testes reescritos para passar
- [ ] CI não enfraquecido
- [ ] Diff < 400 linhas (ou justificado)
BODY
)

  read -rp "Abrir PR contra develop com o título \"$title\"? [y/N] " ans
  case "$ans" in
    y|Y|yes|YES) ;;
    *) error "Abortado."; exit 1 ;;
  esac

  gh pr create --base develop --head "$branch" --title "$title" --body "$default_body"
  ok "PR criado."
}

action_release() {
  local version="${1:-}"
  if [ -z "$version" ]; then
    error "Uso: git-flow.sh release vX.Y.Z"
    exit 2
  fi
  if ! echo "$version" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$'; then
    error "Versão inválida '$version'. Use SemVer: v1.2.3 ou v1.2.3-rc.1"
    exit 2
  fi

  require_tool gh

  info "Verificando develop..."
  git checkout develop
  git pull --ff-only origin develop

  info "Verificando main..."
  git checkout main
  git pull --ff-only origin main

  info "Abrindo PR develop -> main..."
  gh pr create --base main --head develop \
    --title "release: $version" \
    --body "Promove develop para main para release $version." || true

  warn "Após o merge do PR acima, rode novamente:"
  echo "   ./scripts/git-flow.sh release $version --tag-only"
  echo ""

  if [ "${2:-}" = "--tag-only" ]; then
    info "Criando tag $version em main..."
    git checkout main
    git pull --ff-only origin main
    git tag -a "$version" -m "Release $version"
    git push origin "$version"
    ok "Tag $version criada. Pipeline de release disparado."
  fi
}

action_hotfix() {
  local name="${1:-}"
  if [ -z "$name" ]; then
    error "Uso: git-flow.sh hotfix <nome>"
    exit 2
  fi

  require_clean
  info "Criando hotfix a partir de main..."
  git checkout main
  git pull --ff-only origin main
  git checkout -b "hotfix/$name"
  ok "Branch hotfix/$name criada."
  echo "Lembre-se: PR contra main E contra develop após o merge."
}

action_status() {
  local branch
  branch=$(git branch --show-current)
  echo "${BOLD}Branch:${NC} $branch"

  if [ -n "$(git status --porcelain)" ]; then
    echo "${YELLOW}Working tree:${NC} sujo"
    git status --short | sed 's/^/  /'
  else
    echo "${GREEN}Working tree:${NC} limpo"
  fi

  if git rev-parse --abbrev-ref --symbolic-full-name "@{u}" >/dev/null 2>&1; then
    local ahead behind
    ahead=$(git rev-list --count "@{u}..HEAD")
    behind=$(git rev-list --count "HEAD..@{u}")
    echo "Ahead:  $ahead"
    echo "Behind: $behind"
  else
    echo "Sem upstream configurado."
  fi

  echo ""
  echo "${BOLD}Últimos 5 commits:${NC}"
  git log --oneline -5 | sed 's/^/  /'
}

action_help() {
  sed -n '2,22p' "$0"
}

# --------------------------------------------------------------
# Dispatch
# --------------------------------------------------------------
ACTION="${1:-help}"
shift 2>/dev/null || true

case "$ACTION" in
  start)   action_start   "$@" ;;
  commit)  action_commit  "$@" ;;
  amend)   action_amend   "$@" ;;
  sync)    action_sync    "$@" ;;
  verify)  action_verify  "$@" ;;
  push)    action_push    "$@" ;;
  pr)      action_pr      "$@" ;;
  release) action_release "$@" ;;
  hotfix)  action_hotfix  "$@" ;;
  status)  action_status  "$@" ;;
  help|-h|--help) action_help ;;
  *)
    error "Ação desconhecida: $ACTION"
    echo ""
    action_help
    exit 2 ;;
esac
