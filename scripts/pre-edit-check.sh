#!/usr/bin/env bash
# ==============================================================
# scripts/pre-edit-check.sh — hook chamado ANTES de editar um arquivo
#
# Uso:
#   ./scripts/pre-edit-check.sh <caminho-do-arquivo>
#
# Chamado pelo harness (hook PreToolUse) antes de edit_file/write_file.
# Objetivo:
#   - Classificar o arquivo por área (server, d1, kv, r2, ai, auth, etc.)
#   - Lembrar o agente de carregar a skill relevante
#   - Alertar sobre security gates aplicáveis
#   - Nunca bloqueia (é um guia, não um gate rígido)
# ==============================================================

set -uo pipefail

FILE="${1:-}"
if [ -z "$FILE" ]; then
  # Sem argumento: nada a verificar
  exit 0
fi

# --------------------------------------------------------------
# Cores
# --------------------------------------------------------------
if [ -t 1 ]; then
  YELLOW=$'\033[0;33m'
  BLUE=$'\033[0;34m'
  CYAN=$'\033[0;36m'
  BOLD=$'\033[1m'
  NC=$'\033[0m'
else
  YELLOW=""; BLUE=""; CYAN=""; BOLD=""; NC=""
fi

# --------------------------------------------------------------
# Ignorar arquivos irrelevantes
# --------------------------------------------------------------
case "$FILE" in
  *node_modules*|*.svelte-kit*|*/build/*|*/dist/*|*/coverage/*|*.lock|*.log)
    exit 0
    ;;
esac

echo ""
echo "${BLUE}${BOLD}[pre-edit]${NC} ${CYAN}$FILE${NC}"

# --------------------------------------------------------------
# Detecção de área + skill + gates
# --------------------------------------------------------------
SKILLS=()
GATES=()
NOTES=()

case "$FILE" in
  # ---- server-only ----
  *src/lib/server/*|*+page.server.ts|*+server.ts|*hooks.server.ts)
    NOTES+=("Arquivo server-only: NUNCA importar de componente cliente.")
    GATES+=("Gate 1 (Secrets)" "Gate 2 (Input)")
    SKILLS+=("sveltekit-auth")
    ;;

  # ---- Svelte / componentes ----
  *.svelte)
    NOTES+=("Use apenas runes Svelte 5. Proibido export let / \$: / stores legadas.")
    SKILLS+=("sveltekit-runes")
    ;;
  *+layout.server.ts)
    NOTES+=("Guards de rota aqui. Valide locals.user em cada request.")
    GATES+=("Gate 1 (Secrets)")
    SKILLS+=("sveltekit-auth")
    ;;

  # ---- Workers / Cloudflare ----
  *workers/src/db/*|*workers/src/d1/*)
    NOTES+=("D1: sempre .bind(). Nunca concatenar SQL.")
    GATES+=("Gate 3 (D1)")
    SKILLS+=("cloudflare-d1")
    ;;
  *workers/src/cache/*|*workers/src/kv/*)
    NOTES+=("KV: TTL explícito. Prefixos claros (sess:, cache:, flag:).")
    SKILLS+=("cloudflare-kv")
    ;;
  *workers/src/storage/*|*workers/src/r2/*)
    NOTES+=("R2: bucket privado. Signed URLs ≤15min. Validar tipo/tamanho.")
    GATES+=("Gate 4 (R2)")
    SKILLS+=("cloudflare-r2")
    ;;
  *workers/src/ai/*|*workers/src/gateway/*)
    NOTES+=("LLM SEMPRE via AI Gateway. Nunca provider direto. Sanitizar prompt.")
    GATES+=("Gate 5 (AI Gateway)" "Gate 7 (Prompt Injection)")
    SKILLS+=("cloudflare-ai-gateway")
    ;;
  *workers/src/index.ts)
    NOTES+=("Entry point do Worker. Verifique bindings em app.d.ts.")
    SKILLS+=("cloudflare-security")
    ;;

  # ---- Migrations ----
  *migrations/*.sql)
    NOTES+=("Migration versionada. Nunca alterar schema em produção manualmente.")
    GATES+=("Gate 3 (D1)")
    SKILLS+=("cloudflare-d1")
    ;;

  # ---- Configs ----
  *wrangler*.toml)
    NOTES+=("Config Cloudflare. Nunca comitar secrets. Use wrangler secret put.")
    GATES+=("Gate 1 (Secrets)")
    ;;
  *.env*)
    NOTES+=("NUNCA comitar .env. Apenas .env.example é versionado.")
    GATES+=("Gate 1 (Secrets)")
    ;;
  *.gitleaks.toml)
    NOTES+=("Config de detecção de secrets. Alterar com cuidado.")
    GATES+=("Gate 1 (Secrets)")
    ;;

  # ---- CI / scripts ----
  *.github/workflows/*)
    NOTES+=("Workflow CI/CD. Não enfraquecer gates (lint, coverage, security).")
    GATES+=("Gate 8 (Deploy)")
    ;;
  *scripts/*.sh)
    NOTES+=("Script operacional. Mantenha idempotência e segurança.")
    ;;

  # ---- Testes ----
  *.test.ts|*.spec.ts|*tests/*)
    NOTES+=("NUNCA reescrever teste para passar. Corrija o código, não o teste.")
    SKILLS+=("agentic-code-review")
    ;;
esac

# --------------------------------------------------------------
# Saída
# --------------------------------------------------------------
if [ ${#NOTES[@]} -gt 0 ]; then
  echo "  ${YELLOW}notas:${NC}"
  for n in "${NOTES[@]}"; do
    echo "    · $n"
  done
fi

if [ ${#GATES[@]} -gt 0 ]; then
  echo "  ${YELLOW}gates:${NC} ${GATES[*]}"
fi

if [ ${#SKILLS[@]} -gt 0 ]; then
  echo "  ${YELLOW}skills:${NC} ${SKILLS[*]}"
fi

echo ""
exit 0
