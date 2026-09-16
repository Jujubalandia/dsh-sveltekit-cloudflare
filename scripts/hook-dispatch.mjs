#!/usr/bin/env node
// ==============================================================
// scripts/hook-dispatch.mjs — ponte entre os hooks do DSH e os
// scripts de verificação deste kit.
//
// Por que existe:
//   O bridge `@deepseek-ai/dsh-hooks-claude-code` entrega o payload
//   do evento como JSON no stdin do comando do hook, no formato do
//   Claude Code. Os scripts deste kit esperam o caminho do arquivo
//   como primeiro argumento posicional ($1). Este dispatcher lê o
//   JSON, extrai `tool_input.file_path` e chama o script alvo.
//
// Uso (definido em .agents/hooks.json):
//   node scripts/hook-dispatch.mjs <caminho-do-script-de-check>
//
// Contrato de saída:
//   Emite em stdout um JSON com
//   `hookSpecificOutput.additionalContext`, que é o canal pelo qual
//   o DSH injeta texto no contexto do modelo. Sem isso o guia do
//   script ficaria visível só para o humano e nunca chegaria ao
//   agente — que é justamente o ponto de um hook de PreToolUse.
//
// Por que nunca bloqueia:
//   O codec do DSH (`hook-protocol/codec.ts`) trata exit 2 como
//   bloqueio, com o stderr virando o motivo, e qualquer outro exit
//   como erro não-bloqueante. Estes checks são um guia, não um gate
//   rígido — então o dispatcher sempre sai com código 0, mesmo se o
//   script alvo falhar. Gates de verdade vivem no CI e nos hooks de
//   git em `.husky/`.
// ==============================================================

import { spawnSync } from 'node:child_process'
import { readFileSync } from 'node:fs'

/** Tamanho máximo do texto injetado no contexto do modelo. */
const MAX_CONTEXT_CHARS = 4000

/** Timeout do script de check, em milissegundos. */
const CHECK_TIMEOUT_MS = 300_000

/** Campos de `tool_input` que carregam o caminho do arquivo, em ordem de preferência. */
const FILE_PATH_KEYS = ['file_path', 'path', 'notebook_path']

/**
 * Lê todo o stdin como UTF-8. O bridge escreve o payload e fecha o pipe,
 * então a leitura síncrona até o EOF é suficiente.
 * @returns o payload cru, ou string vazia quando não há stdin.
 */
function readStdin() {
  try {
    return readFileSync(0, 'utf8')
  } catch {
    return ''
  }
}

/**
 * Extrai o caminho do arquivo do payload do evento.
 * @param payload - o objeto JSON recebido no stdin.
 * @returns o caminho do arquivo, ou undefined quando o evento não é de edição.
 */
function filePathOf(payload) {
  const input = payload?.tool_input
  if (input === null || typeof input !== 'object') return undefined
  for (const key of FILE_PATH_KEYS) {
    const value = input[key]
    if (typeof value === 'string' && value.trim().length > 0) return value
  }
  return undefined
}

/**
 * Trunca o texto preservando o começo, que é onde ficam os alertas.
 * @param text - o texto a truncar.
 * @returns o texto original, ou truncado com um marcador.
 */
function clamp(text) {
  return text.length <= MAX_CONTEXT_CHARS
    ? text
    : `${text.slice(0, MAX_CONTEXT_CHARS)}\n… [saída truncada em ${MAX_CONTEXT_CHARS} caracteres]`
}

/** Ponto de entrada: lê o payload, roda o script alvo e publica o resultado. */
function main() {
  const target = process.argv[2]
  if (typeof target !== 'string' || target.length === 0) return

  let payload
  try {
    payload = JSON.parse(readStdin())
  } catch {
    return
  }

  const filePath = filePathOf(payload)
  if (filePath === undefined) return

  const eventName = payload.hook_event_name
  if (typeof eventName !== 'string' || eventName.length === 0) return

  const result = spawnSync('bash', [target, filePath], {
    encoding: 'utf8',
    timeout: CHECK_TIMEOUT_MS,
    stdio: ['ignore', 'pipe', 'pipe'],
  })

  const text = [result.stdout ?? '', result.stderr ?? '']
    .filter(part => part.trim().length > 0)
    .join('\n')
  if (text.trim().length === 0) return

  process.stdout.write(`${JSON.stringify({
    hookSpecificOutput: { hookEventName: eventName, additionalContext: clamp(text) },
  })}\n`)
}

try {
  main()
} catch {
  // Silencioso de propósito: ver o contrato "nunca bloqueia" no topo.
}

process.exitCode = 0
