---
name: code-complexity
description: "Análise de complexidade ciclomática, duplicação, dead code e tamanho de arquivo. Use ao refatorar código legado, adicionar lógica condicional, revisar um PR que aumenta complexidade, ou antes de merge rodando scripts/complexity-check.sh."
---

# Skill: code-complexity

## Quando usar

Carregue esta skill ao trabalhar com:
- Adicionar ou modificar funções com lógica condicional
- Refatorar código legado ou de difícil manutenção
- Revisar PR (verificar se aumenta complexidade)
- Investigar bugs difíceis de reproduzir (complexidade alta costuma ser a causa)
- Auditoria periódica de qualidade
- Antes de merge (rodar `scripts/complexity-check.sh`)

## Objetivo

Manter o código legível e testável. Complexidade alta é o preditor
número um de bugs e dificuldade de manutenção.

Citação relevante (Addy Osmani, "Agentic Code Quality"):
> "Metrics around code quality, such as cyclomatic complexity and line
> length, help keep things readable. Coverage tells you a line ran;
> mutation testing tells you whether the test would notice if that line
> were wrong."

## Métricas e thresholds

| Métrica | Limite | Ferramenta | Ação se exceder |
|---------|--------|------------|-----------------|
| Complexidade ciclomática | ≤ 10 | ESLint `complexity` | Refatorar |
| Linhas por função | ≤ 50 | ESLint `max-lines-per-function` | Extrair funções |
| Linhas por arquivo | ≤ 300 | ESLint `max-lines` | Dividir módulo |
| Profundidade de aninhamento | ≤ 4 | ESLint `max-depth` | Early returns |
| Parâmetros por função | ≤ 5 | ESLint `max-params` | Objeto de opções |
| Duplicação de código | ≤ 3% | jscpd | Extrair util |
| Cobertura de testes | ≥ 70% | Vitest | Adicionar testes |
| Mutation score | ≥ 60% | Stryker | Fortalecer asserts |

## Complexidade ciclomática

### O que é
Conta o número de caminhos independentes através de uma função.
Cada `if`, `else if`, `case`, `&&`, `||`, `?`, loop adiciona 1.

Score aproximado:
- 1–5: simples, fácil de testar.
- 6–10: aceitável.
- 11–20: complexo, requer refatoração.
- 21+: refatoração obrigatória.

### Padrão correto — early returns

```ts
// ✅ complexidade 4 (early returns)
function processUser(user: User): Result {
  if (!user.active) return reject('inactive');
  if (!user.emailVerified) return reject('unverified');
  if (user.banned) return reject('banned');
  if (user.role !== 'admin') return reject('not admin');

  return accept(user);
}
```

### Anti-pattern — aninhamento profundo

```ts
// ❌ complexidade 10 (aninhamento)
function processUser(user: User): Result {
  if (user.role === 'admin') {
    if (user.active) {
      if (user.emailVerified) {
        if (!user.banned) {
          if (user.age >= 18) {
            return accept(user);
          } else {
            return reject('underage');
          }
        } else {
          return reject('banned');
        }
      } else {
        return reject('unverified');
      }
    } else {
      return reject('inactive');
    }
  } else {
    return reject('not admin');
  }
}
```

### Refatoração — guard clauses + tabela

```ts
// ✅ complexidade 3
const CHECKS: Array<[predicate: (u: User) => boolean, reason: string]> = [
  [(u) => u.role === 'admin', 'not admin'],
  [(u) => u.active, 'inactive'],
  [(u) => u.emailVerified, 'unverified'],
  [(u) => !u.banned, 'banned'],
  [(u) => u.age >= 18, 'underage']
];

function processUser(user: User): Result {
  for (const [predicate, reason] of CHECKS) {
    if (!predicate(user)) return reject(reason);
  }
  return accept(user);
}
```

### Refatoração — extrair condição

```ts
// ❌ condição complexa
if (user.age >= 18 && user.country === 'BR' && user.hasValidDocument() && !user.isBlocked) {
  // ...
}

// ✅ condição nomeada
const canRegister = user.age >= 18
  && user.country === 'BR'
  && user.hasValidDocument()
  && !user.isBlocked;

if (canRegister) {
  // ...
}
```

## Tamanho de função

### Padrão correto

```ts
// ✅ 15 linhas, uma responsabilidade
async function createUser(env: Env, input: CreateUserInput): Promise<User> {
  const parsed = CreateUserSchema.parse(input);
  const id = crypto.randomUUID();
  const passwordHash = await hashPassword(parsed.password);

  const user = await env.DB.prepare(
    'INSERT INTO users (id, email, name, password_hash) VALUES (?, ?, ?, ?) RETURNING id, email, name'
  )
    .bind(id, parsed.email, parsed.name, passwordHash)
    .first<User>();

  if (!user) throw new Error('Failed to create user');
  return user;
}
```

### Anti-pattern

```ts
// ❌ 80 linhas, múltiplas responsabilidades
async function handleRequest(request: Request, env: Env) {
  // valida
  // parseia
  // verifica auth
  // verifica permissão
  // busca no banco
  // computa
  // grava
  // envia email
  // loga
  // retorna
}
```

### Refatoração

Divida em funções com nomes que descrevem o **o quê**, não o **como**:

```ts
async function handleRequest(request: Request, env: Env) {
  const input = await parseAndValidate(request);
  const user = await authenticate(env, request);
  requirePermission(user, 'create:user');

  const result = await createUser(env, input);
  await notifyUser(env, result);
  logSafe('user_created', { userId: result.id });

  return json(result);
}
```

## Profundidade de aninhamento

### Padrão correto — máximo 2–3 níveis

```ts
// ✅ aninhamento 2
function findActiveAdmins(users: User[]): User[] {
  return users.filter((user) => {
    if (!user.active) return false;
    return user.role === 'admin';
  });
}
```

### Anti-pattern

```ts
// ❌ aninhamento 5
function process(users: User[]) {
  for (const user of users) {
    if (user.active) {
      if (user.role === 'admin') {
        for (const perm of user.permissions) {
          if (perm.scope === 'global') {
            // ...
          }
        }
      }
    }
  }
}
```

### Refatoração

```ts
// ✅ aninhamento 1 por função
function process(users: User[]) {
  const admins = users.filter(isActiveAdmin);
  admins.flatMap((u) => u.permissions)
    .filter(isGlobalScope)
    .forEach(handleGlobalPermission);
}

const isActiveAdmin = (u: User) => u.active && u.role === 'admin';
const isGlobalScope = (p: Permission) => p.scope === 'global';
```

## Parâmetros por função

### Padrão correto

```ts
// ✅ objeto de opções
interface CreateUserOptions {
  email: string;
  name: string;
  role?: 'user' | 'admin';
  sendWelcomeEmail?: boolean;
  createdBy?: string;
}

async function createUser(env: Env, opts: CreateUserOptions) {
  const { email, name, role = 'user', sendWelcomeEmail = true } = opts;
  // ...
}
```

### Anti-pattern

```ts
// ❌ 7 parâmetros posicionais — fácil errar a ordem
async function createUser(
  env: Env,
  email: string,
  name: string,
  role: string,
  sendWelcomeEmail: boolean,
  createdBy: string,
  metadata: object
) {
  // ...
}

// Chamada confusa:
createUser(env, email, name, 'user', true, adminId, {});
```

## Duplicação de código

### O que é
Blocos idênticos ou quase idênticos em múltiplos lugares.
Threshold: ≤ 3% do código total (jscpd).

### Padrão correto

```ts
// ✅ lógica extraída
// src/lib/utils/validation.ts
export const isValidEmail = (email: string): boolean =>
  /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

export const isValidUUID = (id: string): boolean =>
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

// Uso em múltiplos lugares
import { isValidEmail } from '$utils/validation';
```

### Anti-pattern

```ts
// ❌ mesma regex em 5 arquivos
// arquivo1.ts
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// arquivo2.ts
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// arquivo3.ts
const validEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
```

### Quando duplicar de propósito

Três linhas duplicadas são melhores que uma abstração prematura.
Regra prática:
- 1ª vez: escreva.
- 2ª vez: note.
- 3ª vez: extraia.

## Dead code

### O que é
Código que nunca executa: funções não chamadas, exports órfãos,
imports não usados, branches impossíveis.

### Detecção

```bash
# knip detecta exports e dependências não usados
npx knip --include files,exports,dependencies

# TypeScript detecta imports não usados (com noUnusedLocals)
pnpm check

# ESLint detecta variáveis não usadas
pnpm lint
```

### Anti-pattern

```ts
// ❌ função nunca chamada
function legacyProcessData(data: unknown) {
  // ... 50 linhas
}

// ❌ import não usado
import { unusedUtil } from '$utils/unused';

// ❌ branch impossível
if (typeof name === 'string' && name === null) {
  // ...
}
```

### Checklist
- [ ] `npx knip` sem findings
- [ ] Nenhum import não usado
- [ ] Nenhum `export` sem consumo
- [ ] Nenhum `TODO` antigo (criar issue)

## Mutation testing

### O que é
Ferramenta modifica o código (mutantes) e verifica se os testes detectam.
Mutante "sobrevivente" indica teste fraco.

### Exemplo

```ts
// Código original
function isAdult(age: number): boolean {
  return age >= 18;
}

// Mutante 1: >= vira >
function isAdult(age: number): boolean {
  return age > 18; // deve falhar para age=18
}

// Mutante 2: 18 vira 19
function isAdult(age: number): boolean {
  return age >= 19; // deve falhar para age=18
}
```

Se o teste não detecta o mutante, o teste é fraco.

### Teste forte

```ts
describe('isAdult', () => {
  it('aceita exatamente 18', () => {
    expect(isAdult(18)).toBe(true); // mata mutante >= → >
  });

  it('rejeita 17', () => {
    expect(isAdult(17)).toBe(false);
  });

  it('aceita 19', () => {
    expect(isAdult(19)).toBe(true); // mata mutante 18 → 19
  });
});
```

### Configuração

```javascript
// tests/mutation/stryker.config.mjs
export default {
  testRunner: 'vitest',
  mutate: ['src/lib/**/*.ts', 'workers/src/**/*.ts'],
  thresholds: { high: 80, low: 60, break: 60 },
  reporters: ['clear-text', 'progress', 'html']
};
```

### Comando

```bash
pnpm test:mutation
```

## Refatorações comuns

### 1. Guard clauses

```ts
// ❌ aninhado
function process(input: Input) {
  if (input) {
    if (input.valid) {
      // ... lógica real
    }
  }
}

// ✅ guard
function process(input: Input) {
  if (!input) return;
  if (!input.valid) return;
  // ... lógica real
}
```

### 2. Extrair função

```ts
// ❌ inline
function render(items: Item[]) {
  const html = items.map((i) => {
    const price = i.price * (1 + i.tax);
    const discount = i.coupon ? price * 0.1 : 0;
    return `<div>${i.name}: ${(price - discount).toFixed(2)}</div>`;
  }).join('');
  return html;
}

// ✅ extraído
function calcFinalPrice(item: Item): number {
  const withTax = item.price * (1 + item.tax);
  const discount = item.coupon ? withTax * 0.1 : 0;
  return withTax - discount;
}

function render(items: Item[]) {
  return items
    .map((i) => `<div>${i.name}: ${calcFinalPrice(i).toFixed(2)}</div>`)
    .join('');
}
```

### 3. Substituir condicional por polimorfismo

```ts
// ❌ switch grande
function getShippingCost(type: string): number {
  switch (type) {
    case 'standard': return 10;
    case 'express': return 25;
    case 'overnight': return 50;
    default: throw new Error('Unknown');
  }
}

// ✅ mapa
const SHIPPING_COSTS: Record<string, number> = {
  standard: 10,
  express: 25,
  overnight: 50
};

function getShippingCost(type: string): number {
  const cost = SHIPPING_COSTS[type];
  if (cost === undefined) throw new Error('Unknown');
  return cost;
}
```

### 4. Substituir loop por pipeline

```ts
// ❌ loop imperativo
function getActiveAdmins(users: User[]): string[] {
  const result: string[] = [];
  for (let i = 0; i < users.length; i++) {
    if (users[i].active && users[i].role === 'admin') {
      result.push(users[i].name);
    }
  }
  return result;
}

// ✅ pipeline
function getActiveAdmins(users: User[]): string[] {
  return users
    .filter((u) => u.active && u.role === 'admin')
    .map((u) => u.name);
}
```

## Como rodar

```bash
# Análise completa (ESLint + jscpd + knip + tamanho)
./scripts/complexity-check.sh

# Modo não-bloqueante
./scripts/complexity-check.sh --warn-only

# Mutation testing
pnpm test:mutation

# Type check + lint (rápido, cobre imports não usados)
pnpm check && pnpm lint
```

## Checklist antes de finalizar

- [ ] Nenhuma função com complexidade > 10
- [ ] Nenhuma função com mais de 50 linhas
- [ ] Nenhum arquivo com mais de 300 linhas
- [ ] Aninhamento máximo de 4 níveis
- [ ] Máximo de 5 parâmetros por função
- [ ] Duplicação abaixo de 3%
- [ ] Nenhum dead code (knip verde)
- [ ] Nenhum import não usado
- [ ] Cobertura ≥ 70% nos arquivos modificados
- [ ] Mutation score ≥ 60% nos módulos críticos
- [ ] Refatorações extraem nomes que descrevem o "o quê"
- [ ] Nenhuma abstração prematura (regra das 3 vezes)

## Referências

- Cyclomatic complexity (McCabe): https://en.wikipedia.org/wiki/Cyclomatic_complexity
- Refactoring (Martin Fowler): https://refactoring.com/catalog/
- Clean Code (Robert C. Martin)
- Stryker Mutator: https://stryker-mutator.io/
- jscpd: https://github.com/kucherenko/jscpd
- knip: https://github.com/webpro/knip
- AGENT.md — seção 9, Step Verification (etapa 8)
- Skill `agentic-code-review` — red flags de qualidade
