-- sql/token_ai/schema_research_contracts.sql
-- Token-AI: Research, Contracts, and Environment Schema
--
-- This schema is designed for Token-AI to:
--   - Track research topics related to token optimization, safety, and eco-impact.
--   - Link topics to executable contracts/policies used by AI-chat tools and agents.
--   - Store environment styles and parameter sets that influence token and telemetry behavior.
--   - Provide a normalized base for analytics and formal specification of Token-AI behaviors.
--
-- All game-specific notions have been scrubbed; remaining entities are generic for
-- AI systems, tooling, and research orchestration.

PRAGMA foreign_keys = ON;

----------------------------------------------------------------------
-- Core research topics
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS research_topic (
    topic_id      TEXT PRIMARY KEY,
    title         TEXT NOT NULL,
    -- Domain tags for Token-AI relevant areas.
    domain        TEXT NOT NULL CHECK(
        domain IN (
            'ai',
            'bci',
            'input',
            'data',
            'tools',
            'rendering',
            'audio',
            'physics',
            'cross-cutting'
        )
    ),
    status        TEXT NOT NULL CHECK(
        status IN (
            'open',
            'in-progress',
            'implemented',
            'blocked',
            'speculative'
        )
    ),
    -- Abstract and hypothesis allow storing structured research notes
    -- for token usage strategies, safety mechanisms, and eco-aware scheduling.
    abstract      TEXT NOT NULL DEFAULT '',
    hypothesis    TEXT NOT NULL DEFAULT ''
);

----------------------------------------------------------------------
-- Mapping between research topics and contracts/policies
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS research_related_contract (
    topic_id      TEXT NOT NULL REFERENCES research_topic(topic_id) ON DELETE CASCADE,
    contract_id   TEXT NOT NULL,
    PRIMARY KEY (topic_id, contract_id)
);

----------------------------------------------------------------------
-- Environment styles and parameter sets
-- Used for configuring AI-chat environments, simulation contexts, and
-- token-policy settings without any game semantics.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS environment_style (
    style_id      TEXT PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE,
    -- palette_hex can represent color or label palettes for dashboards,
    -- UI themes, or token-usage visualizations (stored as JSON array of hex strings).
    palette_hex   TEXT NOT NULL DEFAULT '[]',
    -- default_parameters_json is a JSON object that can hold token-budget
    -- defaults, logging verbosity, safety thresholds, and eco-impact weights.
    default_parameters_json  TEXT NOT NULL DEFAULT '{}'
);

----------------------------------------------------------------------
-- Contract registry for executable policies and schemas
-- These contracts represent formalized behaviors such as:
--   - Token budgeting and throttling rules.
--   - Prompt-guard and safety policies.
--   - Telemetry and eco-impact reporting schemas.
----------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS contract_registry (
    contract_id   TEXT PRIMARY KEY,
    -- schema_path can point to a file or resource describing the contract structure,
    -- e.g., JSON Schema, TLA+ spec, or DSL definition used by Token-AI.
    schema_path   TEXT NOT NULL,
    version_major INTEGER NOT NULL,
    description   TEXT NOT NULL
);

----------------------------------------------------------------------
-- Indexes for efficient querying and analysis
----------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_research_domain_status
    ON research_topic(domain, status);

CREATE INDEX IF NOT EXISTS idx_research_contract
    ON research_related_contract(contract_id);

CREATE INDEX IF NOT EXISTS idx_contract_registry_version
    ON contract_registry(version_major);
