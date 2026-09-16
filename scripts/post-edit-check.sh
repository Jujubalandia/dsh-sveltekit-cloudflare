#!/usr/bin/env bash
# ==============================================================
# scripts/post-edit-check.sh — hook chamado APÓS editar um arquivo
#
# Uso:
#   ./scripts/post-edit-check.sh <caminho-do-arquivo>
#
# Chamado pelo harness (hook PostToolUse) depois de edit/write.
# Objetivo:
#   - Rodar type check no projeto
#   - Rodar lint
#   - Se o arquivo for teste, rodar esse teste específico
#   - Falhar rápido (exit 1) se algo quebrar
# ==============================================================

set -uo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then
  exit 0
fi

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

# --------------------------------------------------------------
# Raiz do projeto
# --------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

# --------------------------------------------------------------
# Ignorar arquivos que não afetam build/testes
# --------------------------------------------------------------
case "$FILE" in
  *node_modules*|*.svelte-kit*|*/build/*|*/dist/*|*/coverage/*)
    exit 0
    ;;
  *.md|*.txt|*.log|*.lock)
    exit 0
    ;;
esac

echo ""
echo "${BLUE}${BOLD}[post-edit]${NC} ${CYAN}$FILE${NC}"

START=$(date +%s)
FAILED=0

# --------------------------------------------------------------
# 1. Type check
# --------------------------------------------------------------
echo "  ${YELLOW}▶${NC} type check (pnpm check)"
if ! pnpm check > /tmp/dsh-postedit-check.log 2>&1; then
  echo "  ${RED}❌ type check falhou${NC}"
  tail -30 /tmp/dsh-postedit-check.log | sed 's/^/     /'
  FAILED=1
else
  echo "  ${GREEN}✅${NC} type check OK"
fi

# --------------------------------------------------------------
# 2. Lint do arquivo modificado (rápido) — se aplicável
# --------------------------------------------------------------
case "$FILE" in
  *.ts|*.js|*.svelte|*.mjs|*.cjs)
    echo "  ${YELLOW}▶${NC} lint (arquivo: $FILE)"
    if ! pnpm exec eslint "$FILE" > /tmp/dsh-postedit-lint.log 2>&1; then
      # ESLint pode falhar se o arquivo não estiver coberto pelo config
      if grep -q "No files matching" /tmp/dsh-postedit-lint.log; then
        echo "  ${YELLOW}⚠${NC}  arquivo não coberto pelo ESLint"
      else
        echo "  ${RED}❌ lint falhou${NC}"
        tail -30 /tmp/dsh-postedit-lint.log | sed 's/^/     /'
        FAILED=1
      fi
    else
      echo "  ${GREEN}✅${NC} lint OK"
    fi
    ;;
esac

# --------------------------------------------------------------
# 3. Teste focado se o arquivo for teste
# --------------------------------------------------------------
case "$FILE" in
  *.test.ts|*.spec.ts|*/tests/*)
    if [ -f "$FILE" ]; then
      echo "  ${YELLOW}▶${NC} teste focado ($FILE)"
      if ! pnpm exec vitest run "$FILE" --reporter=dot > /tmp/dsh-postedit-test.log 2>&1; then
        echo "  ${RED}❌ teste falhou${NC}"
        tail -30 /tmp/dsh-postedit-test.log | sed 's/^/     /'
        FAILED=1
      else
        echo "  ${GREEN}✅${NC} teste OK"
      fi
    fi
    ;;
esac

# --------------------------------------------------------------
# 4. Aviso: mudança em testes existentes
# --------------------------------------------------------------
case "$FILE" in
  *tests/*|*.test.ts|*.spec.ts)
    echo "  ${YELLOW}⚠${NC}  alteração em teste — confirme que NÃO é para mascarar falha"
    ;;
esac

# --------------------------------------------------------------
# Resumo
# --------------------------------------------------------------
END=$(date +%s)
ELAPSED=$((END - START))

if [ "$FAILED" -eq 1 ]; then
  echo "  ${RED}${BOLD}❌ post-edit FALHOU${NC} (${ELAPSED}s)"
  exit 1
fi

echo "  ${GREEN}${BOLD}✅ post-edit OK${NC} (${ELAPSED}s)"
exit 0
