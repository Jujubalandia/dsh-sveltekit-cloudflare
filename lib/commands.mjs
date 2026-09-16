// ==============================================================
// lib/commands.mjs — registra os comandos /sveflare-* no DSH
//
// Por que este arquivo existe:
//   O DSH NÃO descobre comandos a partir de arquivos markdown. O
//   `@deepseek-ai/dsh-commands` é um registry em que cada plugin se
//   registra por CÓDIGO, via `ctx.commands.register(definition)` —
//   ele não tem schema de configuração e nenhum diretório
//   `.agents/commands/` é varrido pelo harness.
//
//   Então os prompts em `.agents/commands/*.md` só viram comandos de
//   verdade se um plugin os ler e registrar. É o que este módulo faz.
//
// Sem dependências externas: só builtins do Node. O message é
// construído como objeto literal — o `id` do DSH é uma marca só de
// tipo (compile-time), então um UUID comum serve em runtime.
//
// Contrato de config (vindo da linha do bundle em cordis.patch.yml):
//   commands:
//     - name: sveflare-spec          # vira /sveflare-spec
//       file: .agents/commands/sveflare-spec.md
// ==============================================================

import { randomUUID } from 'node:crypto'
import { readFileSync, existsSync } from 'node:fs'
import { join, resolve, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

export const name = 'sveflare-commands'

/** Sem `commands` no contexto não há o que registrar. */
export const inject = ['commands']

/** Raiz do bundle (uma acima de lib/). */
const BUNDLE_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..')

/** Nome de comando aceito pelo registry do DSH. */
const COMMAND_NAME = /^[a-z][a-z0-9_-]*$/u

/** Comandos usados quando a config não declara nenhum. */
const DEFAULT_COMMANDS = [
  { name: 'sveflare-spec', file: '.agents/commands/sveflare-spec.md' },
  { name: 'sveflare-plan', file: '.agents/commands/sveflare-plan.md' },
  { name: 'sveflare-goal', file: '.agents/commands/sveflare-goal.md' },
  { name: 'sveflare-verify', file: '.agents/commands/sveflare-verify.md' },
  { name: 'sveflare-ship', file: '.agents/commands/sveflare-ship.md' },
]

/**
 * Acha um arquivo tentando o cwd da sessão e depois a raiz do bundle.
 * @param rel - caminho relativo declarado na config.
 * @returns o caminho absoluto do primeiro candidato existente, ou undefined.
 */
function resolveCommandFile(rel) {
  for (const base of [process.cwd(), BUNDLE_ROOT]) {
    const candidate = resolve(base, rel)
    if (existsSync(candidate)) return candidate
  }
  return undefined
}

/**
 * Separa o frontmatter YAML do corpo do prompt.
 * @param text - conteúdo cru do arquivo markdown.
 * @returns o frontmatter como texto e o corpo sem ele.
 */
function splitFrontmatter(text) {
  const lines = text.split('\n')
  if (lines[0]?.trim() !== '---') return { frontmatter: '', body: text }
  const end = lines.indexOf('---', 1)
  if (end < 0) return { frontmatter: '', body: text }
  return { frontmatter: lines.slice(1, end).join('\n'), body: lines.slice(end + 1).join('\n').trim() }
}

/**
 * Lê um campo escalar simples do frontmatter.
 * @param frontmatter - o bloco de frontmatter.
 * @param key - o nome do campo.
 * @returns o valor sem quotes, ou undefined.
 */
function frontmatterField(frontmatter, key) {
  const match = new RegExp(`^${key}:\\s*(.+)$`, 'm').exec(frontmatter)
  return match?.[1]?.trim().replace(/^["']|["']$/g, '')
}

/**
 * Monta o message de usuário que o plugin injeta no agente.
 * @param text - o prompt completo a enviar.
 * @returns um UserMessage estruturalmente válido.
 */
function userMessage(text) {
  return {
    id: randomUUID(),
    role: 'user',
    content: [{ type: 'text', text }],
    source: { kind: 'plugin', plugin: name },
  }
}

/**
 * Registra um comando a partir de um arquivo de prompt.
 * @param ctx - o contexto Cordis.
 * @param spec - `{ name, file, description? }`.
 * @returns true quando registrou, false quando pulou.
 */
function registerOne(ctx, spec) {
  const commandName = spec.name
  if (typeof commandName !== 'string' || !COMMAND_NAME.test(commandName)) {
    ctx.logger.warn(`${name}: nome de comando inválido "${String(commandName)}" — ignorado`)
    return false
  }

  const path = resolveCommandFile(spec.file)
  if (path === undefined) {
    ctx.logger.warn(`${name}: arquivo do comando /${commandName} não encontrado (${spec.file}) — ignorado`)
    return false
  }

  let raw
  try {
    raw = readFileSync(path, 'utf8')
  } catch (error) {
    ctx.logger.warn(`${name}: falha ao ler ${path}: ${String(error)} — comando ignorado`)
    return false
  }

  const { frontmatter, body } = splitFrontmatter(raw)
  const description = spec.description
    ?? frontmatterField(frontmatter, 'description')
    ?? `Comando ${commandName} do harness sveflare.`
  const hint = frontmatterField(frontmatter, 'argument-hint')

  if (body.trim().length === 0) {
    ctx.logger.warn(`${name}: ${path} tem corpo vazio — comando ignorado`)
    return false
  }

  ctx.commands.register({
    name: commandName,
    description,
    ...hint === undefined ? {} : { input: { hint } },
    handler: ({ agent, rawInput }) => {
      const argument = typeof rawInput === 'string' ? rawInput.trim() : ''
      const prompt = argument.length === 0
        ? body
        : `${body}\n\n---\n\nArgumento informado pelo usuário:\n${argument}`

      try {
        const message = userMessage(prompt)
        // `steer` acorda o driver, então o modelo responde de imediato —
        // que é o que um slash command precisa. `inject` sozinho deixaria
        // o contexto parado até o usuário digitar algo.
        if (typeof agent?.steer === 'function') agent.steer(message)
        else if (typeof agent?.inject === 'function') agent.inject(message)
        else return { kind: 'error', text: `/${commandName}: o agente não expõe steer() nem inject().` }
      } catch (error) {
        return { kind: 'error', text: `/${commandName} falhou: ${String(error)}` }
      }

      return { kind: 'success', text: `/${commandName} enviado.` }
    },
  })

  ctx.logger.info?.(`${name}: /${commandName} registrado`)
  return true
}

/**
 * Ponto de entrada do plugin.
 * @param ctx - o contexto Cordis com o serviço `commands`.
 * @param config - `{ commands?: Array<{name, file, description?}> }`.
 */
export function apply(ctx, config) {
  const specs = Array.isArray(config?.commands) && config.commands.length > 0
    ? config.commands
    : DEFAULT_COMMANDS

  let registered = 0
  for (const spec of specs) {
    if (spec === null || typeof spec !== 'object') continue
    if (registerOne(ctx, spec)) registered += 1
  }

  if (registered === 0) {
    ctx.logger.warn(`${name}: nenhum comando registrado — verifique .agents/commands/`)
  }
}
