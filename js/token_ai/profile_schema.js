// js/token_ai/profile_schema.js
// Token-AI Profile Schema and Validator
//
// This module defines a JSON Schema for Token-AI-specific user/agent profiles,
// scrubbed of region- and BCI-specific details and refocused on token usage,
// safety posture, and interaction invariants. It also provides a lightweight
// validator to check profile objects against the schema without external deps.
//
// Intended usage:
//   - As a core contract for configuring per-user/per-project token behavior.
//   - As a portable spec that AI-chat tools and agents can load to tune
//     budgeting, safety, and UX heuristics.

const tokenAiProfileSchema = {
  type: "object",
  required: ["version", "profileType", "tokenPolicy", "telemetryHints", "invariants"],
  additionalProperties: false,
  properties: {
    version: { type: "string", const: "v1" },

    // High-level experience/profile type, aligned with Token-AI workflows.
    profileType: {
      type: "string",
      enum: [
        "nano-mode",          // extremely concise, low token budget
        "code-completionist", // extended contexts for coding workflows
        "git-user",           // repository-focused interactions
        "researcher",         // long-horizon, exploratory reasoning
        "moderation-guard"    // safety-enforcing agent profile
      ]
    },

    // Token policy hints describe how the system should budget and throttle tokens.
    tokenPolicy: {
      type: "object",
      required: [
        "maxTokensPerRequest",
        "maxTokensPerSession",
        "contextRetentionMode",
        "compressionPreference",
        "qualityBias"
      ],
      additionalProperties: false,
      properties: {
        maxTokensPerRequest: {
          type: "integer",
          minimum: 128,
          description: "Upper bound on tokens per single response."
        },
        maxTokensPerSession: {
          type: "integer",
          minimum: 512,
          description: "Soft cap on total tokens consumed in a session."
        },
        contextRetentionMode: {
          type: "string",
          enum: [
            "minimal",   // keep only the last turn
            "windowed",  // keep last N turns
            "full-hint"  // keep summary plus recent turns
          ]
        },
        compressionPreference: {
          type: "string",
          enum: [
            "lossless-summary",  // precise but concise summarization
            "semantic-merge",    // merge similar turns, drop redundancy
            "none"               // no automatic compression
          ]
        },
        qualityBias: {
          type: "string",
          enum: [
            "speed",     // prioritize latency and low token usage
            "balanced",  // trade off quality and efficiency
            "depth"      // prioritize depth even at higher token cost
          ]
        }
      }
    },

    // Telemetry hints describe how much logging and eco-impact tracking to apply.
    telemetryHints: {
      type: "object",
      required: ["loggingLevel", "ecoImpactSensitivity", "anonymizationMode"],
      additionalProperties: false,
      properties: {
        loggingLevel: {
          type: "string",
          enum: [
            "none",
            "errors-only",
            "summary",
            "full"
          ]
        },
        ecoImpactSensitivity: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "Relative weight of eco-impact in token decisions."
        },
        anonymizationMode: {
          type: "string",
          enum: [
            "pseudonymous", // opaque IDs, no raw PII
            "aggregated",   // only aggregate metrics
            "strict"        // strongest anonymization, minimal linkage
          ]
        }
      }
    },

    // Invariants describe continuous metrics that Token-AI tries to keep within
    // safe and efficient ranges for a given profile.
    invariants: {
      type: "object",
      required: ["CIC", "DET", "LSG"],
      additionalProperties: false,
      properties: {
        // Constancy of interaction coherence: how consistently prompts and
        // responses stay aligned with the intended task.
        CIC: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "Coherence Integrity Coefficient"
        },

        // Detection reliability for unsafe or wasteful interactions.
        DET: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "Detection Reliability"
        },

        // Latency and safety guard: higher values imply stricter controls
        // on response time and safety checks.
        LSG: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "Latency Safety Guard"
        },

        // User experience comfort, representing how well token limits and
        // summarization preserve usability.
        UEC: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "User Experience Comfort"
        },

        // Churn/dropout likelihood under current token and safety policies.
        CDL: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "Churn/Dropout Likelihood"
        },

        // Attention retention rate, capturing how well the system maintains
        // user focus despite compression and throttling.
        ARR: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description: "Attention Retention Rate"
        }
      }
    }
  }
};

/**
 * Lightweight schema validator for Token-AI profiles.
 * This does not implement full JSON Schema; it enforces the core structure
 * and bounds needed by Token-AI without external libraries.
 *
 * @param {object} profile - The profile object to validate.
 * @returns {{ valid: boolean, errors: string[] }}
 */
function validateTokenAiProfile(profile) {
  const errors = [];

  if (typeof profile !== "object" || profile === null || Array.isArray(profile)) {
    return { valid: false, errors: ["Profile must be a non-null object."] };
  }

  // Required top-level fields.
  const topRequired = tokenAiProfileSchema.required;
  for (const field of topRequired) {
    if (!(field in profile)) {
      errors.push(`Missing required field: ${field}`);
    }
  }

  // Version check.
  if ("version" in profile && profile.version !== "v1") {
    errors.push(`Invalid version: ${profile.version}, expected "v1".`);
  }

  // profileType enum.
  if ("profileType" in profile) {
    const allowed = tokenAiProfileSchema.properties.profileType.enum;
    if (!allowed.includes(profile.profileType)) {
      errors.push(`Invalid profileType: ${profile.profileType}`);
    }
  }

  // tokenPolicy object checks.
  if ("tokenPolicy" in profile && typeof profile.tokenPolicy === "object") {
    const tp = profile.tokenPolicy;
    const tpProps = tokenAiProfileSchema.properties.tokenPolicy.properties;
    const tpReq = tokenAiProfileSchema.properties.tokenPolicy.required;

    for (const field of tpReq) {
      if (!(field in tp)) {
        errors.push(`tokenPolicy missing required field: ${field}`);
      }
    }

    if ("maxTokensPerRequest" in tp) {
      if (!Number.isInteger(tp.maxTokensPerRequest) || tp.maxTokensPerRequest < 128) {
        errors.push("maxTokensPerRequest must be an integer >= 128.");
      }
    }

    if ("maxTokensPerSession" in tp) {
      if (!Number.isInteger(tp.maxTokensPerSession) || tp.maxTokensPerSession < 512) {
        errors.push("maxTokensPerSession must be an integer >= 512.");
      }
    }

    if ("contextRetentionMode" in tp) {
      const allowed = tpProps.contextRetentionMode.enum;
      if (!allowed.includes(tp.contextRetentionMode)) {
        errors.push(`Invalid contextRetentionMode: ${tp.contextRetentionMode}`);
      }
    }

    if ("compressionPreference" in tp) {
      const allowed = tpProps.compressionPreference.enum;
      if (!allowed.includes(tp.compressionPreference)) {
        errors.push(`Invalid compressionPreference: ${tp.compressionPreference}`);
      }
    }

    if ("qualityBias" in tp) {
      const allowed = tpProps.qualityBias.enum;
      if (!allowed.includes(tp.qualityBias)) {
        errors.push(`Invalid qualityBias: ${tp.qualityBias}`);
      }
    }
  } else {
    errors.push("tokenPolicy must be an object.");
  }

  // telemetryHints checks.
  if ("telemetryHints" in profile && typeof profile.telemetryHints === "object") {
    const th = profile.telemetryHints;
    const thProps = tokenAiProfileSchema.properties.telemetryHints.properties;
    const thReq = tokenAiProfileSchema.properties.telemetryHints.required;

    for (const field of thReq) {
      if (!(field in th)) {
        errors.push(`telemetryHints missing required field: ${field}`);
      }
    }

    if ("loggingLevel" in th) {
      const allowed = thProps.loggingLevel.enum;
      if (!allowed.includes(th.loggingLevel)) {
        errors.push(`Invalid loggingLevel: ${th.loggingLevel}`);
      }
    }

    if ("ecoImpactSensitivity" in th) {
      if (typeof th.ecoImpactSensitivity !== "number" ||
          th.ecoImpactSensitivity < 0.0 ||
          th.ecoImpactSensitivity > 1.0) {
        errors.push("ecoImpactSensitivity must be a number between 0.0 and 1.0.");
      }
    }

    if ("anonymizationMode" in th) {
      const allowed = thProps.anonymizationMode.enum;
      if (!allowed.includes(th.anonymizationMode)) {
        errors.push(`Invalid anonymizationMode: ${th.anonymizationMode}`);
      }
    }
  } else {
    errors.push("telemetryHints must be an object.");
  }

  // invariants checks.
  if ("invariants" in profile && typeof profile.invariants === "object") {
    const inv = profile.invariants;
    const invProps = tokenAiProfileSchema.properties.invariants.properties;
    const invReq = tokenAiProfileSchema.properties.invariants.required;

    for (const field of invReq) {
      if (!(field in inv)) {
        errors.push(`invariants missing required field: ${field}`);
      }
    }

    for (const key of Object.keys(invProps)) {
      if (key in inv) {
        const value = inv[key];
        if (typeof value !== "number" || value < 0.0 || value > 1.0) {
          errors.push(`${key} must be a number between 0.0 and 1.0.`);
        }
      }
    }
  } else {
    errors.push("invariants must be an object.");
  }

  return { valid: errors.length === 0, errors };
}

module.exports = {
  tokenAiProfileSchema,
  validateTokenAiProfile
};
