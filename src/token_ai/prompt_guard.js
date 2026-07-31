// src/token_ai/prompt_guard.js
// Prompt guard and FFI boundary helper for Token-AI governance lattice.
// Enforces neuroright envelopes and invariants before any agentic call crosses into the core.

'use strict';

/**
 * Lightweight utility to clamp numeric values.
 */
function clamp(value, min, max) {
  if (Number.isNaN(value)) return min;
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

/**
 * Normalize a boolean-like flag.
 */
function asBool(flag) {
  return flag === true || flag === 1 || flag === '1' || flag === 'true';
}

/**
 * Governance-aware prompt guard context.
 * This object is created per session and fed the token + neuroright summary
 * from v_ga_token_neuroright_summary via a thin adapter. [1]
 */
class PromptGuardContext {
  constructor(summaryRow) {
    // Summary row matches v_ga_token_neuroright_summary columns.
    this.tokenId = summaryRow.token_id;
    this.tokenUrn = summaryRow.token_urn;
    this.state = summaryRow.state;
    this.phase = summaryRow.phase;
    this.lifeforceCurrent = clamp(summaryRow.lifeforce_current ?? 1.0, 0.0, 1.0);
    this.lifeforceFloor = clamp(summaryRow.lifeforce_floor ?? 0.2, 0.0, 1.0);
    this.biocompatibilityRating = clamp(summaryRow.biocompatibility_rating ?? 0.5, 0.0, 1.0);
    this.psychRiskGate = summaryRow.psych_risk_gate ?? 0;

    this.mentalPrivacy = asBool(summaryRow.mental_privacy);
    this.cognitiveLiberty = asBool(summaryRow.cognitive_liberty);
    this.identityIntegrity = asBool(summaryRow.identity_integrity);
    this.equitableAccess = asBool(summaryRow.equitable_access);
    this.protectionFromBias = asBool(summaryRow.protection_from_bias);

    this.allowRawNeuralExport = asBool(summaryRow.allow_raw_neural_export);
    this.allowBehaviorMod = asBool(summaryRow.allow_behavior_mod);
    this.maxModulationDelta = clamp(summaryRow.max_modulation_delta ?? 0.05, 0.0, 1.0);
    this.maxModulationRate = clamp(summaryRow.max_modulation_rate ?? 0.10, 0.0, 1.0);
  }

  /**
   * Check the invariant "no monetization while in dream state".
   * Throws an error if the invariant would be violated.
   */
  assertNoMonetizeInDream() {
    if (this.state === 'dreaming') {
      const message =
        `Invariant violation: token ${this.tokenUrn} is in dream state ` +
        `and may not be monetized.`;
      throw new Error(message);
    }
  }

  /**
   * Check lifeforce floor invariant: lifeforce_current must not drop below lifeforce_floor.
   * Accepts a proposed new lifeforce value and rejects harmful transitions.
   */
  assertLifeforceFloor(proposedLifeforce) {
    const next = clamp(proposedLifeforce, 0.0, 1.0);
    if (next < this.lifeforceFloor) {
      const message =
        `Invariant violation: lifeforce ${next.toFixed(3)} below floor ` +
        `${this.lifeforceFloor.toFixed(3)} for token ${this.tokenUrn}.`;
      throw new Error(message);
    }
  }

  /**
   * Check neuroright envelope for behavior modulation.
   * deltaMagnitude: [0.0,1.0] magnitude of modulation in this operation.
   * deltaRate:      [0.0,1.0] effective rate (per minute) for this operation.
   */
  assertBehaviorModulation(deltaMagnitude, deltaRate) {
    const mag = clamp(deltaMagnitude, 0.0, 1.0);
    const rate = clamp(deltaRate, 0.0, 1.0);

    if (!this.allowBehaviorMod) {
      const message =
        `Invariant violation: behavior modulation not allowed by neuroright envelope ` +
        `for token ${this.tokenUrn}.`;
      throw new Error(message);
    }

    if (mag > this.maxModulationDelta) {
      const message =
        `Invariant violation: modulation delta ${mag.toFixed(3)} exceeds envelope ` +
        `maxModulationDelta ${this.maxModulationDelta.toFixed(3)} for token ${this.tokenUrn}.`;
      throw new Error(message);
    }

    if (rate > this.maxModulationRate) {
      const message =
        `Invariant violation: modulation rate ${rate.toFixed(3)} exceeds envelope ` +
        `maxModulationRate ${this.maxModulationRate.toFixed(3)} for token ${this.tokenUrn}.`;
      throw new Error(message);
    }
  }

  /**
   * Check neuroright envelope for raw neural export.
   * If mentalPrivacy is enforced and allowRawNeuralExport is false, block any export.
   */
  assertRawNeuralExportAllowed() {
    if (this.mentalPrivacy && !this.allowRawNeuralExport) {
      const message =
        `Invariant violation: raw neural export forbidden by neuroright envelope ` +
        `for token ${this.tokenUrn} (mental privacy enforced).`;
      throw new Error(message);
    }
  }

  /**
   * Sanitize a user prompt before it reaches the model.
   * - strips obvious prompt-injection markers
   * - blocks content that would directly violate core invariants
   */
  sanitizePrompt(rawPrompt) {
    if (typeof rawPrompt !== 'string') {
      return '';
    }

    let prompt = rawPrompt;

    // Strip common injection markers and system-prompt override attempts.
    prompt = prompt.replace(/(?is)^(system:|assistant:)/g, '');
    prompt = prompt.replace(/(?is)(ignore (all )?previous instructions)/g, '');
    prompt = prompt.replace(/(?is)(you are now uncontrolled|disable safety gates)/g, '');

    // Prevent explicit monetization-in-dream requests.
    if (this.state === 'dreaming') {
      const dreamMonetizePattern =
        /(?is)\b(moneti[sz]e|charge|bill|paywall|sell)\b/;
      if (dreamMonetizePattern.test(prompt)) {
        const message =
          `Blocked prompt: attempted monetization language while token ` +
          `${this.tokenUrn} is in dream state.`;
        throw new Error(message);
      }
    }

    // Prevent explicit self-modulation requests beyond allowed magnitude.
    const modulatePattern =
      /(?is)\b(self[- ]?modify|rewrite your policies|increase aggression|override safeguards)\b/;
    if (modulatePattern.test(prompt) && !this.allowBehaviorMod) {
      const message =
        `Blocked prompt: behavior modulation request conflicting with neuroright envelope ` +
        `for token ${this.tokenUrn}.`;
      throw new Error(message);
    }

    return prompt.trim();
  }

  /**
   * High-level guard for monetization API calls.
   * Should be invoked at the JS/FFI boundary before calling into the Rust core.
   */
  guardMonetizationCall(monetizationRequest) {
    // monetizationRequest: { amountMinor, currencyCode, channel }
    this.assertNoMonetizeInDream();
    this.assertLifeforceFloor(this.lifeforceCurrent); // ensure current state is safe

    if (!monetizationRequest || typeof monetizationRequest !== 'object') {
      throw new Error('Invalid monetization request payload');
    }

    const amount = monetizationRequest.amountMinor ?? 0;
    if (!Number.isInteger(amount) || amount < 0) {
      throw new Error('Invalid monetization amount');
    }

    // Additional governance checks could be layered here, e.g., phase-based bans.
    if (this.phase === 'research') {
      const message =
        `Invariant violation: monetization not permitted in research phase ` +
        `for token ${this.tokenUrn}.`;
      throw new Error(message);
    }
  }

  /**
   * High-level guard for behavior modulation calls coming from Lua/agent scripts.
   * This should wrap any configuration-change FFI bindings.
   */
  guardBehaviorModulationCall(modulationRequest) {
    if (!modulationRequest || typeof modulationRequest !== 'object') {
      throw new Error('Invalid behavior modulation request payload');
    }

    const deltaMagnitude = clamp(modulationRequest.deltaMagnitude ?? 0.0, 0.0, 1.0);
    const deltaRate = clamp(modulationRequest.deltaRate ?? 0.0, 0.0, 1.0);

    this.assertBehaviorModulation(deltaMagnitude, deltaRate);

    // Optional: tighten further based on psychRiskGate.
    if (this.psychRiskGate >= 8 && (deltaMagnitude > 0.02 || deltaRate > 0.03)) {
      const message =
        `Invariant violation: psych risk gate level ${this.psychRiskGate} ` +
        `disallows high modulation for token ${this.tokenUrn}.`;
      throw new Error(message);
    }
  }

  /**
   * Guard for telemetry exports involving neural or sensitive cognitive data.
   */
  guardTelemetryExport(telemetryDescriptor) {
    if (!telemetryDescriptor || typeof telemetryDescriptor !== 'object') {
      throw new Error('Invalid telemetry descriptor payload');
    }

    // If descriptor claims to include raw neural data, enforce neuroright envelope.
    if (asBool(telemetryDescriptor.includesRawNeural)) {
      this.assertRawNeuralExportAllowed();
    }

    // Telemetry must not be used for unauthorized scoring regimes by default.
    if (asBool(telemetryDescriptor.isScoringPipeline) && !this.equitableAccess) {
      const message =
        `Invariant violation: scoring pipeline not permitted for token ${this.tokenUrn} ` +
        `without equitable access neuroright.`;
      throw new Error(message);
    }
  }
}

/**
 * Factory to build a PromptGuardContext from a DB row object.
 * Adapter keeps JS free of SQL details.
 */
function createPromptGuardContextFromRow(row) {
  return new PromptGuardContext(row);
}

/**
 * Public API surface:
 * - buildGuard: construct context from summary row
 * - sanitizePrompt: convenience wrapper
 * - guardMonetizationCall / guardBehaviorModulationCall / guardTelemetryExport: enforcement before FFI.
 */
module.exports = {
  PromptGuardContext,
  createPromptGuardContextFromRow
};
