#!/usr/bin/env bash
# ==============================================================
# scripts/owasp-check.sh — verificação automatizada OWASP Top 10
#
# Uso:
#   ./scripts/owasp-check.sh
#   ./scripts/owasp-check.sh --warn-only    # não falha, só reporta
#
# Cobre (adaptado para SvelteKit + Cloudflare + AI Gateway):
#   A01 Broken Access Control
#   A02 Cryptographic Failures
#   A03 Injection (SQL, eval, XSS, prompt injection)
#   A04 Insecure Design (rate limit, timeouts)
#   A05 Security Misconfiguration (CORS, headers)
#   A06 Vulnerable Components (pnpm audit)
#   A07 Authentication Failures (cookies, localStorage)
#   A08 Data Integrity Failures (signed URLs, migrations)
#   A09 Logging Failures (PII em logs)
#   A10 SSRF (fetch de URL do usuário, provider direto)
# ==============================================================

set -uo pipefail   # sem -e: queremos continuar após um check falhar

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
for arg in "$@"; do
  case "$arg" in
    --warn-only) WARN_ONLY=1 ;;
    -h|--help)
      sed -n '2,24p' "$0"
      exit 0 ;;
    *)
      echo "${RED}Argumento desconhecido: $arg${NC}" >&2
      exit 2 ;;
  esac
done

# --------------------------------------------------------------
# Diretórios de código
# --------------------------------------------------------------
SRC_DIRS=("src" "workers/src")
EXISTING_SRC=()
for d in "${SRC_DIRS[@]}"; do
  [ -d "$d" ] && EXISTING_SRC+=("$d")
done

if [ ${#EXISTING_SRC[@]} -eq 0 ]; then
  echo "${YELLOW}⚠️  Nenhum diretório src/ ou workers/src/ encontrado.${NC}"
  exit 0
fi

# --------------------------------------------------------------
# Contadores e helpers
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

# grep que ignora arquivos de teste e node_modules
grep_code() {
  grep -rn --include='*.ts' --include='*.js' \
       --include='*.svelte' --include='*.tsx' \
       --exclude-dir=node_modules \
       --exclude-dir=.svelte-kit \
       --exclude-dir=build \
       --exclude-dir=dist \
       --exclude='*.test.ts' \
       --exclude='*.spec.ts' \
       "$@" "${EXISTING_SRC[@]}" 2>/dev/null
}

# ==============================================================
# A01 — Broken Access Control
# ==============================================================
section "A01 — Broken Access Control"

# Rotas protegidas devem ter guard em +layout.server.ts ou +page.server.ts
if [ -d "src/routes" ]; then
  HAS_GUARD=$(grep -rl "locals.user\|requireAuth\|getSession" src/routes 2>/dev/null | wc -l | tr -d ' ')
  if [ "$HAS_GUARD" -gt 0 ]; then
    ok "Guard server-side presente em $HAS_GUARD arquivo(s) de rotas"
  else
    warn "Nenhum guard server-side detectado (locals.user / requireAuth)"
  fi
fi

# Não confiar em role vindo do cliente
if grep_code "role.*req\.\|role.*event\.request\|role.*params" >/dev/null 2>&1; then
  warn "Possível uso de role do cliente sem validação server-side"
else
  ok "Nenhum uso aparente de role do cliente"
fi

# ==============================================================
# A02 — Cryptographic Failures
# ==============================================================
section "A02 — Cryptographic Failures"

# Cookies devem ter httpOnly + secure
COOKIE_ISSUES=0
while IFS= read -r line; do
  if echo "$line" | grep -q "cookies.set"; then
    file=$(echo "$line" | cut -d: -f1)
    if ! grep -q "httpOnly" "$file" 2>/dev/null; then
      warn "Cookie sem httpOnly em $file"
      COOKIE_ISSUES=$((COOKIE_ISSUES+1))
    fi
    if ! grep -q "secure" "$file" 2>/dev/null; then
      warn "Cookie sem secure em $file"
      COOKIE_ISSUES=$((COOKIE_ISSUES+1))
    fi
  fi
done < <(grep_code "cookies.set" 2>/dev/null || true)
[ "$COOKIE_ISSUES" -eq 0 ] && ok "Cookies com httpOnly/secure OK"

# Comparação insegura de secrets
if grep_code "=== .*secret\|== .*secret\|secret.* ==\|token.* ===" >/dev/null 2>&1; then
  fail "Comparação de secret com == ou === (use timingSafeEqual)"
else
  ok "Nenhuma comparação insegura de secret"
fi

# ==============================================================
# A03 — Injection
# ==============================================================
section "A03 — Injection"

# SQL concatenado (D1)
if grep_code 'DB.prepare(`' | grep -v '\.bind(' >/dev/null 2>&1; then
  fail "D1 query com template string sem .bind()"
  grep_code 'DB.prepare(`' | grep -v '\.bind(' | sed 's/^/   /'
else
  ok "Nenhuma D1 query sem .bind()"
fi

# SQL com concatenação
if grep_code 'DB.prepare(.*+.*)' >/dev/null 2>&1; then
  fail "D1 query com concatenação de string"
else
  ok "Nenhuma D1 query com concatenação"
fi

# eval / new Function
if grep_code "eval(\|new Function(" >/dev/null 2>&1; then
  fail "eval() ou new Function() detectado"
else
  ok "Nenhum eval() / new Function()"
fi

# innerHTML com dado não sanitizado
if grep_code "innerHTML" >/dev/null 2>&1; then
  warn "Uso de innerHTML detectado — confirme sanitização"
else
  ok "Nenhum innerHTML direto"
fi

# Prompt injection: input do usuário direto em prompt LLM
if grep_code 'prompt.*\${.*request\|prompt.*\${.*body\|prompt.*\${.*params' >/dev/null 2>&1; then
  fail "Possível prompt injection: input do usuário direto em prompt LLM"
else
  ok "Nenhum input direto em prompt LLM aparente"
fi

# ==============================================================
# A04 — Insecure Design
# ==============================================================
section "A04 — Insecure Design"

# Rate limiting em endpoints
RATE_LIMITED=$(grep -rl "rateLimit\|rate-limit\|RateLimiter" src workers 2>/dev/null | wc -l | tr -d ' ')
if [ "$RATE_LIMITED" -gt 0 ]; then
  ok "Rate limiting referenciado em $RATE_LIMITED arquivo(s)"
else
  warn "Nenhuma referência a rate limiting (endpoints públicos precisam)"
fi

# Timeout em fetch externo
FETCH_NO_TIMEOUT=0
while IFS= read -r line; do
  file=$(echo "$line" | cut -d: -f1)
  if ! grep -q "AbortSignal\|timeout\|AbortController" "$file" 2>/dev/null; then
    warn "fetch sem timeout aparente em $file"
    FETCH_NO_TIMEOUT=$((FETCH_NO_TIMEOUT+1))
  fi
done < <(grep_code "await fetch(" 2>/dev/null || true)
[ "$FETCH_NO_TIMEOUT" -eq 0 ] && ok "Fetches com timeout configurado"

# ==============================================================
# A05 — Security Misconfiguration
# ==============================================================
section "A05 — Security Misconfiguration"

# CORS wildcard
if grep_code "origin: '\*'\|origin: \"\*\"\|Access-Control-Allow-Origin.*\*" >/dev/null 2>&1; then
  fail "CORS com wildcard (*) detectado"
else
  ok "Nenhum CORS wildcard"
fi

# Stack trace em resposta
if grep_code "error: e\.stack\|error: error\.stack\|json(.*stack" >/dev/null 2>&1; then
  fail "Stack trace sendo retornado ao cliente"
else
  ok "Nenhum stack trace em resposta"
fi

# Headers de segurança (opcional: checar se há _headers)
if [ -f "static/_headers" ] || [ -f "public/_headers" ]; then
  ok "Arquivo _headers presente (Cloudflare Pages)"
else
  warn "Nenhum static/_headers — considere adicionar CSP, HSTS, X-Frame-Options"
fi

# ==============================================================
# A06 — Vulnerable Components
# ==============================================================
section "A06 — Vulnerable Components"

if command -v pnpm >/dev/null 2>&1; then
  if pnpm audit --audit-level high >/dev/null 2>&1; then
    ok "pnpm audit: nenhuma vulnerabilidade high/critical"
  else
    warn "pnpm audit reportou vulnerabilidades high/critical (rode manualmente)"
  fi
else
  warn "pnpm não disponível — não foi possível rodar audit"
fi

# ==============================================================
# A07 — Authentication Failures
# ==============================================================
section "A07 — Authentication Failures"

# Tokens em localStorage
if grep_code "localStorage.setItem.*[Tt]oken\|localStorage.setItem.*[Ss]ession" >/dev/null 2>&1; then
  fail "Token/sessão em localStorage"
else
  ok "Nenhum token em localStorage"
fi

# Session sem validação em hooks.server.ts
if [ -f "src/hooks.server.ts" ]; then
  if grep -q "locals.user\|validateSession\|getSession" src/hooks.server.ts; then
    ok "hooks.server.ts valida sessão"
  else
    warn "hooks.server.ts não valida sessão aparentemente"
  fi
else
  warn "src/hooks.server.ts ausente"
fi

# ==============================================================
# A08 — Data Integrity Failures
# ==============================================================
section "A08 — Data Integrity Failures"

# Signed URLs R2 com expiração
if grep -rn "getSignedUrl\|createSignedUrl\|presign" src workers 2>/dev/null >/dev/null; then
  if grep -rn "expiresIn\|expires" src workers 2>/dev/null | grep -q "expires"; then
    ok "Signed URLs R2 com expiração configurada"
  else
    warn "Signed URLs R2 sem expiração aparente"
  fi
else
  ok "Nenhum uso de signed URL (não aplicável)"
fi

# Migrations versionadas
if [ -d "migrations" ]; then
  MIG_COUNT=$(find migrations -name '*.sql' 2>/dev/null | wc -l | tr -d ' ')
  if [ "$MIG_COUNT" -gt 0 ]; then
    ok "$MIG_COUNT migration(s) versionada(s)"
  else
    warn "Diretório migrations/ vazio"
  fi
else
  warn "Diretório migrations/ ausente"
fi

# ==============================================================
# A09 — Logging Failures
# ==============================================================
section "A09 — Logging Failures"

if grep_code "console.log.*password\|console.log.*token\|console.log.*secret\|console.log.*email\|console.log.*cpf" >/dev/null 2>&1; then
  fail "Possível log de PII ou secret"
  grep_code "console.log.*password\|console.log.*token\|console.log.*secret\|console.log.*email\|console.log.*cpf" | sed 's/^/   /'
else
  ok "Nenhum log de PII/secret óbvio"
fi

# ==============================================================
# A10 — SSRF
# ==============================================================
section "A10 — SSRF"

# Fetch direto a providers LLM
if grep_code "api.openai.com\|api.anthropic.com\|generativelanguage.googleapis.com" \
    | grep -v "AI_GATEWAY_URL" >/dev/null 2>&1; then
  fail "Chamada direta a provider LLM (deve ir via AI Gateway)"
else
  ok "Nenhuma chamada direta a provider LLM"
fi

# Fetch de URL fornecida pelo usuário
if grep_code "fetch(.*request\.\|fetch(.*body\.\|fetch(.*params\." >/dev/null 2>&1; then
  warn "fetch() com URL vinda do cliente — validar contra allowlist"
else
  ok "Nenhum fetch de URL do cliente"
fi

# ==============================================================
# Resumo
# ==============================================================
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILURES" -gt 0 ]; then
  echo "${RED}${BOLD}❌ OWASP check FALHOU${NC} — ${FAILURES} falha(s), ${WARNINGS} aviso(s)"
  echo "══════════════════════════════════════════════════════"
  if [ "$WARN_ONLY" -eq 1 ]; then
    echo "${YELLOW}Modo --warn-only: não falha o pipeline.${NC}"
    exit 0
  fi
  exit 1
fi
echo "${GREEN}${BOLD}✅ OWASP check OK${NC} — ${WARNINGS} aviso(s)"
echo "══════════════════════════════════════════════════════"
exit 0
