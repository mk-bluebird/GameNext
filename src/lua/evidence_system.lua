-- evidence_system.lua
-- Agent-47-Wiki: Lua-side evidence system with SQLite backing.
--
-- This module abstracts "evidence" as neutral, data-driven records
-- that gameplay, tools, and AI agents can query and update.

local EvidenceSystem = {}
EvidenceSystem.__index = EvidenceSystem

-- Expected SQLite wrapper:
-- - db:eval(sql, params_table?) or db:execute(sql)
-- You can adapt this to luasql, sqlite.lua, or engine-specific bindings.

function EvidenceSystem.new(db)
    local self = setmetatable({}, EvidenceSystem)
    self.db = db
    self:_init_schema()
    return self
end

-- Initialize tables if they do not exist.
function EvidenceSystem:_init_schema()
    local sql = [[
    CREATE TABLE IF NOT EXISTS evidence_source (
        id INTEGER PRIMARY KEY,
        kind TEXT NOT NULL,           -- e.g., "camera", "human_witness", "intel_node"
        map_id TEXT NOT NULL,
        location_x REAL,
        location_y REAL,
        location_z REAL,
        radius_or_fov REAL,
        flags INTEGER DEFAULT 0       -- bitfield; engine-defined
    );

    CREATE TABLE IF NOT EXISTS evidence_instance (
        id INTEGER PRIMARY KEY,
        source_id INTEGER NOT NULL,
        mission_run_id TEXT NOT NULL,
        timecode REAL NOT NULL,
        subject TEXT NOT NULL,        -- e.g., "agent47", "npc"
        action_tag TEXT NOT NULL,     -- neutral tag e.g., "device_area_effect"
        severity REAL NOT NULL,
        visibility_state TEXT NOT NULL, -- "hidden", "discoverable", "discovered"
        cleanup_state TEXT NOT NULL,    -- "intact", "partially_cleaned", "fully_cleaned", "destroyed"
        linked_npc_id TEXT,
        linked_item_id TEXT,
        FOREIGN KEY (source_id) REFERENCES evidence_source(id)
    );

    CREATE TABLE IF NOT EXISTS cleanup_action (
        id INTEGER PRIMARY KEY,
        evidence_instance_id INTEGER NOT NULL,
        timecode REAL NOT NULL,
        actor TEXT NOT NULL,          -- e.g., "agent47", "npc", "system"
        action_tag TEXT NOT NULL,     -- e.g., "system_evidence_resolve"
        success INTEGER NOT NULL,     -- 0/1
        notes TEXT,
        FOREIGN KEY (evidence_instance_id) REFERENCES evidence_instance(id)
    );
    ]]
    self.db:eval(sql)
end

-- Register a new evidence source (camera, witness archetype, intel node, etc.)
function EvidenceSystem:register_source(source)
    local sql = [[
        INSERT INTO evidence_source
        (kind, map_id, location_x, location_y, location_z, radius_or_fov, flags)
        VALUES (:kind, :map_id, :x, :y, :z, :r, :flags);
    ]]
    self.db:eval(sql, {
        kind   = source.kind,
        map_id = source.map_id,
        x      = source.location_x or 0,
        y      = source.location_y or 0,
        z      = source.location_z or 0,
        r      = source.radius_or_fov or 0,
        flags  = source.flags or 0,
    })
end

-- Create an evidence instance when a relevant event occurs.
-- "event" is expected to be already mapped to a neutral action_tag.
function EvidenceSystem:create_instance(event)
    local sql = [[
        INSERT INTO evidence_instance
        (source_id, mission_run_id, timecode, subject, action_tag,
         severity, visibility_state, cleanup_state, linked_npc_id, linked_item_id)
        VALUES (:source_id, :run_id, :timecode, :subject, :action_tag,
                :severity, :visibility_state, :cleanup_state, :npc_id, :item_id);
    ]]

    self.db:eval(sql, {
        source_id        = event.source_id,
        run_id           = event.mission_run_id,
        timecode         = event.timecode,
        subject          = event.subject or "agent47",
        action_tag       = event.action_tag,                 -- e.g., "state_neutralize"
        severity         = event.severity or 1.0,
        visibility_state = event.visibility_state or "discoverable",
        cleanup_state    = event.cleanup_state or "intact",
        npc_id           = event.linked_npc_id,
        item_id          = event.linked_item_id,
    })
end

-- Record a cleanup action and update the related evidence instance.
function EvidenceSystem:mark_cleaned(cleanup)
    local sql_action = [[
        INSERT INTO cleanup_action
        (evidence_instance_id, timecode, actor, action_tag, success, notes)
        VALUES (:id, :timecode, :actor, :action_tag, :success, :notes);
    ]]

    self.db:eval(sql_action, {
        id        = cleanup.evidence_instance_id,
        timecode  = cleanup.timecode,
        actor     = cleanup.actor or "agent47",
        action_tag= cleanup.action_tag or "system_evidence_resolve",
        success   = cleanup.success and 1 or 0,
        notes     = cleanup.notes,
    })

    if cleanup.new_cleanup_state then
        local sql_update = [[
            UPDATE evidence_instance
            SET cleanup_state = :state
            WHERE id = :id;
        ]]
        self.db:eval(sql_update, {
            state = cleanup.new_cleanup_state,
            id    = cleanup.evidence_instance_id,
        })
    end
end

-- Get all active evidence for a mission run.
function EvidenceSystem:get_active_for_run(mission_run_id)
    local results = {}
    local sql = [[
        SELECT *
        FROM evidence_instance
        WHERE mission_run_id = :run_id
          AND cleanup_state IN ('intact', 'partially_cleaned');
    ]]

    self.db:eval(sql, { run_id = mission_run_id }, function(row)
        table.insert(results, row)
        return 0
    end)

    return results
end

-- Compute a simple aggregate severity score for unresolved evidence.
function EvidenceSystem:get_unresolved_severity(mission_run_id)
    local total = 0.0
    local sql = [[
        SELECT severity
        FROM evidence_instance
        WHERE mission_run_id = :run_id
          AND cleanup_state IN ('intact', 'partially_cleaned');
    ]]

    self.db:eval(sql, { run_id = mission_run_id }, function(row)
        local v = tonumber(row.severity) or 0
        total = total + v
        return 0
    end)

    return total
end

-- Helper: true if no unresolved evidence remains.
function EvidenceSystem:is_fully_clean(mission_run_id)
    local sql = [[
        SELECT COUNT(*) AS c
        FROM evidence_instance
        WHERE mission_run_id = :run_id
          AND cleanup_state IN ('intact', 'partially_cleaned');
    ]]

    local count = 0
    self.db:eval(sql, { run_id = mission_run_id }, function(row)
        count = tonumber(row.c) or 0
        return 0
    end)

    return count == 0
end

return EvidenceSystem
