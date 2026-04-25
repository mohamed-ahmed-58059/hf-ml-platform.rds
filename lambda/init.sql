CREATE EXTENSION IF NOT EXISTS pgcrypto;


-- Tiers
CREATE TABLE IF NOT EXISTS tiers (
    id               UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    name             VARCHAR(20)    NOT NULL UNIQUE,
    capacity         INTEGER        NOT NULL,
    refill_per_sec   NUMERIC(10, 4) NOT NULL,
    requests_per_min INTEGER        NOT NULL,
    version          INTEGER        NOT NULL DEFAULT 1
);


-- Routes
-- Single source of truth for registered endpoints.
-- tier_endpoints.endpoint is a FK to routes.path — you cannot define a rate limit
-- policy for an endpoint that does not exist as a route.
-- Internal routes live under /internal/v1/ and are blocked at the ALB port 80 listener.
CREATE TABLE IF NOT EXISTS routes (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    path       VARCHAR(255) NOT NULL UNIQUE,
    upstream   VARCHAR(255) NOT NULL,
    active     BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now()
);


-- Tier Endpoints
-- Per-endpoint rate limit overrides per tier.
-- Falls back to global tier limits (tiers.capacity / tiers.refill_per_sec) when no row exists.
CREATE TABLE IF NOT EXISTS tier_endpoints (
    id             UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    tier_id        UUID           NOT NULL REFERENCES tiers(id),
    endpoint       VARCHAR(255)   NOT NULL REFERENCES routes(path),
    capacity       INTEGER        NOT NULL,
    refill_per_sec NUMERIC(10, 4) NOT NULL,
    UNIQUE (tier_id, endpoint)
);


-- Users
CREATE TABLE IF NOT EXISTS users (
    id            UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    default_tier  UUID         NOT NULL REFERENCES tiers(id),
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now()
);


-- Sessions
CREATE TABLE IF NOT EXISTS sessions (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NOT NULL,
    revoked_at    TIMESTAMPTZ,
    revoke_reason TEXT,
    ip            INET,
    user_agent    TEXT
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_active
    ON sessions(user_id, last_seen_at ASC)
    WHERE revoked_at IS NULL;


-- Refresh Tokens
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id            UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id    UUID        NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    user_id       UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash    BYTEA       NOT NULL UNIQUE,
    issued_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at    TIMESTAMPTZ NOT NULL,
    parent_id     UUID        REFERENCES refresh_tokens(id) ON DELETE SET NULL,
    redeemed_at   TIMESTAMPTZ,
    grace_until   TIMESTAMPTZ,
    revoked_at    TIMESTAMPTZ,
    revoke_reason TEXT
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_session
    ON refresh_tokens(session_id)
    WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user
    ON refresh_tokens(user_id)
    WHERE revoked_at IS NULL;


-- Service Clients
CREATE TABLE IF NOT EXISTS service_clients (
    id                 UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id          VARCHAR(255) NOT NULL UNIQUE,
    client_secret_hash VARCHAR(255) NOT NULL,
    name               VARCHAR(255) NOT NULL,
    tier               UUID         NOT NULL REFERENCES tiers(id),
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at         TIMESTAMPTZ
);


-- API Keys
CREATE TABLE IF NOT EXISTS api_keys (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    key_hash   BYTEA        NOT NULL UNIQUE,
    tier       UUID         NOT NULL REFERENCES tiers(id),
    name       VARCHAR(100) NOT NULL,
    status     VARCHAR(20)  NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
    created_at TIMESTAMPTZ  NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    UNIQUE (user_id, name)
);


-- Tiers (seed data)
INSERT INTO tiers (name, capacity, refill_per_sec, requests_per_min) VALUES
    ('free', 25, 0.3333, 20)
ON CONFLICT (name) DO NOTHING;


