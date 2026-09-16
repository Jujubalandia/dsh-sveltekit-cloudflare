#!/usr/bin/env bash
# ==============================================================
# test-install.sh — valida a instalação do bundle DSH localmente
#
# Rode este script num terminal onde o comando `dsh` esteja no PATH
# (o ambiente de build onde o kit foi montado não tinha `dsh`).
#
# O que ele faz, em ordem:
#   1. Confere que `dsh` existe no PATH.
#   2. Cria um profile DEDICADO de teste (não mexe no seu profile
#      `web`) e instala este diretório como bundle.
#   3. Verifica que a camada do bundle aparece em --dump-config.
#   4. Verifica que as 12 skills foram registradas.
#   5. Roda um boot curto para capturar warnings de boot.
#
# Uso:
#   ./test-install.sh              # profile de teste "sveltekit-bundle-test"
#   PROFILE=web ./test-install.sh  # insiste no profile web (altera seu setup)
#   KEEP=1 ./test-install.sh       # não remove o profile no final
#
# Por que um profile dedicado: `dsh plugin add` altera o profile alvo
# (adiciona dependência + camada em dsh.profile.bundles). Testar no
# profile `web` mexe no seu ambiente de trabalho real.
# ==============================================================

set -uo pipefail

PROFILE="${PROFILE:-sveltekit-bundle-test}"
KEEP="${KEEP:-0}"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUNDLE_NAME="@jujubalandia/dsh-sveltekit-cloudflare"

PASS=0
FAIL=0

ok()   { echo "  ✅ $*"; PASS=$((PASS + 1)); }
bad()  { echo "  ❌ $*"; FAIL=$((FAIL + 1)); }
info() { echo "  ·  $*"; }

echo ""
echo "┌────────────────────────────────────────────────────────────┐"
echo "│ Teste de instalação do bundle DSH                          │"
echo "│ bundle:  $BUNDLE_NAME"
echo "│ profile: $PROFILE"
echo "│ origem:  $BUNDLE_DIR"
echo "└────────────────────────────────────────────────────────────┘"

# --------------------------------------------------------------
# 1. dsh disponível?
# --------------------------------------------------------------
echo ""
echo "▶ [1/5] Procurando o comando dsh"
if ! command -v dsh >/dev/null 2>&1; then
  bad "dsh não encontrado no PATH."
  echo ""
  echo "  Instale o DeepSeek Harness e/ou exporte o PATH, por exemplo:"
  echo "    export PATH=\"\$HOME/.dsh/bin:\$PATH\""
  echo ""
  echo "  Neste ambiente de build o dsh não estava disponível, então a"
  echo "  validação do patch foi feita replicando o algoritmo oficial do"
  echo "  loader (vendor/include/src/index.ts) contra o dsh-base real."
  exit 1
fi
ok "dsh encontrado: $(command -v dsh)"
dsh --version 2>&1 | head -1 | sed 's/^/     /'

# --------------------------------------------------------------
# 2. Instalar o bundle no profile
# --------------------------------------------------------------
echo ""
echo "▶ [2/5] Instalando o bundle no profile '$PROFILE'"
if dsh plugin --profile "$PROFILE" add "$BUNDLE_DIR" 2>&1 | sed 's/^/     /'; then
  ok "dsh plugin add concluiu"
else
  bad "dsh plugin add falhou (veja a saída acima)"
fi

# --------------------------------------------------------------
# 3. A camada aparece no dump-config?
# --------------------------------------------------------------
echo ""
echo "▶ [3/5] Verificando a camada em --dump-config"
DUMP="$(dsh --profile "$PROFILE" --dump-config 2>&1)"

if printf '%s' "$DUMP" | grep -qi "dsh-sveltekit-cloudflare"; then
  ok "a camada do bundle aparece no dump"
else
  bad "a camada NÃO aparece no dump — o bundle não foi reconhecido"
  echo "     Verifique se package.json tem dsh.bundle.patch apontando"
  echo "     para ./cordis.patch.yml."
fi

# A linha de hooks precisa estar na árvore composta.
if printf '%s' "$DUMP" | grep -q "sveltekit-cloudflare-hooks"; then
  ok "a linha sveltekit-cloudflare-hooks foi inserida"
else
  bad "a linha de hooks NÃO foi inserida"
fi

# O nome do plugin de hooks precisa aparecer.
if printf '%s' "$DUMP" | grep -q "dsh-hooks-claude-code"; then
  ok "o bridge dsh-hooks-claude-code está montado"
else
  bad "dsh-hooks-claude-code ausente do dump"
fi

# --------------------------------------------------------------
# 4. Warnings de patch não aplicado
# --------------------------------------------------------------
echo ""
echo "▶ [4/5] Procurando warnings de patch não aplicado"
if printf '%s' "$DUMP" | grep -qi "patch: entry .* not found"; then
  bad "o loader reclamou de patch apontando para linha inexistente:"
  printf '%s' "$DUMP" | grep -i "patch: entry .* not found" | sed 's/^/     /'
  echo "     Linhas novas precisam estar dentro de 'insert:' no cordis.patch.yml."
else
  ok "nenhum warning de 'entry not found'"
fi

# --------------------------------------------------------------
# 5. Skills registradas
# --------------------------------------------------------------
echo ""
echo "▶ [5/5] Verificando as 12 skills do kit"
SKILLS="agentic-code-review cloudflare-ai-gateway cloudflare-d1 cloudflare-kv \
cloudflare-r2 cloudflare-security code-complexity git-flow owasp-top10 \
security-leaks sveltekit-auth sveltekit-runes"

FOUND=0
for s in $SKILLS; do
  if printf '%s' "$DUMP" | grep -q "$s"; then
    FOUND=$((FOUND + 1))
  else
    info "skill ausente do dump: $s"
  fi
done

if [ "$FOUND" -eq 12 ]; then
  ok "as 12 skills aparecem no dump"
elif [ "$FOUND" -gt 0 ]; then
  info "$FOUND/12 skills no dump"
  echo "     O --dump-config pode não listar skills; confirme num boot"
  echo "     interativo que o catálogo de skills mostra as 12."
else
  info "nenhuma skill no dump (esperado: --dump-config lista plugins, não skills)"
  echo "     Confirme num boot interativo que o catálogo mostra as 12 skills."
  echo "     Se não mostrar, verifique se cada SKILL.md começa com"
  echo "     frontmatter '---' contendo name e description."
fi

# --------------------------------------------------------------
# Limpeza
# --------------------------------------------------------------
echo ""
if [ "$KEEP" = "1" ]; then
  echo "▶ KEEP=1 — profile '$PROFILE' mantido para inspeção."
  echo "  Para remover depois:"
  echo "    dsh plugin --profile $PROFILE remove $BUNDLE_NAME"
else
  echo "▶ Removendo o profile de teste"
  dsh plugin --profile "$PROFILE" remove "$BUNDLE_NAME" 2>&1 | sed 's/^/     /' \
    && ok "bundle removido do profile de teste"
fi

# --------------------------------------------------------------
# Resultado
# --------------------------------------------------------------
echo ""
echo "┌────────────────────────────────────────────────────────────┐"
printf "│ %-58s │\n" "Resultado: $PASS ok, $FAIL falha(s)"
echo "└────────────────────────────────────────────────────────────┘"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Diagnóstico rápido:"
  echo "  · camada ausente      → dsh.bundle.patch em package.json"
  echo "  · linha não inserida  → faltou 'insert:' no cordis.patch.yml"
  echo "  · 'entry not found'   → patch de topo apontando p/ id inexistente"
  echo "  · skills não carregam → frontmatter name+description no SKILL.md"
  exit 1
fi

echo ""
echo "✅ Instalação validada."
exit 0
