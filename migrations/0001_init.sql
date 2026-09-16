-- ==============================================================
-- migrations/0001_init.sql — migração inicial do D1
--
-- Convenções:
--   - Nome: NNNN_descricao.sql (sequencial)
--   - Aplicar local:     wrangler d1 migrations apply DB --local
--   - Aplicar staging:   wrangler d1 migrations apply DB --env staging
--   - Aplicar produção:  wrangler d1 migrations apply DB --env production
--
-- Regras:
--   - NUNCA alterar schema em produção manualmente.
--   - Toda migração é imutável após ser aplicada em produção.
--   - Sempre criar índices para colunas usadas em WHERE/JOIN.
--   - Use TEXT para IDs (UUIDs), INTEGER para timestamps unixepoch.
-- ==============================================================

-- --------------------------------------------------------------
-- users
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  email         TEXT NOT NULL UNIQUE,
  name          TEXT NOT NULL,
  role          TEXT NOT NULL DEFAULT 'user'
                CHECK (role IN ('user', 'admin', 'moderator')),
  email_verified INTEGER NOT NULL DEFAULT 0
                CHECK (email_verified IN (0, 1)),
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

CREATE INDEX IF NOT EXISTS idx_users_email
  ON users (email);

CREATE INDEX IF NOT EXISTS idx_users_role
  ON users (role);

-- --------------------------------------------------------------
-- sessions
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sessions (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  expires_at    INTEGER NOT NULL,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  user_agent    TEXT,
  ip_address    TEXT,
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id
  ON sessions (user_id);

CREATE INDEX IF NOT EXISTS idx_sessions_expires_at
  ON sessions (expires_at);

-- --------------------------------------------------------------
-- audit_log — trilha de auditoria (sem PII sensível)
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS audit_log (
  id            TEXT PRIMARY KEY,
  user_id       TEXT,
  action        TEXT NOT NULL,
  resource_type TEXT,
  resource_id   TEXT,
  metadata      TEXT,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE SET NULL
);

CREATE INDEX IF NOT EXISTS idx_audit_log_user_id
  ON audit_log (user_id);

CREATE INDEX IF NOT EXISTS idx_audit_log_action
  ON audit_log (action);

CREATE INDEX IF NOT EXISTS idx_audit_log_created_at
  ON audit_log (created_at);

-- --------------------------------------------------------------
-- notifications — exemplo de tabela com soft delete
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS notifications (
  id            TEXT PRIMARY KEY,
  user_id       TEXT NOT NULL,
  title         TEXT NOT NULL,
  body          TEXT NOT NULL,
  read_at       INTEGER,
  deleted_at    INTEGER,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
  ON notifications (user_id, read_at)
  WHERE deleted_at IS NULL;

-- --------------------------------------------------------------
-- Schema metadata (rastreia a última migração aplicada)
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS schema_info (
  key           TEXT PRIMARY KEY,
  value         TEXT NOT NULL,
  updated_at    INTEGER NOT NULL DEFAULT (unixepoch())
);

INSERT OR IGNORE INTO schema_info (key, value)
VALUES ('version', '0001');
