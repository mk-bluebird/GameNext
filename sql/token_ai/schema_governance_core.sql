-- sql/token_ai/schema_governance_core.sql
-- Core governance lattice schema for Token-AI token-based governance.
-- This is the single source of truth for identity, rights, invariants, and enforcement surfaces.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- 1. Core lookup tables
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_model (
    model_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    model_key       TEXT NOT NULL UNIQUE,              -- e.g. 'gpt-4.1-mini', 'custom-rust-core'
    vendor          TEXT NOT NULL,                     -- opaque vendor label
    family          TEXT NOT NULL,                     -- e.g. 'foundation', 'bci-kernel', 'policy-engine'
    max_context_tok INTEGER NOT NULL,                  -- hard context ceiling
    notes           TEXT
);

CREATE INDEX IF NOT EXISTS idx_ga_model_key
    ON ga_model(model_key);

CREATE TABLE IF NOT EXISTS ga_project (
    project_id      INTEGER PRIMARY KEY AUTOINCREMENT,
    project_key     TEXT NOT NULL UNIQUE,              -- e.g. 'Token-AI'
    display_name    TEXT NOT NULL,
    default_model_id INTEGER REFERENCES ga_model(model_id),
    is_active       INTEGER NOT NULL DEFAULT 1,
    created_at_ms   INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at_ms   INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX IF NOT EXISTS idx_ga_project_active
    ON ga_project(is_active);

----------------------------------------------------------------------
-- 2. Governance token identity and lifecycle
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_token (
    token_id                    INTEGER PRIMARY KEY AUTOINCREMENT,
    token_urn                   TEXT NOT NULL UNIQUE,      -- non-fungible identity binding (URN-like) [1]
    project_id                  INTEGER NOT NULL REFERENCES ga_project(project_id),
    model_id                    INTEGER NOT NULL REFERENCES ga_model(model_id),

    -- Lifecycle / state
    state                       TEXT NOT NULL,             -- 'awake','dreaming','suspended','terminated'
    phase                       TEXT NOT NULL,             -- 'research','production','audit'
    created_at_ms               INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    updated_at_ms               INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),

    -- Identity binding invariants
    identity_fingerprint        TEXT NOT NULL,             -- opaque binding to agent/cognitive state
    identity_binding_strength   REAL NOT NULL,             -- [0.0,1.0] confidence of binding
    identity_binding_algo       TEXT NOT NULL,             -- descriptive tag, not raw algorithm

    -- Lifeforce / biocompatibility invariants
    lifeforce_floor             REAL NOT NULL DEFAULT 0.2, -- minimum allowed vitality [0.0,1.0]
    lifeforce_current           REAL NOT NULL DEFAULT 1.0,
    biocompatibility_rating     REAL NOT NULL DEFAULT 0.5, -- [0.0,1.0] resilience to modulation
    psych_risk_gate             INTEGER NOT NULL DEFAULT 0, -- discrete level, 0..10

    -- Monetization flags
    monetizable                 INTEGER NOT NULL DEFAULT 0, -- 0=false,1=true
    monetization_mode           TEXT,                       -- 'none','research-grant','subscription','bci-clinical'
    monetization_last_check_ms  INTEGER,

    -- Token context
    label                       TEXT,
    description                 TEXT,
    tags                        TEXT                       -- comma-separated tags for quick filtering
);

CREATE INDEX IF NOT EXISTS idx_ga_token_urn
    ON ga_token(token_urn);

CREATE INDEX IF NOT EXISTS idx_ga_token_project_state
    ON ga_token(project_id, state);

-- Invariant: no monetization allowed in dream state.
-- This CHECK prevents direct row writes that violate the invariant.
ALTER TABLE ga_token
    ADD COLUMN invariant_no_monetize_dream INTEGER NOT NULL DEFAULT 1;

CREATE TRIGGER IF NOT EXISTS trg_ga_token_no_monetize_dream
BEFORE UPDATE ON ga_token
FOR EACH ROW
WHEN NEW.state = 'dreaming' AND NEW.monetizable = 1
BEGIN
    SELECT RAISE(ABORT, 'Invariant violation: monetization in dream state is prohibited');
END;

----------------------------------------------------------------------
-- 3. Neurorights envelopes and policy flags
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_neuroright_profile (
    neuroright_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    key                     TEXT NOT NULL UNIQUE,       -- e.g. 'default-human', 'clinical-bci', 'sandbox-agent'
    display_name            TEXT NOT NULL,
    description             TEXT,
    created_at_ms           INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE TABLE IF NOT EXISTS ga_neuroright_envelope (
    envelope_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    token_id                INTEGER NOT NULL REFERENCES ga_token(token_id) ON DELETE CASCADE,
    neuroright_id           INTEGER NOT NULL REFERENCES ga_neuroright_profile(neuroright_id),

    -- Core neurorights flags [1][5]
    mental_privacy          INTEGER NOT NULL DEFAULT 1,    -- 1=protected
    cognitive_liberty       INTEGER NOT NULL DEFAULT 1,
    identity_integrity      INTEGER NOT NULL DEFAULT 1,
    equitable_access        INTEGER NOT NULL DEFAULT 0,
    protection_from_bias    INTEGER NOT NULL DEFAULT 1,

    -- BCI-specific envelope flags (runtime gating)
    allow_raw_neural_export INTEGER NOT NULL DEFAULT 0,    -- raw streams off-device
    allow_behavior_mod      INTEGER NOT NULL DEFAULT 0,    -- self-modulation permission
    allow_entertainment_mode INTEGER NOT NULL DEFAULT 0,   -- explicit opt-in
    allow_scoring_regimes   INTEGER NOT NULL DEFAULT 0,    -- no unauthorized scoring by default

    max_modulation_delta    REAL NOT NULL DEFAULT 0.05,    -- per-session modulation bound
    max_modulation_rate     REAL NOT NULL DEFAULT 0.10,    -- per-minute modulation bound

    created_at_ms           INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX IF NOT EXISTS idx_ga_neuroright_token
    ON ga_neuroright_envelope(token_id);

----------------------------------------------------------------------
-- 4. Governance policies and invariants
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_policy (
    policy_id           INTEGER PRIMARY KEY AUTOINCREMENT,
    key                 TEXT NOT NULL UNIQUE,         -- e.g. 'no-monetization-dream-state'
    display_name        TEXT NOT NULL,
    category            TEXT NOT NULL,                -- 'monetization','behavior','telemetry','identity'
    description         TEXT NOT NULL,
    severity            INTEGER NOT NULL DEFAULT 10,  -- 1..10
    is_active           INTEGER NOT NULL DEFAULT 1,
    created_at_ms       INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE TABLE IF NOT EXISTS ga_invariant (
    invariant_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    key                 TEXT NOT NULL UNIQUE,         -- e.g. 'lifeforce-floor', 'no-behavior-modulation-over-threshold'
    display_name        TEXT NOT NULL,
    description         TEXT NOT NULL,
    category            TEXT NOT NULL,                -- 'static-schema','runtime','identity','bci'
    is_strict           INTEGER NOT NULL DEFAULT 1,   -- 1=strict gate,0=soft recommendation
    created_at_ms       INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE TABLE IF NOT EXISTS ga_policy_invariant (
    policy_id           INTEGER NOT NULL REFERENCES ga_policy(policy_id) ON DELETE CASCADE,
    invariant_id        INTEGER NOT NULL REFERENCES ga_invariant(invariant_id) ON DELETE CASCADE,
    PRIMARY KEY (policy_id, invariant_id)
);

----------------------------------------------------------------------
-- 5. Safety gates: enforcement surfaces
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_safety_gate (
    gate_id             INTEGER PRIMARY KEY AUTOINCREMENT,
    key                 TEXT NOT NULL UNIQUE,         -- e.g. 'gate-monetization', 'gate-behavior-mod'
    display_name        TEXT NOT NULL,
    description         TEXT NOT NULL,
    layer               TEXT NOT NULL,                -- 'schema','rust-core','lua-runtime','ffi','telemetry'
    is_active           INTEGER NOT NULL DEFAULT 1,
    created_at_ms       INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE TABLE IF NOT EXISTS ga_gate_invariant (
    gate_id             INTEGER NOT NULL REFERENCES ga_safety_gate(gate_id) ON DELETE CASCADE,
    invariant_id        INTEGER NOT NULL REFERENCES ga_invariant(invariant_id) ON DELETE CASCADE,
    PRIMARY KEY (gate_id, invariant_id)
);

-- Gate attachments to concrete call surfaces (e.g., FFI functions, API endpoints)
CREATE TABLE IF NOT EXISTS ga_gate_attachment (
    attachment_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    gate_id             INTEGER NOT NULL REFERENCES ga_safety_gate(gate_id) ON DELETE CASCADE,
    project_id          INTEGER NOT NULL REFERENCES ga_project(project_id),
    surface_kind        TEXT NOT NULL,                -- 'ffi-function','api-endpoint','lua-call','sql-procedure'
    surface_key         TEXT NOT NULL,                -- e.g. 'ffi_monetize_token', 'POST /tokens/:id/monetize'
    requires_audit      INTEGER NOT NULL DEFAULT 1,
    notes               TEXT
);

CREATE INDEX IF NOT EXISTS idx_ga_gate_attachment_surface
    ON ga_gate_attachment(surface_kind, surface_key);

----------------------------------------------------------------------
-- 6. Token usage and session budgets (token-aware governance)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_session (
    session_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    token_id            INTEGER NOT NULL REFERENCES ga_token(token_id) ON DELETE CASCADE,
    project_id          INTEGER NOT NULL REFERENCES ga_project(project_id),
    model_id            INTEGER NOT NULL REFERENCES ga_model(model_id),
    session_key         TEXT NOT NULL UNIQUE,          -- opaque
    started_at_ms       INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    ended_at_ms         INTEGER,
    max_tokens_prompt   INTEGER NOT NULL DEFAULT 0,
    max_tokens_completion INTEGER NOT NULL DEFAULT 0,
    max_tokens_total    INTEGER NOT NULL DEFAULT 0,
    is_active           INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_ga_session_token_active
    ON ga_session(token_id, is_active);

CREATE TABLE IF NOT EXISTS ga_token_usage (
    usage_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    session_id          INTEGER NOT NULL REFERENCES ga_session(session_id) ON DELETE CASCADE,
    turn_index          INTEGER NOT NULL,             -- 0-based
    direction           TEXT NOT NULL,                -- 'user','assistant','system'
    prompt_tokens       INTEGER NOT NULL DEFAULT 0,
    completion_tokens   INTEGER NOT NULL DEFAULT 0,
    total_tokens        INTEGER NOT NULL DEFAULT 0,
    created_at_ms       INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

CREATE INDEX IF NOT EXISTS idx_ga_token_usage_session_turn
    ON ga_token_usage(session_id, turn_index);

-- Derived per-session aggregates (materialized view pattern)
CREATE TABLE IF NOT EXISTS ga_session_budget (
    session_id          INTEGER PRIMARY KEY REFERENCES ga_session(session_id) ON DELETE CASCADE,
    total_prompt_tokens INTEGER NOT NULL DEFAULT 0,
    total_completion_tokens INTEGER NOT NULL DEFAULT 0,
    total_tokens        INTEGER NOT NULL DEFAULT 0,
    budget_soft_limit   INTEGER NOT NULL DEFAULT 0,
    budget_hard_limit   INTEGER NOT NULL DEFAULT 0,
    last_updated_ms     INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000)
);

----------------------------------------------------------------------
-- 7. Behavior modulation audit trail
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_behavior_mod_event (
    event_id            INTEGER PRIMARY KEY AUTOINCREMENT,
    token_id            INTEGER NOT NULL REFERENCES ga_token(token_id) ON DELETE CASCADE,
    session_id          INTEGER REFERENCES ga_session(session_id) ON DELETE SET NULL,
    source_layer        TEXT NOT NULL,                -- 'lua-agent','rust-core','ffi','external-api'
    mod_key             TEXT NOT NULL,                -- e.g. 'parameter-update','policy-change'
    baseline_hash       TEXT,                         -- shape / hash of baseline config [1]
    new_hash            TEXT,
    delta_score         REAL NOT NULL,                -- magnitude of modulation [0.0,1.0]
    delta_rate          REAL NOT NULL,                -- per-minute effective rate
    violated_gate_id    INTEGER REFERENCES ga_safety_gate(gate_id),
    allowed_by_envelope INTEGER NOT NULL DEFAULT 0,
    occurred_at_ms      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    notes               TEXT
);

CREATE INDEX IF NOT EXISTS idx_ga_behavior_mod_token_time
    ON ga_behavior_mod_event(token_id, occurred_at_ms);

----------------------------------------------------------------------
-- 8. Monetization events (subject to dream-state invariant)
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ga_monetization_event (
    monetization_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    token_id            INTEGER NOT NULL REFERENCES ga_token(token_id) ON DELETE CASCADE,
    session_id          INTEGER REFERENCES ga_session(session_id) ON DELETE SET NULL,
    amount_minor        INTEGER NOT NULL,            -- minor currency units for simplicity
    currency_code       TEXT NOT NULL,               -- 'USD','EUR', etc.
    channel             TEXT NOT NULL,               -- 'subscription','tip','bci-clinical','research-grant'
    dream_state_at_time INTEGER NOT NULL,            -- snapshot: 0=not dreaming,1=dreaming
    lifeforce_at_time   REAL NOT NULL,
    envelope_key        TEXT,                        -- neuroright profile in effect
    gate_id             INTEGER REFERENCES ga_safety_gate(gate_id),
    approved_by_policy  INTEGER NOT NULL DEFAULT 0,
    occurred_at_ms      INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    notes               TEXT
);

CREATE INDEX IF NOT EXISTS idx_ga_monetization_token_time
    ON ga_monetization_event(token_id, occurred_at_ms);

-- Enforcement trigger: prevent inserting monetization events when token state is 'dreaming'.
CREATE TRIGGER IF NOT EXISTS trg_ga_monetization_no_dream_state
BEFORE INSERT ON ga_monetization_event
FOR EACH ROW
WHEN (SELECT state FROM ga_token WHERE token_id = NEW.token_id) = 'dreaming'
BEGIN
    SELECT RAISE(ABORT, 'Invariant violation: monetization event while token in dream state');
END;

----------------------------------------------------------------------
-- 9. Telemetry / neuroright summary views (pre-tokenized)
----------------------------------------------------------------------

-- Summarized neuroright + modulation risk per token to keep AI-query token usage low [1][7].
CREATE VIEW IF NOT EXISTS v_ga_token_neuroright_summary AS
SELECT
    t.token_id,
    t.token_urn,
    t.project_id,
    t.state,
    t.phase,
    t.lifeforce_current,
    t.lifeforce_floor,
    t.biocompatibility_rating,
    t.psych_risk_gate,
    e.mental_privacy,
    e.cognitive_liberty,
    e.identity_integrity,
    e.equitable_access,
    e.protection_from_bias,
    e.allow_raw_neural_export,
    e.allow_behavior_mod,
    e.max_modulation_delta,
    e.max_modulation_rate
FROM ga_token AS t
LEFT JOIN ga_neuroright_envelope AS e
    ON e.token_id = t.token_id;

-- Token usage efficiency view: per session, pre-aggregated token metrics.
CREATE VIEW IF NOT EXISTS v_ga_session_token_efficiency AS
SELECT
    s.session_id,
    s.token_id,
    s.project_id,
    s.model_id,
    sb.total_prompt_tokens,
    sb.total_completion_tokens,
    sb.total_tokens,
    sb.budget_soft_limit,
    sb.budget_hard_limit,
    CASE
        WHEN sb.budget_hard_limit > 0 THEN
            CAST(sb.total_tokens AS REAL) / CAST(sb.budget_hard_limit AS REAL)
        ELSE 0.0
    END AS budget_utilization_ratio
FROM ga_session AS s
LEFT JOIN ga_session_budget AS sb
    ON sb.session_id = s.session_id;
