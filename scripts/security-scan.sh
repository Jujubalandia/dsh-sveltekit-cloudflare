#!/usr/bin/env bash
# ==============================================================
# scripts/security-scan.sh — verificação de segurança completa
#
# Uso:
#   ./scripts/security-scan.sh
#   ./scripts/security-scan.sh --staged     # só arquivos staged (pre-commit)
#   ./scripts/security-scan.sh --ci         # modo CI (não falha em warnings)
#
# Etapas:
#   1. Secrets scan       (gitleaks)
#   2. Dependências       (pnpm audit)
#   3. D1 migrations      (wrangler d1 migrations list)
#   4. OWASP Top 10       (scripts/owasp-check.sh)
#   5. AI Gateway         (verificação manual assistida)
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
MODE="full"
for arg in "$@"; do
  case "$arg" in
    --staged) MODE="staged" ;;
    --ci)     MODE="ci" ;;
    -h|--help)
      sed -n '2,16p' "$0"
      exit 0 ;;
    *)
      echo "${RED}Argumento desconhecido: $arg${NC}" >&2
      exit 2 ;;
  esac
done

# --------------------------------------------------------------
# Contadores
# --------------------------------------------------------------
FAILURES=0
WARNINGS=0

fail() { echo "${RED}❌ $1${NC}"; FAILURES=$((FAILURES+1)); }
warn() { echo "${YELLOW}⚠️  $1${NC}"; WARNINGS=$((WARNINGS+1)); }
ok()   { echo "${GREEN}✅ $1${NC}"; }

banner() {
  echo ""
  echo "${BLUE}${BOLD}▶ $1${NC}"
  echo "──────────────────────────────────────────────────────"
}

# --------------------------------------------------------------
# 1. Secrets scan — gitleaks
# --------------------------------------------------------------
banner "[1/5] Secrets scan (gitleaks)"

if command -v gitleaks >/dev/null 2>&1; then
  if [ "$MODE" = "staged" ]; then
    if gitleaks protect --staged --redact --config .gitleaks.toml --verbose; then
      ok "Nenhum secret nos arquivos staged"
    else
      fail "Secret detectado nos arquivos staged"
    fi
  else
    if gitleaks detect --source . --redact --config .gitleaks.toml --verbose \
        --report-format json --report-path gitleaks-report.json; then
      ok "Nenhum secret detectado"
    else
      fail "Secret(s) detectado(s) — ver gitleaks-report.json"
    fi
  fi
else
  warn "gitleaks não instalado (pule este check localmente)"
  if [ "$MODE" = "ci" ]; then
    fail "gitleaks é obrigatório em CI"
  fi
fi

# --------------------------------------------------------------
# 2. Dependências — pnpm audit
# --------------------------------------------------------------
banner "[2/5] Audit de dependências (pnpm audit)"

if pnpm audit --audit-level high --json > /tmp/dsh-audit.json 2>/dev/null; then
  ok "Nenhuma vulnerabilidade high/critical"
else
  # Distingue "vulnerabilidade encontrada" de "falha de rede"
  if grep -q '"vulnerabilities"' /tmp/dsh-audit.json 2>/dev/null; then
    warn "Vulnerabilidades high/critical detectadas"
    pnpm audit --audit-level high || true
    if [ "$MODE" = "ci" ]; then
      fail "pnpm audit falhou em modo CI"
    fi
  else
    warn "Não foi possível executar pnpm audit (verifique rede/registry)"
  fi
fi

# --------------------------------------------------------------
# 3. D1 migrations — verificar pendências
# --------------------------------------------------------------
banner "[3/5] D1 migrations (wrangler d1 migrations list)"

if command -v wrangler >/dev/null 2>&1 && [ -f "wrangler.toml" ]; then
  if wrangler d1 migrations list DB --env staging 2>/dev/null; then
    ok "Migrations listadas (verifique se há pendências para staging)"
  else
    warn "Não foi possível listar migrations (DB staging não configurado?)"
  fi
else
  warn "wrangler não encontrado ou wrangler.toml ausente"
fi

# --------------------------------------------------------------
# 4. OWASP Top 10
# --------------------------------------------------------------
banner "[4/5] OWASP Top 10 (scripts/owasp-check.sh)"

if [ -x "scripts/owasp-check.sh" ]; then
  if ./scripts/owasp-check.sh; then
    ok "OWASP check passou"
  else
    fail "OWASP check falhou"
  fi
else
  warn "scripts/owasp-check.sh não encontrado ou não executável"
fi

# --------------------------------------------------------------
# 5. AI Gateway — checklist manual assistida
# --------------------------------------------------------------
banner "[5/5] AI Gateway — checklist manual"

echo "Verifique no dashboard Cloudflare (não automatizável aqui):"
echo "  [ ] Guardrails ativos no AI Gateway"
echo "  [ ] Rate limit configurado por usuário/IP"
echo "  [ ] Logs com redaction de PII habilitados"
echo "  [ ] Fallback configurado para falha do provider"
echo "  [ ] Metadata 'userId' sendo enviada nas chamadas"
echo ""
echo "Para automatizar parcialmente, cheque presença do binding:"

if [ -f "wrangler.toml" ] && grep -q "AI_GATEWAY_URL" wrangler.toml 2>/dev/null; then
  ok "AI_GATEWAY_URL presente em wrangler.toml"
else
  warn "AI_GATEWAY_URL não encontrado em wrangler.toml"
fi

if grep -rn "api.openai.com\|api.anthropic.com" src/ workers/ 2>/dev/null \
    | grep -v "AI_GATEWAY_URL" | grep -v ".test." ; then
  fail "Chamada direta a provider LLM detectada (deve ir via AI Gateway)"
else
  ok "Nenhuma chamada direta a provider LLM"
fi

# --------------------------------------------------------------
# Resumo
# --------------------------------------------------------------
echo ""
echo "══════════════════════════════════════════════════════"
if [ "$FAILURES" -gt 0 ]; then
  echo "${RED}${BOLD}❌ security-scan FALHOU${NC} — ${FAILURES} falha(s), ${WARNINGS} aviso(s)"
  echo "══════════════════════════════════════════════════════"
  exit 1
fi
echo "${GREEN}${BOLD}✅ security-scan OK${NC} — ${WARNINGS} aviso(s)"
echo "══════════════════════════════════════════════════════"
