#!/usr/bin/env bash
# ==============================================================
# scripts/verify.sh — pipeline completo de verificação
#
# Uso:
#   ./scripts/verify.sh                # pipeline completo
#   ./scripts/verify.sh --fast         # pula e2e (para pre-push local)
#   ./scripts/verify.sh --no-build     # pula build
#
# Etapas:
#   1. Type check  (pnpm check)
#   2. Lint        (pnpm lint)
#   3. Unit tests  (pnpm test:coverage)
#   4. Build       (pnpm build)
#   5. E2E         (pnpm test:e2e)  [opcional via --fast]
# ==============================================================

set -euo pipefail

# --------------------------------------------------------------
# Cores (desabilitadas se não for TTY)
# --------------------------------------------------------------
if [ -t 1 ]; then
  RED=$'\033[0;31m'
  GREEN=$'\033[0;32m'
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; NC=""
fi

# --------------------------------------------------------------
# Diretório raiz do projeto (independente de onde é chamado)
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# --------------------------------------------------------------
# Flags
# --------------------------------------------------------------
FAST=0
SKIP_BUILD=0
for arg in "$@"; do
  case "$arg" in
    --fast)      FAST=1 ;;
    --no-build)  SKIP_BUILD=1 ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      echo "${RED}Argumento desconhecido: $arg${NC}" >&2
      exit 2
      ;;
  esac
done

# --------------------------------------------------------------
# Helpers
# --------------------------------------------------------------
START_TIME=$(date +%s)
FAILED_STEP=""

run_step() {
  local label="$1"; shift
  local num="$1"; shift
  local total="$1"; shift

  echo ""
  echo "${BLUE}${BOLD}▶ [$num/$total] $label${NC}"
  echo "──────────────────────────────────────────────────────"

  local step_start
  step_start=$(date +%s)

  if "$@"; then
    local step_end
    step_end=$(date +%s)
    local elapsed=$((step_end - step_start))
    echo "${GREEN}✅ $label OK (${elapsed}s)${NC}"
  else
    local step_end
    step_end=$(date +%s)
    local elapsed=$((step_end - step_start))
    echo "${RED}❌ $label FALHOU (${elapsed}s)${NC}"
    FAILED_STEP="$label"
    return 1
  fi
}

on_exit() {
  local exit_code=$?
  local end_time
  end_time=$(date +%s)
  local total=$((end_time - START_TIME))

  echo ""
  echo "══════════════════════════════════════════════════════"
  if [ "$exit_code" -eq 0 ]; then
    echo "${GREEN}${BOLD}✅ verify OK${NC} — ${total}s"
  else
    echo "${RED}${BOLD}❌ verify FALHOU${NC} em '${FAILED_STEP}' — ${total}s"
  fi
  echo "══════════════════════════════════════════════════════"
  exit "$exit_code"
}
trap on_exit EXIT

# --------------------------------------------------------------
# Pré-checagem: node_modules
# --------------------------------------------------------------
if [ ! -d "node_modules" ]; then
  echo "${YELLOW}⚠️  node_modules ausente. Rodando 'pnpm install'...${NC}"
  pnpm install --frozen-lockfile
fi

# --------------------------------------------------------------
# Define etapas conforme flags
# --------------------------------------------------------------
STEPS=()
if [ "$SKIP_BUILD" -eq 0 ]; then
  STEPS+=(build)
fi
if [ "$FAST" -eq 0 ]; then
  STEPS+=(e2e)
fi

TOTAL=$(( 3 + ${#STEPS[@]} ))   # check, lint, test + steps opcionais

# --------------------------------------------------------------
# Execução
# --------------------------------------------------------------
echo "${BOLD}DSH verify — pipeline completo${NC}"
echo "Raiz: $ROOT_DIR"
echo "Flags: FAST=$FAST SKIP_BUILD=$SKIP_BUILD"

STEP_NUM=1

run_step "Type check"  "$STEP_NUM" "$TOTAL" pnpm check; STEP_NUM=$((STEP_NUM+1))
run_step "Lint"        "$STEP_NUM" "$TOTAL" pnpm lint;  STEP_NUM=$((STEP_NUM+1))
run_step "Unit tests"  "$STEP_NUM" "$TOTAL" pnpm test:coverage; STEP_NUM=$((STEP_NUM+1))

if [ "$SKIP_BUILD" -eq 0 ]; then
  run_step "Build" "$STEP_NUM" "$TOTAL" bash -c "NODE_ENV=production pnpm build"
  STEP_NUM=$((STEP_NUM+1))
fi

if [ "$FAST" -eq 0 ]; then
  run_step "E2E tests" "$STEP_NUM" "$TOTAL" bash -c "CI=true pnpm test:e2e"
  STEP_NUM=$((STEP_NUM+1))
fi

# Sucesso — o trap on_exit mostra o resumo
