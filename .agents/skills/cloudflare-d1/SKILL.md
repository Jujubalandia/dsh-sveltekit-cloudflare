---
name: cloudflare-d1
description: "Cloudflare D1, o banco SQL serverless sobre SQLite: queries, migrations, índices, transações e prepared statements. Use ao editar migrations/, arquivos em workers/src/db/, ou qualquer código que importe env.DB."
---

# Skill: cloudflare-d1

## Quando usar

Carregue esta skill ao trabalhar com:
- Queries SQL em `workers/src/db/`
- Migrations em `migrations/`
- Qualquer arquivo que importe `env.DB`
- Schemas, índices, triggers D1

## O que é D1

Cloudflare D1 é um banco SQL serverless baseado em SQLite, distribuído
via replicação read-only para edge. Escrita acontece em uma região primária.

Características importantes:
- SQLite com dialeto SQL.
- Prepared statements são obrigatórios para segurança.
- Sem joins complexos eficientes; prefira queries simples + índice.
- Limite de 100 MB por database no plano free (verificar plano atual).
- Migrations gerenciadas por `wrangler d1 migrations`.

## Padrões corretos

### Query com prepared statement

```ts
// workers/src/db/users.ts
export async function getUserById(env: Env, id: string) {
  const stmt = env.DB
    .prepare('SELECT id, email, name, role FROM users WHERE id = ?')
    .bind(id);

  return stmt.first<User>();
}
```

### Insert com retorno

```ts
export async function createUser(
  env: Env,
  input: { id: string; email: string; name: string }
) {
  const stmt = env.DB
    .prepare(
      'INSERT INTO users (id, email, name) VALUES (?, ?, ?) RETURNING *'
    )
    .bind(input.id, input.email, input.name);

  return stmt.first<User>();
}
```

### Batch (transação)

```ts
export async function deleteUserAndSessions(env: Env, userId: string) {
  const results = await env.DB.batch([
    env.DB.prepare('DELETE FROM sessions WHERE user_id = ?').bind(userId),
    env.DB.prepare('DELETE FROM users WHERE id = ?').bind(userId)
  ]);

  return results;
}
```

### Lista com paginação

```ts
export async function listUsers(
  env: Env,
  limit: number,
  cursor: string | null
) {
  const stmt = cursor
    ? env.DB.prepare(
        'SELECT * FROM users WHERE id > ? ORDER BY id LIMIT ?'
      ).bind(cursor, limit)
    : env.DB.prepare(
        'SELECT * FROM users ORDER BY id LIMIT ?'
      ).bind(limit);

  const { results } = await stmt.all<User>();
  return results ?? [];
}
```

### Migration versionada

```sql
-- migrations/0003_add_teams.sql
CREATE TABLE IF NOT EXISTS teams (
  id         TEXT PRIMARY KEY,
  name       TEXT NOT NULL,
  owner_id   TEXT NOT NULL,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_teams_owner
  ON teams (owner_id);

UPDATE schema_info
SET value = '0003', updated_at = unixepoch()
WHERE key = 'version';
```

## Anti-patterns (proibidos)

### 1. Concatenação de SQL

```ts
// ❌ NUNCA — SQL Injection
const stmt = env.DB.prepare(
  `SELECT * FROM users WHERE email = '${email}'`
);
```

### 2. Sem bind em input do usuário

```ts
// ❌ NUNCA
const stmt = env.DB.prepare(`SELECT * FROM users WHERE id = ${id}`);
```

### 3. Alterar schema em produção manualmente

```bash
# ❌ NUNCA — use migrations
wrangler d1 execute DB --command "ALTER TABLE users ADD COLUMN x TEXT" --env production
```

### 4. Retornar resultado cru para o cliente

```ts
// ❌ NUNCA — vaza estrutura e metadados
return json(await env.DB.prepare('SELECT * FROM users').all());

// ✅ SEMPRE — projete apenas o necessário
const { results } = await env.DB.prepare(
  'SELECT id, name FROM users'
).all();
return json({ users: results });
```

### 5. Ignorar índices

Toda coluna usada em `WHERE`, `JOIN ON` ou `ORDER BY` deve ter índice
se a tabela puder crescer.

## Comandos

```bash
# Criar migration vazia
wrangler d1 migrations create DB add_teams

# Aplicar local
wrangler d1 migrations apply DB --local

# Aplicar staging
wrangler d1 migrations apply DB --env staging

# Aplicar produção (após aprovação)
wrangler d1 migrations apply DB --env production

# Listar migrations pendentes
wrangler d1 migrations list DB --env staging

# Executar query ad-hoc (somente dev)
wrangler d1 execute DB --command "SELECT COUNT(*) FROM users" --local

# Exportar dados (backup)
wrangler d1 export DB --output backup.sql --env production
```

## Checklist antes de finalizar

- [ ] Toda query usa `.prepare()` + `.bind()`
- [ ] Nenhuma string concatenada em SQL
- [ ] Migration criada e testada localmente
- [ ] Índices apropriados criados
- [ ] Query testada com dados reais (não só mocks)
- [ ] `schema_info` atualizado na migration
- [ ] Migration NÃO altera tabela existente sem `IF NOT EXISTS` ou lógica segura
- [ ] Testes unitários cobrindo caso de sucesso e erro
- [ ] Se é query de listagem, paginação implementada

## Referências

- Cloudflare D1 docs: https://developers.cloudflare.com/d1/
- SQLite SQL syntax: https://www.sqlite.org/lang.html
- AGENT.md — seção 5, Gate 3
