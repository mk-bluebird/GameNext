// js/token_ai/db/token_ai_schema_bootstrap.js
// Token-AI schema bootstrap and registry initializer.
//
// This module takes the original GameNext-focused SQL schema and provides
// Token-AI–specific utilities to:
//   - Initialize a SQLite database with a cleaned, Token-AI-centric schema.
//   - Register contracts (JSON Schemas, policy files) in a contract_registry.
//   - Link research topics to contracts and terms.
//   - Log schema usage for telemetry and token-efficiency analysis.
//
// All game/engine-specific entries are scrubbed or generalized. The seed data
// now targets Token-AI contracts and terms.

const TOKEN_AI_SCHEMA_SQL = `
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

-- Contract registry: master list of all Token-AI schemas/contracts
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

-- Research topics (Token-AI specific)
CREATE TABLE IF NOT EXISTS research_topic (
    topic_id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    domain TEXT NOT NULL,
    status TEXT NOT NULL,
    abstract TEXT,
    hypothesis TEXT,
    created_date TEXT NOT NULL DEFAULT (date('now')),
    last_updated TEXT NOT NULL DEFAULT (date('now')),
    CHECK (domain IN (
        'token-budgeting',
        'compression',
        'telemetry',
        'eco-impact',
        'prompt-guard',
        'ai-systems',
        'tools',
        'networking'
    )),
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

-- Infrastructure predictions for research topics
CREATE TABLE IF NOT EXISTS research_infra_prediction (
    topic_id TEXT PRIMARY KEY,
    min_model_params REAL,
    recommended_memory_mb INTEGER,
    target_platforms TEXT,
    notes TEXT,
    FOREIGN KEY (topic_id) REFERENCES research_topic(topic_id) ON DELETE CASCADE
);

-- Environment/style packs for Token-AI dashboards and agents
CREATE TABLE IF NOT EXISTS environment_style (
    style_id TEXT PRIMARY KEY,
    name TEXT NOT NULL UNIQUE,
    description TEXT,
    palette_hex TEXT,
    default_parameters_json TEXT,
    created_date TEXT NOT NULL DEFAULT (date('now'))
);

-- Engine/stack compatibility matrix (generalized)
CREATE TABLE IF NOT EXISTS engine_compat (
    engine_id TEXT NOT NULL,
    contract_id TEXT NOT NULL,
    support_level TEXT NOT NULL,
    notes TEXT,
    last_verified TEXT,
    PRIMARY KEY (engine_id, contract_id),
    FOREIGN KEY (contract_id) REFERENCES contract_registry(contract_id) ON DELETE CASCADE,
    CHECK (support_level IN ('native', 'adapter', 'plugin', 'planned', 'unsupported')),
    CHECK (engine_id IN ('node', 'rust', 'cpp', 'browser', 'python', 'custom'))
);

CREATE INDEX IF NOT EXISTS idx_engine_support 
    ON engine_compat(engine_id, support_level);

-- Term definitions for AI queryability (Token-AI terminology)
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

-- Seed data: core Token-AI contracts
INSERT OR IGNORE INTO contract_registry (contract_id, schema_path, version_major, version_minor, title, description) VALUES
('token-ai-profile-schema-v1', 'schemas/token-ai-profile-schema-v1.json', 1, 0, 'Token-AI Profile Schema', 'Per-user/per-project profile for token policy and telemetry hints'),
('token-ai-telemetry-binding-v1', 'schemas/token-ai-telemetry-binding-v1.json', 1, 0, 'Token-AI Telemetry Binding', 'Per-region telemetry binding for UI and metrics'),
('token-ai-telemetry-request-v1', 'schemas/token-ai-telemetry-request-v1.json', 1, 0, 'Token-AI Telemetry Request', 'Telemetry and configuration request envelope'),
('token-ai-telemetry-response-v1', 'schemas/token-ai-telemetry-response-v1.json', 1, 0, 'Token-AI Telemetry Response', 'Telemetry response envelope'),
('token-ai-definition-request-v1', 'schemas/token-ai-definition-request-v1.json', 1, 0, 'Token-AI Definition Request', 'Definition query envelope'),
('token-ai-definition-response-v1', 'schemas/token-ai-definition-response-v1.json', 1, 0, 'Token-AI Definition Response', 'Definition response format');

-- Seed data: core Token-AI terms
INSERT OR IGNORE INTO term_definition (term, definition, source, context) VALUES
('CIC', 'Coherence Integrity Coefficient: measures interaction coherence and stability (0-1)', 'authoritative', 'telemetry'),
('LSG', 'Latency Safety Guard: dampens effects when system latency or safety thresholds are at risk (0-1)', 'authoritative', 'telemetry'),
('tokenLoad', 'Normalized measure of tokens consumed in a given window or region (0-1)', 'authoritative', 'token-budgeting'),
('ecoImpactScore', 'Normalized measure of resource and energy impact for Token-AI interactions (0-1)', 'authoritative', 'eco-impact');
`;

/**
 * Initialize the Token-AI schema in a SQLite database.
 *
 * @param {import('sqlite3').Database} db - An open sqlite3 Database instance.
 * @returns {Promise<void>}
 */
function initializeTokenAiSchema(db) {
  return new Promise((resolve, reject) => {
    db.exec(TOKEN_AI_SCHEMA_SQL, (err) => {
      if (err) {
        reject(err);
      } else {
        resolve();
      }
    });
  });
}

/**
 * Register a new Token-AI contract in the registry.
 *
 * @param {import('sqlite3').Database} db
 * @param {object} contract
 * @param {string} contract.contractId
 * @param {string} contract.schemaPath
 * @param {number} contract.versionMajor
 * @param {number} [contract.versionMinor]
 * @param {string} contract.title
 * @param {string} [contract.description]
 * @returns {Promise<void>}
 */
function registerContract(db, contract) {
  const sql = `
    INSERT OR REPLACE INTO contract_registry (
      contract_id, schema_path, version_major, version_minor, title, description
    ) VALUES (?, ?, ?, ?, ?, ?)
  `;
  const params = [
    contract.contractId,
    contract.schemaPath,
    contract.versionMajor,
    contract.versionMinor ?? 0,
    contract.title,
    contract.description ?? null
  ];

  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve();
    });
  });
}

/**
 * Log usage of a contract for telemetry and token-efficiency analysis.
 *
 * @param {import('sqlite3').Database} db
 * @param {string} contractId
 * @param {string} [usageContext]
 * @returns {Promise<void>}
 */
function logSchemaUsage(db, contractId, usageContext) {
  const sql = `
    INSERT INTO schema_usage_log (contract_id, usage_context)
    VALUES (?, ?)
  `;
  const params = [contractId, usageContext ?? null];

  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve();
    });
  });
}

/**
 * Fetch open/in-progress Token-AI research topics grouped by domain.
 *
 * @param {import('sqlite3').Database} db
 * @returns {Promise<Array<{ domain: string, open_count: number, topic_ids: string }>>}
 */
function getOpenResearchByDomain(db) {
  const sql = `SELECT domain, open_count, topic_ids FROM v_open_research_by_domain`;
  return new Promise((resolve, reject) => {
    db.all(sql, [], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

/**
 * Fetch contract dependency summary for Token-AI contracts.
 *
 * @param {import('sqlite3').Database} db
 * @returns {Promise<Array<{ contract_id: string, title: string, research_topic_count: number, supported_engine_count: number }>>}
 */
function getContractDependencies(db) {
  const sql = `SELECT contract_id, title, research_topic_count, supported_engine_count FROM v_contract_dependencies`;
  return new Promise((resolve, reject) => {
    db.all(sql, [], (err, rows) => {
      if (err) reject(err);
      else resolve(rows);
    });
  });
}

module.exports = {
  TOKEN_AI_SCHEMA_SQL,
  initializeTokenAiSchema,
  registerContract,
  logSchemaUsage,
  getOpenResearchByDomain,
  getContractDependencies
};
