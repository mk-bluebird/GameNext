-- ai_function_registry.sql
-- Agent-47-Wiki: AI-Chat function-code bundle and registry.
--
-- This script defines tables for registering AI-callable functions
-- (Lua modules, C++/Rust bindings, SQL helpers) so chat agents and
-- coding agents can discover and reuse them consistently.

PRAGMA foreign_keys = ON;

------------------------------------------------------------
-- Core registry tables
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS ai_function (
  id INTEGER PRIMARY KEY,
  name TEXT NOT NULL UNIQUE,              -- e.g., "evidence_create_instance"
  module TEXT NOT NULL,                   -- e.g., "evidence_system.lua"
  language TEXT NOT NULL,                 -- "lua", "cpp", "rust", "sql"
  summary TEXT NOT NULL,                  -- short description for AI-Chat
  input_schema TEXT,                      -- JSON description of expected args
  output_schema TEXT,                     -- JSON description of result
  invariants TEXT,                        -- rules AI must respect when using it
  is_stable INTEGER NOT NULL DEFAULT 1,   -- 1 = safe to rely on, 0 = experimental
  tags TEXT                               -- comma-separated tags, e.g., "stealth,evidence"
);

CREATE TABLE IF NOT EXISTS ai_function_param (
  id INTEGER PRIMARY KEY,
  function_id INTEGER NOT NULL,
  name TEXT NOT NULL,                     -- parameter name
  type TEXT NOT NULL,                     -- e.g., "string", "number", "boolean"
  required INTEGER NOT NULL DEFAULT 1,    -- 1 = required, 0 = optional
  description TEXT NOT NULL,
  default_value TEXT,
  FOREIGN KEY (function_id) REFERENCES ai_function(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS ai_function_example (
  id INTEGER PRIMARY KEY,
  function_id INTEGER NOT NULL,
  example_call TEXT NOT NULL,             -- e.g., JSON or pseudo-code
  example_context TEXT,                   -- when/why to call it
  FOREIGN KEY (function_id) REFERENCES ai_function(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Seed: Evidence System (Lua)
------------------------------------------------------------

INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'evidence_register_source',
  'src/lua/evidence_system.lua',
  'lua',
  'Register a new evidence source (camera, witness, intel node) into the SQLite-backed evidence system.',
  '{
    "type": "object",
    "properties": {
      "kind":        { "type": "string", "description": "Source type, e.g. camera, human_witness" },
      "map_id":      { "type": "string", "description": "Logical map identifier" },
      "location_x":  { "type": "number" },
      "location_y":  { "type": "number" },
      "location_z":  { "type": "number" },
      "radius_or_fov": { "type": "number", "description": "Sensing radius or field-of-view" },
      "flags":       { "type": "integer", "description": "Engine-defined bitfield" }
    },
    "required": ["kind", "map_id"]
  }',
  '{
    "type": "null",
    "description": "No direct return; source row inserted into evidence_source."
  }',
  'Uses neutral vocabulary for sources. Does not log real-world entities. Safe for tooling and telemetry analysis.',
  'evidence,sqlite,setup'
);

INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'evidence_create_instance',
  'src/lua/evidence_system.lua',
  'lua',
  'Create a new evidence instance when a neutral action tag is observed by a source.',
  '{
    "type": "object",
    "properties": {
      "source_id":        { "type": "integer", "description": "ID from evidence_source" },
      "mission_run_id":   { "type": "string",  "description": "Unique run identifier" },
      "timecode":         { "type": "number",  "description": "Seconds since mission start" },
      "subject":          { "type": "string",  "description": "agent47, npc, or abstract actor" },
      "action_tag":       { "type": "string",  "description": "Neutral tag like state_neutralize" },
      "severity":         { "type": "number" },
      "visibility_state": { "type": "string",  "description": "hidden, discoverable, discovered" },
      "cleanup_state":    { "type": "string",  "description": "intact, partially_cleaned, fully_cleaned, destroyed" },
      "linked_npc_id":    { "type": "string" },
      "linked_item_id":   { "type": "string" }
    },
    "required": ["source_id", "mission_run_id", "timecode", "action_tag"]
  }',
  '{
    "type": "null",
    "description": "No direct return; instance row inserted into evidence_instance."
  }',
  'action_tag MUST use neutral vocabulary defined in docs/policy/action-tag-abstractions-v1.md. No graphic descriptions are stored. This function is for abstract game events only.',
  'evidence,telemetry,neutral-tags'
);

INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'evidence_mark_cleaned',
  'src/lua/evidence_system.lua',
  'lua',
  'Record a cleanup action and update the cleanup_state of an evidence instance.',
  '{
    "type": "object",
    "properties": {
      "evidence_instance_id": { "type": "integer" },
      "timecode":            { "type": "number" },
      "actor":               { "type": "string", "description": "agent47, npc, system" },
      "action_tag":          { "type": "string", "description": "Typically system_evidence_resolve" },
      "success":             { "type": "boolean" },
      "notes":               { "type": "string" },
      "new_cleanup_state":   { "type": "string", "description": "partially_cleaned, fully_cleaned, or destroyed" }
    },
    "required": ["evidence_instance_id", "timecode", "success"]
  }',
  '{
    "type": "null",
    "description": "No direct return; cleanup_action row inserted and evidence_instance updated."
  }',
  'Cleanup events are abstract (e.g. evidence resolved). Do not use this to describe real-world harm; it is purely a game-system concept.',
  'evidence,cleanup,sqlite'
);

INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'evidence_get_active_for_run',
  'src/lua/evidence_system.lua',
  'lua',
  'Retrieve all active (unresolved) evidence instances for a mission run.',
  '{
    "type": "object",
    "properties": {
      "mission_run_id": { "type": "string" }
    },
    "required": ["mission_run_id"]
  }',
  '{
    "type": "array",
    "items": {
      "type": "object",
      "description": "Rows from evidence_instance with cleanup_state intact or partially_cleaned."
    }
  }',
  'Used for scoring, narrative, and analysis. Returned rows contain neutral action tags only.',
  'evidence,query,scoring'
);

INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'evidence_get_unresolved_severity',
  'src/lua/evidence_system.lua',
  'lua',
  'Compute an aggregate severity score for unresolved evidence in a mission run.',
  '{
    "type": "object",
    "properties": {
      "mission_run_id": { "type": "string" }
    },
    "required": ["mission_run_id"]
  }',
  '{
    "type": "number",
    "description": "Total severity of unresolved evidence."
  }',
  'Use the resulting score as one input into rating and notoriety calculations, not as a standalone punishment metric.',
  'evidence,scoring,notoriety-input'
);

INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'evidence_is_fully_clean',
  'src/lua/evidence_system.lua',
  'lua',
  'Check whether a mission run has no unresolved evidence remaining.',
  '{
    "type": "object",
    "properties": {
      "mission_run_id": { "type": "string" }
    },
    "required": ["mission_run_id"]
  }',
  '{
    "type": "boolean",
    "description": "true if no active evidence instances remain."
  }',
  'Helpful for Silent Assassin / clean run logic. The result is descriptive of game state only.',
  'evidence,query,ratings'
);

------------------------------------------------------------
-- Example parameters for one function (evidence_create_instance)
------------------------------------------------------------

INSERT OR IGNORE INTO ai_function_param (
  function_id, name, type, required, description, default_value
)
SELECT id, 'source_id', 'integer', 1, 'ID from evidence_source table', NULL
FROM ai_function WHERE name = 'evidence_create_instance';

INSERT OR IGNORE INTO ai_function_param (
  function_id, name, type, required, description, default_value
)
SELECT id, 'mission_run_id', 'string', 1, 'Unique mission run identifier', NULL
FROM ai_function WHERE name = 'evidence_create_instance';

INSERT OR IGNORE INTO ai_function_param (
  function_id, name, type, required, description, default_value
)
SELECT id, 'timecode', 'number', 1, 'Seconds since mission start', NULL
FROM ai_function WHERE name = 'evidence_create_instance';

INSERT OR IGNORE INTO ai_function_param (
  function_id, name, type, required, description, default_value
)
SELECT id, 'action_tag', 'string', 1, 'Neutral tag like state_neutralize or access_restricted_entry', NULL
FROM ai_function WHERE name = 'evidence_create_instance';

------------------------------------------------------------
-- Example usage snippet
------------------------------------------------------------

INSERT OR IGNORE INTO ai_function_example (
  function_id, example_call, example_context
)
SELECT
  id,
  'evidence_create_instance({ source_id = 12, mission_run_id = "MAP01_RUN_0007", timecode = 143.2, subject = "agent47", action_tag = "access_restricted_entry", severity = 3.0 })',
  'Called by a Lua mission script when the player enters a restricted zone observed by a registered source.',
FROM ai_function WHERE name = 'evidence_create_instance';
