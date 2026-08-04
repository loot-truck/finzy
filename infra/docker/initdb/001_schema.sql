-- Initial schema, applied by the postgres image on first start.
-- The Go services currently keep state in memory; these tables are the target
-- they migrate onto.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email         TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Addresses are compared case-insensitively, so enforce uniqueness that way.
CREATE UNIQUE INDEX users_email_key ON users (lower(email));

CREATE TABLE profiles (
    user_id    UUID PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
    name       TEXT NOT NULL DEFAULT '',
    currency   CHAR(3) NOT NULL DEFAULT 'USD',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE transactions (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE,
    -- Money is stored in minor units to keep arithmetic exact.
    amount_cents BIGINT NOT NULL,
    currency    CHAR(3) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    category    TEXT,
    occurred_at TIMESTAMPTZ NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- The dominant query is "this user's transactions, newest first".
CREATE INDEX transactions_user_occurred_idx
    ON transactions (user_id, occurred_at DESC);
