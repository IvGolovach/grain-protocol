CREATE TABLE IF NOT EXISTS accounts (
  account_id TEXT PRIMARY KEY,
  created_at_ms INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('active', 'deleted')),
  anonymous_device_hash TEXT
);

CREATE TABLE IF NOT EXISTS app_attest_devices (
  device_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  key_id TEXT NOT NULL,
  public_key_cose_b64 TEXT NOT NULL,
  environment TEXT NOT NULL CHECK (environment IN ('development', 'production')),
  sign_count INTEGER NOT NULL DEFAULT 0,
  created_at_ms INTEGER NOT NULL,
  last_seen_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS auth_challenges (
  challenge_id TEXT PRIMARY KEY,
  account_id TEXT,
  device_id TEXT,
  nonce_b64 TEXT NOT NULL,
  purpose TEXT NOT NULL CHECK (purpose IN ('register', 'session')),
  expires_at_ms INTEGER NOT NULL,
  consumed_at_ms INTEGER
);

CREATE TABLE IF NOT EXISTS sessions (
  session_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  device_id TEXT REFERENCES app_attest_devices(device_id) ON DELETE SET NULL,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'pro')),
  issued_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER NOT NULL,
  revoked_at_ms INTEGER
);

CREATE TABLE IF NOT EXISTS entitlements (
  entitlement_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  tier TEXT NOT NULL CHECK (tier IN ('free', 'pro')),
  source TEXT NOT NULL CHECK (source IN ('local_dev', 'storekit')),
  product_id TEXT,
  original_transaction_id TEXT,
  effective_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER,
  updated_at_ms INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS storekit_transactions (
  transaction_id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  original_transaction_id TEXT NOT NULL,
  environment TEXT NOT NULL CHECK (environment IN ('Sandbox', 'Production')),
  signed_transaction_b64 TEXT NOT NULL,
  verified_at_ms INTEGER NOT NULL,
  expires_at_ms INTEGER
);

CREATE TABLE IF NOT EXISTS storekit_notifications (
  notification_id TEXT PRIMARY KEY,
  original_transaction_id TEXT,
  notification_type TEXT NOT NULL,
  subtype TEXT,
  signed_payload_b64 TEXT NOT NULL,
  received_at_ms INTEGER NOT NULL,
  processed_at_ms INTEGER
);

CREATE TABLE IF NOT EXISTS usage_buckets (
  account_id TEXT NOT NULL REFERENCES accounts(account_id) ON DELETE CASCADE,
  feature TEXT NOT NULL CHECK (feature IN ('photo_analysis', 'food_search')),
  bucket_start_ms INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0,
  limit_value INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  PRIMARY KEY (account_id, feature, bucket_start_ms)
);

CREATE INDEX IF NOT EXISTS idx_sessions_account ON sessions(account_id);
CREATE INDEX IF NOT EXISTS idx_usage_buckets_account ON usage_buckets(account_id, bucket_start_ms);
CREATE INDEX IF NOT EXISTS idx_storekit_transactions_account ON storekit_transactions(account_id);
