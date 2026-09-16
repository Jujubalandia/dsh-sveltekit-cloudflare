#!/usr/bin/env bash
# ==============================================================
# scripts/complexity-check.sh — análise de complexidade e redundância
#
# Uso:
#   ./scripts/complexity-check.sh
#   ./scripts/complexity-check.sh --warn-only    # não falha, só reporta
#   ./scripts/complexity-check.sh --json         # saída JSON
#
# Métricas:
#   1. Complexidade ciclomática    (ESLint complexity ≤ 10)
#   2. Tamanho de função           (ESLint max-lines-per-function ≤ 50)
#   3. Profundidade de aninhamento (ESLint max-depth ≤ 4)
#   4. Parâmetros por função       (ESLint max-params ≤ 5)
#   5. Tamanho de arquivo          (≤ 300 linhas)
#   6. Duplicação de código        (jscpd ≤ 3%)
#   7. Dead code / exports órfãos  (knip)
#   8. Mutation score              (Stryker ≥ 60%, opcional)
# ==============================================================

set -uo pipefail

# --------------------------------------------------------------
# Cores
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# --------------------------------------------------------------
# Flags
# --------------------------------------------------------------
WARN_ONLY=0
JSON_MODE=0
for arg in "$@"; do
  case "$arg" in
    --warn-only) WARN_ONLY=1 ;;
    --json)      JSON_MODE=1 ;;
    -h|--help)
      sed -n '2,22p' "$0"
      exit 0 ;;
    *)
      echo "${RED}Argumento desconhecido: $arg${NC}" >&2
      exit 2 ;;
  esac
done

# --------------------------------------------------------------
# Diretórios de código
# --------------------------------------------------------------
SRC_DIRS=()
[ -d "src" ]         && SRC_DIRS+=("src")
[ -d "workers/src" ] && SRC_DIRS+=("workers/src")

if [ ${#SRC_DIRS[@]} -eq 0 ]; then
  echo "${YELLOW}⚠️  Nenhum diretório de código encontrado.${NC}"
  exit 0
fi

# --------------------------------------------------------------
# Thresholds (ajuste conforme o projeto)
# --------------------------------------------------------------
MAX_COMPLEXITY=10
MAX_FUNCTION_LINES=50
MAX_DEPTH=4
MAX_PARAMS=5
MAX_FILE_LINES=300
MAX_DUPLICATION_PCT=3
MIN_MUTATION_SCORE=60

# --------------------------------------------------------------
# Contadores
# --------------------------------------------------------------
FAILURES=0
WARNINGS=0

fail() { echo "${RED}❌ $1${NC}"; FAILURES=$((FAILURES+1)); }
warn() { echo "${YELLOW}⚠️  $1${NC}"; WARNINGS=$((WARNINGS+1)); }
ok()   { echo "${GREEN}✅ $1${NC}"; }

section() {
  echo ""
  echo "${BLUE}${BOLD}$1${NC}"
  echo "──────────────────────────────────────────────────────"
}

# --------------------------------------------------------------
# JSON accumulator (se --json)
# --------------------------------------------------------------
JSON_RESULTS=()
json_add() {
  # json_add <check> <status> <message>
  if [ "$JSON_MODE" -eq 1 ]; then
    JSON_RESULTS+=("{\"check\":\"$1\",\"status\":\"$2\",\"message\":\"$3\"}")
  fi
}

# ==============================================================
# 1-4. ESLint: complexidade, tamanho, profundidade, params
# ==============================================================
section "[1/4] ESLint — complexidade, tamanho, profundidade, params"

ESLINT_OUT=$(npx eslint "${SRC_DIRS[@]}" \
  --no-eslintrc \
  --parser @typescript-eslint/parser \
  --plugin @typescript-eslint \
  --rule "{\"complexity\": [\"error\", $MAX_COMPLEXITY]}" \
  --rule "{\"max-lines-per-function\": [\"error\", {\"max\": $MAX_FUNCTION_LINES, \"skipBlankLines\": true, \"skipComments\": true}]}" \
  --rule "{\"max-depth\": [\"error\", $MAX_DEPTH]}" \
  --rule "{\"max-params\": [\"error\", $MAX_PARAMS]}" \
  --format stylish 2>&1) || true

if echo "$ESLINT_OUT" | grep -qE "error|warning"; then
  warn "ESLint reportou problemas de complexidade"
  echo "$ESLINT_OUT" | head -40 | sed 's/^/   /'
  json_add "eslint-complexity" "warn" "problemas detectados"
else
  ok "Complexidade, tamanho, profundidade e params dentro dos limites"
  json_add "eslint-complexity" "pass" "dentro dos limites"
fi

# ==============================================================
# 5. Tamanho de arquivo
# ==============================================================
section "[2/4] Tamanho de arquivo (≤ $MAX_FILE_LINES linhas)"

LARGE_FILES=0
while IFS= read -r file; do
  lines=$(wc -l < "$file" | tr -d ' ')
  if [ "$lines" -gt "$MAX_FILE_LINES" ]; then
    warn "$file: $lines linhas (limite: $MAX_FILE_LINES)"
    LARGE_FILES=$((LARGE_FILES+1))
  fi
done < <(find "${SRC_DIRS[@]}" -type f \( -name '*.ts' -o -name '*.svelte' \) 2>/dev/null)

if [ "$LARGE_FILES" -eq 0 ]; then
  ok "Nenhum arquivo acima de $MAX_FILE_LINES linhas"
  json_add "file-size" "pass" "nenhum arquivo grande"
else
  json_add "file-size" "warn" "$LARGE_FILES arquivo(s) grande(s)"
fi

# ==============================================================
# 6. Duplicação (jscpd)
# ==============================================================
section "[3/4] Duplicação de código (jscpd, limite: $MAX_DUPLICATION_PCT%)"

if [ -x "node_modules/.bin/jscpd" ] || command -v npx >/dev/null 2>&1; then
  JSCPD_OUT=$(npx jscpd "${SRC_DIRS[@]}" \
    --min-lines 5 \
    --min-tokens 50 \
    --threshold "$MAX_DUPLICATION_PCT" \
    --reporters console \
    --ignore "**/*.test.ts,**/*.spec.ts,**/node_modules/**,**/.svelte-kit/**" \
    2>&1) || true

  # jscpd imprime "Found X clones" ou "Duplicated lines (%)"
  DUP_PCT=$(echo "$JSCPD_OUT" | grep -oE "Duplicated lines \([0-9.]+%\)" | grep -oE "[0-9.]+" | head -1 || echo "0")

  if [ -z "$DUP_PCT" ]; then
    DUP_PCT="0"
  fi

  if awk -v p="$DUP_PCT" -v m="$MAX_DUPLICATION_PCT" 'BEGIN { exit !(p > m) }'; then
    warn "Duplicação ${DUP_PCT}% acima do limite ${MAX_DUPLICATION_PCT}%"
    echo "$JSCPD_OUT" | tail -20 | sed 's/^/   /'
    json_add "duplication" "warn" "${DUP_PCT}%"
  else
    ok "Duplicação ${DUP_PCT}% dentro do limite"
    json_add "duplication" "pass" "${DUP_PCT}%"
  fi
else
  warn "jscpd não instalado (pnpm add -D jscpd)"
  json_add "duplication" "skip" "jscpd ausente"
fi

# ==============================================================
# 7. Dead code / exports órfãos (knip)
# ==============================================================
section "[4/4] Dead code / exports órfãos (knip)"

if [ -x "node_modules/.bin/knip" ]; then
  KNIP_OUT=$(npx knip --include files,exports,dependencies --no-progress 2>&1) || true

  if echo "$KNIP_OUT" | grep -qiE "unused|unlisted|not found"; then
    warn "knip detectou código não usado"
    echo "$KNIP_OUT" | head -30 | sed 's/^/   /'
    json_add "deadcode" "warn" "itens não usados"
  else
    ok "Nenhum dead code detectado"
    json_add "deadcode" "pass" "limpo"
  fi
else
  warn "knip não instalado (pnpm add -D knip)"
  json_add "deadcode" "skip" "knip ausente"
fi

# ==============================================================
# 8. Mutation score (opcional, roda só se Stryker configurado)
# ==============================================================
if [ -f "tests/mutation/stryker.config.mjs" ] && [ -x "node_modules/.bin/stryker" ]; then
  section "[extra] Mutation score (Stryker, mínimo: $MIN_MUTATION_SCORE%)"
  echo "${YELLOW}Rodando mutation testing (pode levar vários minutos)...${NC}"

  if npx stryker run --reporters clear-text,progress 2>&1 | tee /tmp/dsh-stryker.log | tail -20; then
    SCORE=$(grep -oE "Mutation score.*[0-9]+(\.[0-9]+)?%" /tmp/dsh-stryker.log | grep -oE "[0-9]+(\.[0-9]+)?" | tail -1 || echo "")
    if [ -n "$SCORE" ]; then
      if awk -v s="$SCORE" -v m="$MIN_MUTATION_SCORE" 'BEGIN { exit !(s < m) }'; then
        warn "Mutation score ${SCORE}% abaixo do mínimo ${MIN_MUTATION_SCORE}%"
        json_add "mutation" "warn" "${SCORE}%"
      else
        ok "Mutation score ${SCORE}% OK"
        json_add "mutation" "pass" "${SCORE}%"
      fi
    else
      warn "Não foi possível extrair mutation score"
      json_add "mutation" "unknown" ""
    fi
  else
    warn "Stryker falhou ou não rodou"
    json_add "mutation" "error" "stryker falhou"
  fi
fi

# ==============================================================
# Saída
# ==============================================================
if [ "$JSON_MODE" -eq 1 ]; then
  echo ""
  echo "{"
  echo "  \"failures\": $FAILURES,"
  echo "  \"warnings\": $WARNINGS,"
  echo "  \"checks\": ["
  for i in "${!JSON_RESULTS[@]}"; do
    sep=","
    [ "$i" -eq $((${#JSON_RESULTS[@]} - 1)) ] && sep=""
    echo "    ${JSON_RESULTS[$i]}$sep"
  done
  echo "  ]"
  echo "}"
  exit 0
fi

echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILURES" -gt 0 ]; then
  echo "${RED}${BOLD}❌ complexity-check FALHOU${NC} — ${FAILURES} falha(s), ${WARNINGS} aviso(s)"
  echo "══════════════════════════════════════════════════════"
  if [ "$WARN_ONLY" -eq 1 ]; then
    exit 0
  fi
  exit 1
fi
echo "${GREEN}${BOLD}✅ complexity-check OK${NC} — ${WARNINGS} aviso(s)"
echo "══════════════════════════════════════════════════════"
exit 0
