ALTER TABLE sessions ADD COLUMN token_hash TEXT;

ALTER TABLE accounts ADD COLUMN app_account_token TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS idx_sessions_token_hash
  ON sessions(token_hash)
  WHERE token_hash IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_anonymous_device_hash
  ON accounts(anonymous_device_hash)
  WHERE anonymous_device_hash IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_accounts_app_account_token
  ON accounts(app_account_token)
  WHERE app_account_token IS NOT NULL;

CREATE TABLE IF NOT EXISTS usage_reservations (
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  feature TEXT NOT NULL CHECK (feature IN ('photo_analysis', 'food_search')),
  bucket_start_ms INTEGER NOT NULL,
  request_id TEXT NOT NULL,
  created_at_ms INTEGER NOT NULL,
  PRIMARY KEY (account_id, feature, bucket_start_ms, request_id)
);

CREATE INDEX IF NOT EXISTS idx_usage_reservations_account
  ON usage_reservations(account_id, bucket_start_ms);
