-- File: game-next-research-index.sql
-- Destination: GameNext/db/game-next-research-index.sql
-- Purpose: Core knowledge graph for GameNext research, contracts, and engine compatibility

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Contract registry: master list of all GameNext schemas
CREATE TABLE IF NOT EXISTS contract_registry (
    contract_id TEXT PRIMARY KEY,
    schema_path TEXT NOT NULL UNIQUE,
    version_major INTEGER NOT NULL,
    version_minor INTEGER NOT NULL DEFAULT 0,
    title TEXT NOT NULL,
    description TEXT,
    created_date TEXT NOT NULL DEFAULT (date('now')),
    deprecated BOOLEAN NOT NULL DEFAULT 0,
    CHECK (version_major >= 1),
    CHECK (version_minor >= 0)
);

CREATE INDEX IF NOT EXISTS idx_contract_version 
    ON contract_registry(version_major, version_minor);

-- Research topics
CREATE TABLE IF NOT EXISTS research_topic (
    topic_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    domain TEXT NOT NULL,
    status TEXT NOT NULL,
    abstract TEXT,
    hypothesis TEXT,
    created_date TEXT NOT NULL DEFAULT (date('now')),
    last_updated TEXT NOT NULL DEFAULT (date('now')),
    CHECK (domain IN ('rendering', 'bci', 'audio', 'physics', 'tools', 'networking', 'ai-systems')),
    CHECK (status IN ('open', 'in-progress', 'implemented', 'speculative', 'deferred'))
);

CREATE INDEX IF NOT EXISTS idx_research_domain_status 
    ON research_topic(domain, status);
CREATE INDEX IF NOT EXISTS idx_research_status 
    ON research_topic(status) WHERE status IN ('open', 'in-progress');

-- Link research topics to contracts
CREATE TABLE IF NOT EXISTS research_related_contract (
    topic_id TEXT NOT NULL,
    contract_id TEXT NOT NULL,
    relationship_type TEXT DEFAULT 'implements',
    PRIMARY KEY (topic_id, contract_id),
    FOREIGN KEY (topic_id) REFERENCES research_topic(topic_id) ON DELETE CASCADE,
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE,
    CHECK (relationship_type IN ('implements', 'extends', 'depends-on', 'supersedes'))
);

CREATE INDEX IF NOT EXISTS idx_contract_topics 
    ON research_related_contract(contract_id);

-- Hardware predictions for research topics
CREATE TABLE IF NOT EXISTS research_hardware_prediction (
    topic_id TEXT PRIMARY KEY,
    min_gpu_flops REAL,
    recommended_memory_mb INTEGER,
    target_platforms TEXT,
    notes TEXT,
    FOREIGN KEY (topic_id) REFERENCES research_topic(topic_id) ON DELETE CASCADE
);

-- Environment/style packs
CREATE TABLE IF NOT EXISTS environment_style (
    style_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    palette_hex TEXT,
    default_parameters_json TEXT,
    created_date TEXT NOT NULL DEFAULT (date('now'))
);

-- Engine compatibility matrix
CREATE TABLE IF NOT EXISTS engine_compat (
    engine_id TEXT NOT NULL,
    contract_id TEXT NOT NULL,
    support_level TEXT NOT NULL,
    notes TEXT,
    last_verified TEXT,
    PRIMARY KEY (engine_id, contract_id),
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE,
    CHECK (support_level IN ('native', 'adapter', 'plugin', 'planned', 'unsupported')),
    CHECK (engine_id IN ('unreal', 'unity', 'godot', 'bevy', 'custom-cpp', 'custom-rust'))
);

CREATE INDEX IF NOT EXISTS idx_engine_support 
    ON engine_compat(engine_id, support_level);

-- Term definitions for AI queryability
CREATE TABLE IF NOT EXISTS term_definition (
    term TEXT PRIMARY KEY COLLATE NOCASE,
    definition TEXT NOT NULL,
    source TEXT NOT NULL,
    context TEXT,
    created_date TEXT NOT NULL DEFAULT (date('now')),
    CHECK (source IN ('authoritative', 'contributed', 'ai-inferred'))
);

-- Link terms to contracts where they appear
CREATE TABLE IF NOT EXISTS term_contract_usage (
    term TEXT NOT NULL COLLATE NOCASE,
    contract_id TEXT NOT NULL,
    field_path TEXT,
    PRIMARY KEY (term, contract_id),
    FOREIGN KEY (term) REFERENCES term_definition(term) ON DELETE CASCADE,
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE
);

-- Telemetry: track schema usage patterns
CREATE TABLE IF NOT EXISTS schema_usage_log (
    log_id INTEGER PRIMARY KEY AUTOINCREMENT,
    contract_id TEXT NOT NULL,
    timestamp_ms INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
    usage_context TEXT,
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_usage_timestamp 
    ON schema_usage_log(timestamp_ms DESC);

-- Common queries for AI agents
CREATE VIEW IF NOT EXISTS v_open_research_by_domain AS
SELECT 
    domain,
    COUNT(*) AS open_count,
    GROUP_CONCAT(topic_id, ', ') AS topic_ids
FROM research_topic
WHERE status IN ('open', 'in-progress')
GROUP BY domain;

CREATE VIEW IF NOT EXISTS v_contract_dependencies AS
SELECT 
    c.contract_id,
    c.title,
    COUNT(DISTINCT r.topic_id) AS research_topic_count,
    COUNT(DISTINCT e.engine_id) AS supported_engine_count
FROM contract_registry c
LEFT JOIN research_related_contract r ON c.contract_id = r.contract_id
LEFT JOIN engine_compat e ON c.contract_id = e.contract_id AND e.support_level IN ('native', 'adapter')
GROUP BY c.contract_id, c.title;

-- Seed data: core contracts
INSERT OR IGNORE INTO contract_registry (contract_id, schema_path, version_major, version_minor, title) VALUES
('game-next-ai-bci-geometry-request-v1', 'schemas/game-next-ai-bci-geometry-request-v1.json', 1, 0, 'AI BCI Geometry Request'),
('game-next-bci-geometry-binding-v1', 'schemas/game-next-bci-geometry-binding-v1.json', 1, 0, 'BCI Geometry Binding'),
('grime-geometry-binding-v1', 'schemas/grime-geometry-binding-v1.json', 1, 0, 'Grime Geometry Binding'),
('game-next-research-topic-v1', 'schemas/game-next-research-topic-v1.json', 1, 0, 'Research Topic Schema');

-- Seed data: core terms
INSERT OR IGNORE INTO term_definition (term, definition, source) VALUES
('CIC', 'Constellation Integrity Coefficient: measures BCI signal constellation stability (0-1)', 'authoritative'),
('LSG', 'Latency Safety Guard: dampens effects when system latency degrades (0-1)', 'authoritative'),
('maskRadius', 'Normalized radius of central safe visual region; smaller values = tighter vignette (0-1)', 'authoritative'),
('grimeAdhesion', 'Rate at which grime accumulates on surfaces based on material porosity and exposure', 'authoritative');
