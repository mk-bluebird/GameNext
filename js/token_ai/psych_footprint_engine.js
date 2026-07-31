// js/token_ai/psych_footprint_engine.js
// Token-AI Psych-Footprint Engine
//
// Scrubbed and transformed from a game-specific "grime" integrator into a
// psych-footprint module for Token-AI, supporting augmented citizens and
// stakeholders with BCI-type integrations on organic CPU.
//
// Focus:
//   - Track per-session psych-footprints (stress, clarity, overload, latency)
//   - Respect psych-continuity, preferences, and invariants (CIC, AOS, DET, LSG)
//   - Persist frames and bindings in SQLite for long-horizon continuity
//
// This module is designed to be AI-/GitHub-friendly and free of game semantics.

const sqlite3 = require("sqlite3").verbose();

// ---------------------------------------------------------------------
// Core math helpers
// ---------------------------------------------------------------------

function clamp01(v) {
  if (v < 0.0) return 0.0;
  if (v > 1.0) return 1.0;
  return v;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

// ---------------------------------------------------------------------
// Psych footprint parameter types (replacing GrimeParams)
// ---------------------------------------------------------------------

class PsychParams {
  constructor({
    stress = 0.0,
    clarity = 0.5,
    overload = 0.0,
    fatigue = 0.0,
    integrationDepth = 0.5,
    comfort = 0.5,
    signalPorosity = 0.5,
    flowDirX = 0.0,
    flowDirY = -1.0,
    stretchDirX = 0.0,
    stretchDirY = 0.0
  } = {}) {
    this.stress = clamp01(stress);
    this.clarity = clamp01(clarity);
    this.overload = clamp01(overload);
    this.fatigue = clamp01(fatigue);
    this.integrationDepth = clamp01(integrationDepth);
    this.comfort = clamp01(comfort);
    this.signalPorosity = clamp01(signalPorosity);
    this.flowDirX = flowDirX;
    this.flowDirY = flowDirY;
    this.stretchDirX = stretchDirX;
    this.stretchDirY = stretchDirY;
    this._normalizeVectors();
  }

  _normalizeVectors() {
    const flowLen = Math.max(
      Math.sqrt(this.flowDirX * this.flowDirX + this.flowDirY * this.flowDirY),
      0.0001
    );
    this.flowDirX /= flowLen;
    this.flowDirY /= flowLen;

    const stretchLen = Math.max(
      Math.sqrt(
        this.stretchDirX * this.stretchDirX +
          this.stretchDirY * this.stretchDirY
      ),
      0.0001
    );
    this.stretchDirX /= stretchLen;
    this.stretchDirY /= stretchLen;
  }
}

// Invariants for psych continuity and safety.
class PsychInvariants {
  constructor({ cic, aos, det, lsg }) {
    this.cic = clamp01(cic); // Coherence Integrity Coefficient
    this.aos = clamp01(aos); // Attention Orientation Score
    this.det = clamp01(det); // Detection reliability
    this.lsg = clamp01(lsg); // Latency Safety Guard
  }
}

// Exposure for a single frame of psych interaction traces.
class PsychExposure {
  constructor({
    cognitiveLoad = 0.0,   // abstract load (tasks, context switch)
    sensoryLoad = 0.0,     // visual/audio overload
    surprise = 0.0,        // startle / unexpected events
    integrationDrift = 0.0,// drift from preferred integration state
    timeSinceRestSec = 0.0,// time since rest/reset
    channelVelocity = 0.0  // speed of interaction / changes
  } = {}) {
    this.cognitiveLoad = clamp01(cognitiveLoad);
    this.sensoryLoad = clamp01(sensoryLoad);
    this.surprise = clamp01(surprise);
    this.integrationDrift = clamp01(integrationDrift);
    this.timeSinceRestSec = Math.max(0.0, timeSinceRestSec);
    this.channelVelocity = clamp01(channelVelocity);
  }
}

// ---------------------------------------------------------------------
// Psych gates (from invariants)
// ---------------------------------------------------------------------

function computeSystemHealthGate(inv) {
  const cic = clamp01(inv.cic);
  const det = clamp01(inv.det);
  const health = clamp01(0.5 * cic + 0.5 * det);
  return lerp(0.6, 1.0, health);
}

function computeLatencyGuard(inv) {
  const guard = clamp01(inv.lsg);
  return lerp(1.0, 0.7, guard);
}

// ---------------------------------------------------------------------
// Core integrator: psych footprint evolution
// ---------------------------------------------------------------------

function integratePsych(prev, exposure, inv, dt) {
  const t = Math.max(0.0, dt);

  // Rates derived from exposure
  const stressRate = clamp01(
    exposure.cognitiveLoad * 0.8 + exposure.surprise * 0.4
  );
  const overloadRate = clamp01(
    exposure.sensoryLoad * 0.9 + exposure.cognitiveLoad * 0.3
  );
  const fatigueRate = clamp01(
    exposure.integrationDrift * 0.7 +
      (exposure.timeSinceRestSec / 1800.0) * 0.2
  );

  const naturalRest = clamp01(t * 0.04);
  const naturalClarityRecovery = clamp01(t * 0.03);

  const next = new PsychParams(prev);

  // Stress integration
  const stressGrow = stressRate * t;
  const stressDecay = naturalRest * (1.0 - exposure.cognitiveLoad);
  next.stress = clamp01(prev.stress + stressGrow - stressDecay);

  // Overload integration
  const overloadGrow = overloadRate * t;
  const overloadDecay = clamp01(
    (exposure.channelVelocity * 0.3 + naturalRest * 0.2) * t
  );
  next.overload = clamp01(prev.overload + overloadGrow - overloadDecay);

  // Fatigue integration
  const fatigueGrow = fatigueRate * t;
  const fatigueDecay = clamp01(naturalRest * 0.15);
  next.fatigue = clamp01(prev.fatigue + fatigueGrow - fatigueDecay);

  // Clarity: higher clarity when overload and stress are controlled
  const clarityTarget = clamp01(
    0.6 -
      0.3 * next.stress -
      0.3 * next.overload +
      naturalClarityRecovery
  );
  next.clarity = clamp01(
    lerp(prev.clarity, clarityTarget, 0.3 * inv.cic)
  );

  // Integration depth and comfort as derived metrics
  next.integrationDepth = clamp01(
    0.5 +
      0.3 * (1.0 - exposure.integrationDrift) -
      0.2 * next.fatigue
  );
  next.comfort = clamp01(
    0.5 +
      0.3 * (1.0 - next.stress) -
      0.2 * next.overload
  );
  next.signalPorosity = clamp01(prev.signalPorosity);

  // Flow and stretch direction: represent psych trajectory orientation
  next.flowDirX = 0.0;
  next.flowDirY = -1.0; // grounded, downward drift toward rest
  next.stretchDirX =
    exposure.channelVelocity > 0.1 ? 1.0 : prev.stretchDirX;
  next.stretchDirY = 0.0;

  next._normalizeVectors();

  // Global gates
  const systemGate = computeSystemHealthGate(inv);
  const latencyGate = computeLatencyGuard(inv);
  const gate = systemGate * latencyGate;

  next.stress *= gate;
  next.overload *= gate;
  next.fatigue *= gate;
  next.integrationDepth *= gate;
  next.comfort *= gate;

  return next;
}

// ---------------------------------------------------------------------
// Persistence schema: psych frames and bindings
// ---------------------------------------------------------------------

const INIT_PSYCH_SCHEMA_SQL = `
PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE IF NOT EXISTS psych_frame (
    frame_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    frame_ts_ms     INTEGER NOT NULL,
    session_id      TEXT    NOT NULL,
    stakeholder_id  TEXT    NOT NULL,
    context_label   TEXT    NOT NULL,
    cic             REAL    NOT NULL CHECK (cic BETWEEN 0.0 AND 1.0),
    aos             REAL    NOT NULL CHECK (aos BETWEEN 0.0 AND 1.0),
    det             REAL    NOT NULL CHECK (det BETWEEN 0.0 AND 1.0),
    lsg             REAL    NOT NULL CHECK (lsg BETWEEN 0.0 AND 1.0)
);

CREATE INDEX IF NOT EXISTS idx_psych_frame_session_ts
    ON psych_frame (session_id, frame_ts_ms);
CREATE INDEX IF NOT EXISTS idx_psych_frame_stakeholder
    ON psych_frame (stakeholder_id, frame_ts_ms);

CREATE TABLE IF NOT EXISTS psych_binding (
    binding_id        INTEGER PRIMARY KEY AUTOINCREMENT,
    frame_id          INTEGER NOT NULL REFERENCES psych_frame(frame_id) ON DELETE CASCADE,
    binding_key       TEXT    NOT NULL,
    region            TEXT    NOT NULL,
    stress            REAL    NOT NULL CHECK (stress BETWEEN 0.0 AND 1.0),
    clarity           REAL    NOT NULL CHECK (clarity BETWEEN 0.0 AND 1.0),
    overload          REAL    NOT NULL CHECK (overload BETWEEN 0.0 AND 1.0),
    fatigue           REAL    NOT NULL CHECK (fatigue BETWEEN 0.0 AND 1.0),
    integration_depth REAL    NOT NULL CHECK (integration_depth BETWEEN 0.0 AND 1.0),
    comfort           REAL    NOT NULL CHECK (comfort BETWEEN 0.0 AND 1.0),
    signal_porosity   REAL    NOT NULL CHECK (signal_porosity BETWEEN 0.0 AND 1.0),
    flow_dir_x        REAL    NOT NULL CHECK (flow_dir_x BETWEEN -1.0 AND 1.0),
    flow_dir_y        REAL    NOT NULL CHECK (flow_dir_y BETWEEN -1.0 AND 1.0),
    stretch_dir_x     REAL    NOT NULL CHECK (stretch_dir_x BETWEEN -1.0 AND 1.0),
    stretch_dir_y     REAL    NOT NULL CHECK (stretch_dir_y BETWEEN -1.0 AND 1.0)
);

CREATE INDEX IF NOT EXISTS idx_psych_binding_frame_region
    ON psych_binding (frame_id, region);
CREATE INDEX IF NOT EXISTS idx_psych_binding_key
    ON psych_binding (binding_key);

CREATE VIEW IF NOT EXISTS v_recent_psych AS
SELECT 
    f.frame_id,
    f.frame_ts_ms,
    f.stakeholder_id,
    f.context_label,
    b.region,
    b.stress,
    b.clarity,
    b.overload,
    b.fatigue,
    b.integration_depth,
    b.comfort,
    f.lsg
FROM psych_frame f
JOIN psych_binding b ON f.frame_id = b.frame_id
ORDER BY f.frame_ts_ms DESC
LIMIT 1000;
`;

// ---------------------------------------------------------------------
// Frame and binding DTOs
// ---------------------------------------------------------------------

class PsychFrame {
  constructor({
    frameTsMs,
    sessionId,
    stakeholderId,
    contextLabel,
    cic,
    aos,
    det,
    lsg
  }) {
    this.frameTsMs = frameTsMs;
    this.sessionId = sessionId;
    this.stakeholderId = stakeholderId;
    this.contextLabel = contextLabel;
    this.cic = clamp01(cic);
    this.aos = clamp01(aos);
    this.det = clamp01(det);
    this.lsg = clamp01(lsg);
  }
}

class PsychBinding {
  constructor({
    frameId,
    bindingKey,
    region,
    params
  }) {
    this.frameId = frameId;
    this.bindingKey = bindingKey;
    this.region = region;
    this.params = params;
  }
}

// ---------------------------------------------------------------------
// Database helpers
// ---------------------------------------------------------------------

function initPsychSchema(db) {
  return new Promise((resolve, reject) => {
    db.exec(INIT_PSYCH_SCHEMA_SQL, (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

function insertPsychFrame(db, frame) {
  const sql = `
    INSERT INTO psych_frame (
      frame_ts_ms, session_id, stakeholder_id, context_label,
      cic, aos, det, lsg
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
  `;
  const params = [
    frame.frameTsMs,
    frame.sessionId,
    frame.stakeholderId,
    frame.contextLabel,
    frame.cic,
    frame.aos,
    frame.det,
    frame.lsg
  ];

  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve(this.lastID);
    });
  });
}

function insertPsychBinding(db, binding) {
  const p = binding.params;
  const sql = `
    INSERT INTO psych_binding (
      frame_id, binding_key, region,
      stress, clarity, overload, fatigue,
      integration_depth, comfort, signal_porosity,
      flow_dir_x, flow_dir_y,
      stretch_dir_x, stretch_dir_y
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
  `;
  const params = [
    binding.frameId,
    binding.bindingKey,
    binding.region,
    p.stress,
    p.clarity,
    p.overload,
    p.fatigue,
    p.integrationDepth,
    p.comfort,
    p.signalPorosity,
    p.flowDirX,
    p.flowDirY,
    p.stretchDirX,
    p.stretchDirY
  ];

  return new Promise((resolve, reject) => {
    db.run(sql, params, function (err) {
      if (err) reject(err);
      else resolve(this.lastID);
    });
  });
}

// ---------------------------------------------------------------------
// High-level engine API
// ---------------------------------------------------------------------

/**
 * Create a new SQLite-backed psych-footprint engine.
 * @param {string} path - Path to the SQLite database file, or ':memory:'.
 * @returns {Promise<{ db, initPsychSchema, integratePsych, insertPsychFrame, insertPsychBinding }>}
 */
function createPsychFootprintEngine(path = ":memory:") {
  const db = new sqlite3.Database(path);
  return initPsychSchema(db).then(() => ({
    db,
    initPsychSchema: () => initPsychSchema(db),
    integratePsych,
    insertPsychFrame: (frame) => insertPsychFrame(db, frame),
    insertPsychBinding: (binding) => insertPsychBinding(db, binding)
  }));
}

module.exports = {
  PsychParams,
  PsychInvariants,
  PsychExposure,
  PsychFrame,
  PsychBinding,
  integratePsych,
  initPsychSchema,
  insertPsychFrame,
  insertPsychBinding,
  createPsychFootprintEngine
};
