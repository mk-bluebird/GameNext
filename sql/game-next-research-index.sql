-- filename: sql/game-next-research-index.sql
-- destination: GameNext/sql/game-next-research-index.sql

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS research_topic (
    topic_id      TEXT PRIMARY KEY,
    title         TEXT NOT NULL,
    domain        TEXT NOT NULL CHECK(domain IN ('rendering','audio','physics','ai','bci','input','data','tools','cross-cutting')),
    status        TEXT NOT NULL CHECK(status IN ('open','in-progress','implemented','blocked','speculative')),
    abstract      TEXT NOT NULL DEFAULT '',
    hypothesis    TEXT NOT NULL DEFAULT ''
);

CREATE TABLE IF NOT EXISTS research_related_contract (
    topic_id      TEXT NOT NULL REFERENCES research_topic(topic_id) ON DELETE CASCADE,
    contract_id   TEXT NOT NULL,
    PRIMARY KEY (topic_id, contract_id)
);

CREATE TABLE IF NOT EXISTS environment_style (
    style_id      TEXT PRIMARY KEY,
    name          TEXT NOT NULL UNIQUE,
    palette_hex   TEXT NOT NULL DEFAULT '[]',
    default_parameters_json  TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS contract_registry (
    contract_id   TEXT PRIMARY KEY,
    schema_path   TEXT NOT NULL,
    version_major INTEGER NOT NULL,
    description   TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_research_domain_status ON research_topic(domain, status);
CREATE INDEX IF NOT EXISTS idx_research_contract ON research_related_contract(contract_id);
CREATE INDEX IF NOT EXISTS idx_contract_registry_version ON contract_registry(version_major);
