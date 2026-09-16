#!/usr/bin/env bash
# ==============================================================
# scripts/smoke-test.sh — verificação pós-deploy
#
# Uso:
#   ./scripts/smoke-test.sh                     # staging (padrão)
#   ./scripts/smoke-test.sh production
#   ./scripts/smoke-test.sh staging --base https://custom.url
#
# Verifica:
#   - Endpoints críticos retornam 200
#   - Headers de segurança presentes
#   - Latência dentro do esperado
#   - Health check responde JSON válido
#   - Timeout e retries configurados
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
# Argumentos
# --------------------------------------------------------------
ENV="${1:-staging}"
shift 2>/dev/null || true

CUSTOM_BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) CUSTOM_BASE="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0 ;;
    *) shift ;;
  esac
done

# --------------------------------------------------------------
# Determinar URL base
# --------------------------------------------------------------
if [ -n "$CUSTOM_BASE" ]; then
  BASE="$CUSTOM_BASE"
elif [ -n "${SMOKE_BASE_URL:-}" ]; then
  BASE="$SMOKE_BASE_URL"
else
  case "$ENV" in
    production|prod) BASE="https://myapp.pages.dev" ;;
    staging|stage)   BASE="https://myapp-staging.pages.dev" ;;
    *)               BASE="https://myapp-${ENV}.pages.dev" ;;
  esac
fi

# --------------------------------------------------------------
# Configurações
# --------------------------------------------------------------
TIMEOUT=15
MAX_LATENCY_MS=2000
ENDPOINTS=(
  "/"
  "/api/health"
)

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
# Verificar curl disponível
# --------------------------------------------------------------
if ! command -v curl >/dev/null 2>&1; then
  echo "${RED}❌ curl não está instalado.${NC}"
  exit 2
fi

echo "${BOLD}DSH smoke test${NC}"
echo "Ambiente: $ENV"
echo "Base URL: $BASE"
echo "Timeout:  ${TIMEOUT}s"
echo ""

# ==============================================================
# 1. Endpoints críticos
# ==============================================================
section "[1/4] Endpoints críticos"

for path in "${ENDPOINTS[@]}"; do
  url="${BASE}${path}"

  # Mede tempo e status
  RESPONSE=$(curl -s -o /tmp/dsh-smoke-body.txt -w "%{http_code}|%{time_total}" \
    --max-time "$TIMEOUT" \
    --retry 2 \
    --retry-delay 1 \
    --retry-connrefused \
    "$url" 2>/dev/null) || RESPONSE="000|0"

  STATUS=$(echo "$RESPONSE" | cut -d'|' -f1)
  TIME_S=$(echo "$RESPONSE" | cut -d'|' -f2)
  TIME_MS=$(awk -v t="$TIME_S" 'BEGIN { printf "%.0f", t * 1000 }')

  if [ "$STATUS" = "200" ]; then
    if [ "$TIME_MS" -gt "$MAX_LATENCY_MS" ]; then
      warn "$path → 200 (${TIME_MS}ms, acima de ${MAX_LATENCY_MS}ms)"
    else
      ok "$path → 200 (${TIME_MS}ms)"
    fi
  elif [ "$STATUS" = "000" ]; then
    fail "$path → sem resposta (timeout/conexão recusada)"
  else
    fail "$path → HTTP $STATUS"
  fi
done

# ==============================================================
# 2. Health check com payload válido
# ==============================================================
section "[2/4] Health check (payload)"

HEALTH_URL="${BASE}/api/health"
HEALTH_BODY=$(curl -s --max-time "$TIMEOUT" "$HEALTH_URL" 2>/dev/null || echo "")

if [ -z "$HEALTH_BODY" ]; then
  warn "Health check não retornou corpo"
elif echo "$HEALTH_BODY" | grep -qE '"status"\s*:\s*"(ok|healthy|up)"' ; then
  ok "Health check retorna status ok"
elif echo "$HEALTH_BODY" | head -c 1 | grep -q "{"; then
  ok "Health check retorna JSON"
  echo "   Resposta: $(echo "$HEALTH_BODY" | head -c 120)"
else
  warn "Health check não retorna JSON esperado"
  echo "   Resposta: $(echo "$HEALTH_BODY" | head -c 120)"
fi

# ==============================================================
# 3. Headers de segurança
# ==============================================================
section "[3/4] Headers de segurança"

HEADERS=$(curl -sI --max-time "$TIMEOUT" "$BASE/" 2>/dev/null || echo "")

check_header() {
  local name="$1"
  local required="${2:-warn}"
  if echo "$HEADERS" | grep -qi "^${name}:"; then
    ok "$name presente"
  else
    if [ "$required" = "fail" ]; then
      fail "$name ausente"
    else
      warn "$name ausente"
    fi
  fi
}

check_header "X-Content-Type-Options" "warn"
check_header "X-Frame-Options"        "warn"
check_header "Strict-Transport-Security" "warn"
check_header "Content-Security-Policy"   "warn"
check_header "Referrer-Policy"        "warn"

# Server header não deve expor versão
if echo "$HEADERS" | grep -qiE "^Server:.*[0-9]+\.[0-9]+"; then
  warn "Server header expõe versão"
fi

# ==============================================================
# 4. Verificar ausência de stack trace em erro
# ==============================================================
section "[4/4] Verificação de vazamento em erro"

# Testa 404
NOT_FOUND_URL="${BASE}/__dsh_smoke_nonexistent_$(date +%s)"
NOT_FOUND_BODY=$(curl -s --max-time "$TIMEOUT" "$NOT_FOUND_URL" 2>/dev/null || echo "")

if echo "$NOT_FOUND_BODY" | grep -qiE "stack trace|at Object\.|at Module\.|node_modules"; then
  fail "404 expõe stack trace"
elif echo "$NOT_FOUND_BODY" | grep -qiE "env\.|process\.env|DB\.|KV\.|R2\."; then
  fail "404 expõe detalhes de runtime"
else
  ok "404 não expõe informação sensível"
fi

# ==============================================================
# Resumo
# ==============================================================
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILURES" -gt 0 ]; then
  echo "${RED}${BOLD}❌ smoke test FALHOU${NC} — ${FAILURES} falha(s), ${WARNINGS} aviso(s)"
  echo "Base: $BASE"
  echo "══════════════════════════════════════════════════════"
  exit 1
fi
echo "${GREEN}${BOLD}✅ smoke test OK${NC} — ${WARNINGS} aviso(s)"
echo "Base: $BASE"
echo "══════════════════════════════════════════════════════"
exit 0
