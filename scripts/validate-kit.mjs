#!/usr/bin/env node
// ==============================================================
// scripts/validate-kit.mjs — valida a integridade do harness kit
//
// Verifica os contratos que o DSH realmente exige de um bundle, e
// que quebram silenciosamente quando errados:
//
//   1. package.json é JSON válido e declara dsh.bundle.patch
//   2. o arquivo apontado por dsh.bundle.patch existe
//   3. toda entrada de `files` existe no disco
//   4. cordis.patch.yml é um array YAML de patches válidos
//   5. nenhuma linha de plugin novo ficou FORA de `insert:`
//      (o erro que fazia o bundle inteiro virar no-op)
//   6. as 12 skills têm frontmatter com name válido + description
//   7. .agents/hooks.json é JSON válido e só usa eventos suportados
//   8. os scripts .sh têm sintaxe de shell válida
//
// Uso:
//   node scripts/validate-kit.mjs
//
// Sem a dependência `yaml` o passo 4 degrada para uma checagem
// estrutural por indentação (que ainda pega o erro do passo 5).
// Em CI: npm install --no-save --ignore-scripts yaml
// ==============================================================

import { readFileSync, existsSync, readdirSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'

const ROOT = join(dirname(fileURLToPath(import.meta.url)), '..')

/** Nomes de skill aceitos pelo DSH. */
const SKILL_NAME = /^[a-z0-9]+(?:-[a-z0-9]+)*$/

/** Eventos que o bridge dsh-hooks-claude-code realmente suporta. */
const SUPPORTED_EVENTS = [
  'SessionStart', 'UserPromptSubmit', 'PreToolUse',
  'PostToolUse', 'Stop', 'SubagentStart', 'SubagentStop',
]

const failures = []
const notes = []

const fail = (m) => failures.push(m)
const note = (m) => notes.push(m)
const readJson = (p) => JSON.parse(readFileSync(join(ROOT, p), 'utf8'))

// --------------------------------------------------------------
// 1 + 2 + 3 — manifest
// --------------------------------------------------------------
const pkg = readJson('package.json')
const patchRel = pkg.dsh?.bundle?.patch

if (typeof patchRel !== 'string' || patchRel.length === 0) {
  fail('package.json: falta dsh.bundle.patch')
} else {
  if (!patchRel.startsWith('./')) fail(`dsh.bundle.patch deveria ser relativo (./...): ${patchRel}`)
  if (!existsSync(join(ROOT, patchRel))) fail(`dsh.bundle.patch aponta para arquivo inexistente: ${patchRel}`)
}

for (const entry of pkg.files ?? []) {
  const clean = entry.replace(/\/$/, '')
  if (!existsSync(join(ROOT, clean))) fail(`files: entrada inexistente: ${entry}`)
}

// --------------------------------------------------------------
// 4 + 5 — cordis.patch.yml
// --------------------------------------------------------------
/**
 * Checagem estrutural por indentação: acha entradas de topo que
 * declaram `name` (plugin) sem estar dentro de um `insert:`.
 */
function structuralPatchCheck(text) {
  const lines = text.split('\n')
  const problems = []
  let current = null

  const flush = () => {
    if (current && current.hasName && !current.hasInsert) {
      problems.push(
        `entrada de topo com 'id: ${current.id ?? '?'}' e 'name: ${current.name}' sem 'insert:' — `
        + 'isso NÃO insere plugin nenhum (é uma asserção de nome sobre uma linha existente)',
      )
    }
    current = null
  }

  for (const line of lines) {
    if (/^\s*#/.test(line) || line.trim() === '') continue
    const topItem = /^- (.*)$/.exec(line)
    if (topItem) {
      flush()
      current = { hasInsert: false, hasName: false, id: undefined, name: undefined }
      const rest = topItem[1].trim()
      if (rest.startsWith('insert:')) current.hasInsert = true
      const n = /^name:\s*(.+)$/.exec(rest)
      if (n) { current.hasName = true; current.name = n[1].trim() }
      continue
    }
    if (!current) continue
    if (/^\s+insert:/.test(line)) current.hasInsert = true
    if (/^\s+name:/.test(line)) { current.hasName = true; current.name = line.split(':').slice(1).join(':').trim() }
    const idm = /^\s+id:\s*(.+)$/.exec(line)
    if (idm && current.id === undefined) current.id = idm[1].trim()
  }
  flush()
  return problems
}

let patchText = ''
if (typeof patchRel === 'string' && existsSync(join(ROOT, patchRel))) {
  patchText = readFileSync(join(ROOT, patchRel), 'utf8')

  let parsed
  try {
    const yaml = await import('yaml').catch(() => undefined)
    if (yaml) parsed = yaml.parse(patchText)
    else note('dependência `yaml` ausente — validando cordis.patch.yml só estruturalmente')
  } catch (error) {
    fail(`cordis.patch.yml não é YAML válido: ${error.message}`)
  }

  if (parsed !== undefined) {
    if (!Array.isArray(parsed)) fail('cordis.patch.yml deve ser um array YAML no topo')
    else {
      parsed.forEach((entry, i) => {
        if (entry === null || typeof entry !== 'object' || Array.isArray(entry)) {
          fail(`cordis.patch.yml entrada ${i + 1}: deve ser um mapping`)
          return
        }
        const hasInsert = Array.isArray(entry.insert)
        if (!hasInsert && typeof entry.id !== 'string') {
          fail(`cordis.patch.yml entrada ${i + 1}: precisa de 'insert:' ou de um 'id:' alvo`)
        }
        if (!hasInsert && typeof entry.name === 'string') {
          fail(`cordis.patch.yml entrada ${i + 1}: 'name' sem 'insert' não adiciona plugin (id: ${entry.id ?? '?'})`)
        }
        for (const row of entry.insert ?? []) {
          if (typeof row?.id !== 'string') fail(`cordis.patch.yml entrada ${i + 1}: linha inserida sem 'id'`)
          if (typeof row?.name !== 'string') fail(`cordis.patch.yml entrada ${i + 1}: linha inserida sem 'name'`)
          // Um nome começando com ./ é um módulo DESTE bundle, resolvido pelo
          // loader relativo ao arquivo de patch. Se o arquivo não existe (ou
          // ficou fora do campo `files`), o boot falha ao resolver a linha.
          if (typeof row?.name === 'string' && row.name.startsWith('./')) {
            const rel = row.name.replace(/^\.\//, '')
            if (!existsSync(join(ROOT, rel))) {
              fail(`cordis.patch.yml: a linha '${row.id}' aponta para '${row.name}', que não existe no bundle`)
            }
          }
        }
      })
    }
  }

  for (const p of structuralPatchCheck(patchText)) fail(`cordis.patch.yml: ${p}`)
}

// --------------------------------------------------------------
// 6 — skills
// --------------------------------------------------------------
const skillsDir = join(ROOT, '.agents/skills')
let skillDirs = []
try {
  skillDirs = readdirSync(skillsDir, { withFileTypes: true })
    .filter(d => d.isDirectory()).map(d => d.name).sort()
} catch {
  fail('.agents/skills/ não encontrado')
}

if (skillDirs.length > 0 && skillDirs.length !== 12) {
  note(`esperadas 12 skills, encontradas ${skillDirs.length}`)
}

for (const dir of skillDirs) {
  const file = join(skillsDir, dir, 'SKILL.md')
  if (!existsSync(file)) { fail(`skills/${dir}: SKILL.md ausente`); continue }

  const text = readFileSync(file, 'utf8')
  const lines = text.split('\n')
  if (lines[0] !== '---') {
    fail(`skills/${dir}/SKILL.md: sem frontmatter YAML (linha 1 deve ser '---') — o DSH ignora o arquivo`)
    continue
  }
  const end = lines.indexOf('---', 1)
  if (end < 0) { fail(`skills/${dir}/SKILL.md: frontmatter não fechado`); continue }

  const fm = lines.slice(1, end).join('\n')
  const name = /^name:\s*(.+)$/m.exec(fm)?.[1]?.trim().replace(/^["']|["']$/g, '')
  const desc = /^description:\s*(.+)$/m.exec(fm)?.[1]?.trim()

  if (!name) fail(`skills/${dir}/SKILL.md: frontmatter sem 'name'`)
  else {
    if (!SKILL_NAME.test(name)) fail(`skills/${dir}/SKILL.md: name inválido "${name}"`)
    if (name !== dir) note(`skills/${dir}: name "${name}" difere do diretório`)
  }
  if (!desc) fail(`skills/${dir}/SKILL.md: frontmatter sem 'description' (é o gatilho de carregamento)`)
}

// --------------------------------------------------------------
// 7 — hooks.json
// --------------------------------------------------------------
const hooksPath = '.agents/hooks.json'
if (!existsSync(join(ROOT, hooksPath))) {
  note(`${hooksPath} ausente — o bridge de hooks não terá o que carregar`)
} else {
  try {
    const hooks = readJson(hooksPath)
    const events = Object.keys(hooks.hooks ?? {})
    if (events.length === 0) fail(`${hooksPath}: sem eventos em 'hooks'`)
    for (const e of events) {
      if (!SUPPORTED_EVENTS.includes(e)) {
        fail(`${hooksPath}: evento "${e}" não é suportado pelo bridge (suportados: ${SUPPORTED_EVENTS.join(', ')})`)
      }
    }
    for (const [event, groups] of Object.entries(hooks.hooks ?? {})) {
      if (!Array.isArray(groups)) { fail(`${hooksPath}: "${event}" deve ser um array`); continue }
      for (const g of groups) {
        for (const h of g?.hooks ?? []) {
          if (h?.type !== undefined && h.type !== 'command') fail(`${hooksPath}: ${event}: só hooks 'command' rodam`)
          if (typeof h?.command !== 'string') fail(`${hooksPath}: ${event}: hook sem 'command'`)
        }
      }
    }
  } catch (error) {
    fail(`${hooksPath} não é JSON válido: ${error.message}`)
  }
}

// --------------------------------------------------------------
// 8 — sintaxe dos scripts de shell
// --------------------------------------------------------------
let shellScripts = []
try {
  shellScripts = readdirSync(join(ROOT, 'scripts')).filter(f => f.endsWith('.sh')).sort()
} catch { /* já reportado acima se ausente */ }

for (const s of shellScripts) {
  try {
    execFileSync('bash', ['-n', join(ROOT, 'scripts', s)], { stdio: 'pipe' })
  } catch (error) {
    fail(`scripts/${s}: erro de sintaxe de shell: ${String(error.stderr ?? error.message).trim()}`)
  }
}

// --------------------------------------------------------------
// Resultado
// --------------------------------------------------------------
console.log('')
console.log('Validação do harness kit')
console.log(`  skills:  ${skillDirs.length}`)
console.log(`  scripts: ${shellScripts.length} .sh`)
console.log(`  patch:   ${typeof patchRel === 'string' ? patchRel : '(ausente)'}`)
console.log('')

for (const n of notes) console.log(`  ·  ${n}`)

if (failures.length > 0) {
  console.log('')
  for (const f of failures) console.error(`  ❌ ${f}`)
  console.error(`\n${failures.length} problema(s) encontrado(s).\n`)
  process.exit(1)
}

console.log(`✅ Kit íntegro${notes.length > 0 ? ` (${notes.length} aviso(s))` : ''}.\n`)
