-- ==============================================================
-- migrations/0002_add_uploaded_files.sql
--
-- Adiciona tabela para rastrear metadados de arquivos armazenados
-- no R2. O binário fica no bucket; o D1 guarda apenas metadados e
-- referências para permitir consultas, quotas e auditoria.
--
-- Regras:
--   - NUNCA armazenar conteúdo binário no D1.
--   - A key do R2 é a fonte da verdade do objeto.
--   - Toda signed URL deve ter expiração ≤ 15 minutos (regra de app).
-- ==============================================================

-- --------------------------------------------------------------
-- uploaded_files — metadados de objetos no R2
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS uploaded_files (
  id            TEXT PRIMARY KEY,
  r2_key        TEXT NOT NULL UNIQUE,
  owner_id      TEXT NOT NULL,
  file_name     TEXT NOT NULL,
  content_type  TEXT NOT NULL,
  size_bytes    INTEGER NOT NULL CHECK (size_bytes >= 0),
  checksum_sha256 TEXT,
  visibility    TEXT NOT NULL DEFAULT 'private'
                CHECK (visibility IN ('private', 'tenant', 'public')),
  status        TEXT NOT NULL DEFAULT 'ready'
                CHECK (status IN ('pending', 'ready', 'quarantined', 'deleted')),
  deleted_at    INTEGER,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (owner_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Busca por dono (listagem "meus arquivos")
CREATE INDEX IF NOT EXISTS idx_uploaded_files_owner
  ON uploaded_files (owner_id, created_at DESC)
  WHERE deleted_at IS NULL;

-- Busca por content-type (relatórios, quotas por tipo)
CREATE INDEX IF NOT EXISTS idx_uploaded_files_content_type
  ON uploaded_files (content_type)
  WHERE deleted_at IS NULL;

-- Rastreio de arquivos pendentes (uploads incompletos)
CREATE INDEX IF NOT EXISTS idx_uploaded_files_status
  ON uploaded_files (status)
  WHERE status != 'ready';

-- --------------------------------------------------------------
-- file_shares — controle de compartilhamento com expiração
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS file_shares (
  id            TEXT PRIMARY KEY,
  file_id       TEXT NOT NULL,
  token_hash    TEXT NOT NULL UNIQUE,
  expires_at    INTEGER NOT NULL,
  max_downloads INTEGER,
  download_count INTEGER NOT NULL DEFAULT 0 CHECK (download_count >= 0),
  revoked_at    INTEGER,
  created_by    TEXT NOT NULL,
  created_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (file_id) REFERENCES uploaded_files (id) ON DELETE CASCADE,
  FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_file_shares_file
  ON file_shares (file_id)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_file_shares_expires
  ON file_shares (expires_at)
  WHERE revoked_at IS NULL;

-- --------------------------------------------------------------
-- storage_usage — quota por usuário (atualizada por trigger)
-- --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS storage_usage (
  user_id       TEXT PRIMARY KEY,
  total_bytes   INTEGER NOT NULL DEFAULT 0 CHECK (total_bytes >= 0),
  file_count    INTEGER NOT NULL DEFAULT 0 CHECK (file_count >= 0),
  updated_at    INTEGER NOT NULL DEFAULT (unixepoch()),
  FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- --------------------------------------------------------------
-- Triggers — manter storage_usage em sincronia
-- --------------------------------------------------------------

-- Soma ao inserir arquivo pronto
CREATE TRIGGER IF NOT EXISTS trg_uploaded_files_insert
AFTER INSERT ON uploaded_files
WHEN NEW.status = 'ready' AND NEW.deleted_at IS NULL
BEGIN
  INSERT INTO storage_usage (user_id, total_bytes, file_count)
  VALUES (NEW.owner_id, NEW.size_bytes, 1)
  ON CONFLICT(user_id) DO UPDATE SET
    total_bytes = total_bytes + NEW.size_bytes,
    file_count  = file_count + 1,
    updated_at  = unixepoch();
END;

-- Subtrai em soft delete
CREATE TRIGGER IF NOT EXISTS trg_uploaded_files_soft_delete
AFTER UPDATE OF deleted_at ON uploaded_files
WHEN OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL
BEGIN
  UPDATE storage_usage
  SET total_bytes = MAX(0, total_bytes - OLD.size_bytes),
      file_count  = MAX(0, file_count - 1),
      updated_at  = unixepoch()
  WHERE user_id = OLD.owner_id;
END;

-- --------------------------------------------------------------
-- Bump da versão do schema
-- --------------------------------------------------------------
UPDATE schema_info
SET value = '0002',
    updated_at = unixepoch()
WHERE key = 'version';
