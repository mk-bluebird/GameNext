// js/token_ai/mcp/psych_bridge_mcp.js
// Token-AI Psych Bridge MCP Module
//
// Scrubbed and transformed from a game-specific "grime bridge" Bevy plugin
// into a Token-AI MCP-compatible module for augmented-citizen and
// superintelligence stacks.
//
// Purpose:
//   - Provide a pure-logic psych integration engine (no game/material context).
//   - Expose MCP-style tools for computing and updating psych footprints
//     based on invariants (CIC/AOS/DET/LSG) and exposure metrics.
//   - Make it easy for agents to plug into BCI-type or organic_cpu stacks
//     while preserving psych continuity and safety.

//
// Core math helpers
//

function clamp01(v) {
  if (v < 0.0) return 0.0;
  if (v > 1.0) return 1.0;
  return v;
}

function lerp(a, b, t) {
  return a + (b - a) * t;
}

//
// Core data types (scrubbed from grime → psych)
//

class PsychParams {
  /**
   * Normalized psych footprint parameters for a single stakeholder/region.
   * All scalars are clamped into [0,1]; flow/stretch are unit vectors.
   */
  constructor({
    stress = 0.0,
    load = 0.0,
    tension = 0.0,
    continuityRisk = 0.0,
    flowDirX = 0.0,
    flowDirY = -1.0,
    stretchDirX = 1.0,
    stretchDirY = 0.0
  } = {}) {
    this.stress = clamp01(stress);
    this.load = clamp01(load);
    this.tension = clamp01(tension);
    this.continuityRisk = clamp01(continuityRisk);
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

class PsychInvariants {
  /**
   * Invariant-style gates analogous to CIC/AOS/DET/LSG.
   * Used as system-health and latency dampers on psych intensity.
   */
  constructor({ cic = 1.0, aos = 1.0, det = 1.0, lsg = 0.0 } = {}) {
    this.cic = clamp01(cic);
    this.aos = clamp01(aos);
    this.det = clamp01(det);
    this.lsg = clamp01(lsg);
  }
}

class PsychExposure {
  /**
   * Aggregated exposure inputs per interaction frame.
   * All scalars are normalized into [0,1] or non-negative durations.
   */
  constructor({
    cognitiveLoad = 0.0,   // task complexity / mental switching
    affectiveLoad = 0.0,   // emotional load
    surprise = 0.0,        // unexpected events
    continuityStrain = 0.0,// strain on psych continuity (fragmentation)
    timeSinceResetSec = 0.0,
    interactionVelocity = 0.0 // how fast the context is changing
  } = {}) {
    this.cognitiveLoad = clamp01(cognitiveLoad);
    this.affectiveLoad = clamp01(affectiveLoad);
    this.surprise = clamp01(surprise);
    this.continuityStrain = clamp01(continuityStrain);
    this.timeSinceResetSec = Math.max(0.0, timeSinceResetSec);
    this.interactionVelocity = clamp01(interactionVelocity);
  }
}

//
// Gates
//

function computeSystemHealthGate(inv) {
  const cic = clamp01(inv.cic);
  const det = clamp01(inv.det);
  const health = clamp01(0.5 * cic + 0.5 * det);
  return lerp(0.6, 1.0, health);
}

function computeLatencyGuard(inv) {
  const guard = clamp01(inv.lsg);
  // High LSG → stronger safety → more damping.
  return lerp(1.0, 0.7, guard);
}

//
// Core integrator: psych footprint evolution (scrubbed integrate_grime)
//

function integratePsych(prevParams, exposure, invariants, dt) {
  const t = Math.max(0.0, dt);

  // Rates derived from exposure, in [0,1].
  const stressRate = clamp01(
    exposure.cognitiveLoad * 0.8 + exposure.surprise * 0.4
  );
  const loadRate = clamp01(
    exposure.affectiveLoad * 0.7 +
      exposure.cognitiveLoad * 0.5 +
      exposure.continuityStrain * 0.3
  );
  const tensionRate = clamp01(
    exposure.continuityStrain * 0.8 +
      exposure.interactionVelocity * 0.4
  );

  const naturalRest = clamp01(t * 0.05);
  const naturalReset = clamp01(t * 0.02);

  const next = new PsychParams(prevParams);

  // Stress integration
  const stressGrow = stressRate * t;
  const stressDecay = naturalRest * (1.0 - exposure.cognitiveLoad);
  next.stress = clamp01(prevParams.stress + stressGrow - stressDecay);

  // Load integration
  const loadGrow = loadRate * t;
  const loadDecay = clamp01(
    (exposure.interactionVelocity * 0.4 + naturalRest * 0.3) * t
  );
  next.load = clamp01(prevParams.load + loadGrow - loadDecay);

  // Tension integration
  const tensionGrow =
    tensionRate * t +
    clamp01(exposure.timeSinceResetSec / 600.0) * 0.1 * t;
  const tensionDecay = naturalReset * 0.25;
  next.tension = clamp01(prevParams.tension + tensionGrow - tensionDecay);

  // Continuity risk derived from tension and load.
  const continuityGrow = clamp01(
    next.tension * 0.6 + next.load * 0.4
  ) * t;
  const continuityDecay = naturalReset * 0.2;
  next.continuityRisk = clamp01(
    prevParams.continuityRisk + continuityGrow - continuityDecay
  );

  // Flow and stretch direction: represent psych trajectory orientation.
  next.flowDirX = 0.0;
  next.flowDirY = -1.0;
  next.stretchDirX =
    exposure.interactionVelocity > 0.1 ? 1.0 : prevParams.stretchDirX;
  next.stretchDirY = 0.0;
  next._normalizeVectors();

  // Global gates
  const systemGate = computeSystemHealthGate(invariants);
  const latencyGate = computeLatencyGuard(invariants);
  const gate = systemGate * latencyGate;

  next.stress *= gate;
  next.load *= gate;
  next.tension *= gate;
  next.continuityRisk *= gate;

  return next;
}

//
// MCP-style tool interface
//
// The following functions are shaped to be easy to expose as MCP tools:
//   - computePsychFootprint: pure function taking JSON-like params.
//   - updatePsychState: helper for host-managed persistent state.
//

/**
 * Compute a psych footprint for a single region/stakeholder.
 * Intended MCP tool signature: accepts a payload describing prev state,
 * exposure, invariants, and dt; returns the next PsychParams object.
 *
 * @param {object} payload
 * @param {object} payload.prev - previous psych params
 * @param {object} payload.exposure - psych exposure metrics
 * @param {object} payload.invariants - CIC/AOS/DET/LSG invariants
 * @param {number} payload.dt - time delta (seconds or normalized)
 * @returns {PsychParams}
 */
function computePsychFootprint(payload) {
  const prev = new PsychParams(payload.prev || {});
  const exposure = new PsychExposure(payload.exposure || {});
  const inv = new PsychInvariants(payload.invariants || {});
  const dt = typeof payload.dt === "number" ? payload.dt : 1.0;
  return integratePsych(prev, exposure, inv, dt);
}

/**
 * Stateful updater for host-managed maps of psych params.
 * This does not persist; hosts (augmented-citizen agents, Organichain
 * services, etc.) can store the returned state in their own memory.
 *
 * @param {Map<string, PsychParams>} stateMap - map keyed by stakeholder id.
 * @param {string} stakeholderId - unique stakeholder or region identifier.
 * @param {object} exposure - raw exposure object.
 * @param {object} invariants - raw invariants object.
 * @param {number} dt - time delta.
 * @returns {PsychParams} - updated state for this stakeholder.
 */
function updatePsychState(stateMap, stakeholderId, exposure, invariants, dt) {
  const prev = stateMap.get(stakeholderId) || new PsychParams();
  const exp = new PsychExposure(exposure || {});
  const inv = new PsychInvariants(invariants || {});
  const next = integratePsych(prev, exp, inv, dt);
  stateMap.set(stakeholderId, next);
  return next;
}

module.exports = {
  PsychParams,
  PsychInvariants,
  PsychExposure,
  computePsychFootprint,
  updatePsychState
};
