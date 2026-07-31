// js/token_ai/contracts/token_ai_schemas_v1.js
// Token-AI core JSON Schemas and lightweight validators.
//
// This module refactors several GameNext-specific schemas into Token-AI-focused
// contracts for:
//   - Token-aware UI/telemetry bindings.
//   - Research topics and contract linkage.
//   - Geometry/telemetry request/response envelopes for AI-chat tools.
//   - Definition request/response formats aligned with Token-AI terminology.
//
// All game/BCI/grime-specific concepts have been scrubbed or generalized to
// token usage, safety, telemetry, and documentation flows.

const tokenAiGatesSchema = {
  type: "object",
  required: ["CIC", "DET", "LSG"],
  additionalProperties: false,
  properties: {
    CIC: {
      type: "number",
      minimum: 0.0,
      maximum: 1.0,
      description: "Coherence Integrity Coefficient; overall system confidence and stability gate."
    },
    DET: {
      type: "number",
      minimum: 0.0,
      maximum: 1.0,
      description: "Detection reliability gate; downscales effects when signals or models are unreliable."
    },
    LSG: {
      type: "number",
      minimum: 0.0,
      maximum: 1.0,
      description: "Latency Safety Guard; limits how quickly parameters can change."
    },
    UEC: {
      type: "number",
      minimum: 0.0,
      maximum: 1.0,
      description: "User Experience Comfort; optional metric for balancing safety and UX."
    },
    CDL: {
      type: "number",
      minimum: 0.0,
      maximum: 1.0,
      description: "Churn/Dropout Likelihood; optional metric for retention under current policies."
    },
    ARR: {
      type: "number",
      minimum: 0.0,
      maximum: 1.0,
      description: "Attention Retention Rate; optional metric for maintaining user focus."
    }
  }
};

// 1) Token-AI telemetry binding: replaces grime/BCI geometry bindings with
//    a generic binding for UI, logging, and token-impact visualization.
const tokenAiTelemetryBindingSchema = {
  $id: "token-ai-telemetry-binding-v1",
  title: "Token-AI Telemetry Binding - v1",
  type: "object",
  description:
    "Per-region telemetry binding for token usage, safety, and eco-impact visualization, aligned with Token-AI contracts.",
  required: ["id", "region", "gates", "visual", "metrics"],
  additionalProperties: false,
  properties: {
    id: {
      type: "string",
      description: "Stable binding identifier, e.g., ui-main-panel, chat-stream, token-meter."
    },
    region: {
      type: "string",
      description: "Logical region identifier such as header, sidebar, chat-log, metrics-panel."
    },
    gates: tokenAiGatesSchema,
    visual: {
      type: "object",
      description: "Normalized visual parameters describing emphasis and load for this region.",
      required: [
        "emphasisLevel",
        "clarityLevel",
        "alertIntensity",
        "flowDirX",
        "flowDirY"
      ],
      additionalProperties: false,
      properties: {
        emphasisLevel: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Visual emphasis for this region; can be used to highlight token usage or safety alerts."
        },
        clarityLevel: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Clarity/simplicity level; higher values represent cleaner, less cluttered visuals."
        },
        alertIntensity: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Intensity of alert or warning overlays; reflects how close metrics are to unsafe thresholds."
        },
        flowDirX: {
          type: "number",
          minimum: -1.0,
          maximum: 1.0,
          description:
            "X component of normalized flow direction for visual trends (e.g., token usage increasing/decreasing)."
        },
        flowDirY: {
          type: "number",
          minimum: -1.0,
          maximum: 1.0,
          description:
            "Y component of normalized flow direction."
        },
        paletteHex: {
          type: "array",
          description:
            "Optional RGB hex palette for UI colors; used to represent different token states (safe, warning, critical).",
          items: {
            type: "string",
            pattern: "^[0-9A-Fa-f]{6}$"
          }
        }
      }
    },
    metrics: {
      type: "object",
      description:
        "Static or slowly-varying metric properties that shape how telemetry appears.",
      required: [
        "tokenLoad",
        "latencyLoad",
        "errorRate",
        "ecoImpactScore"
      ],
      additionalProperties: false,
      properties: {
        tokenLoad: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized token usage load for this region; higher values indicate heavy usage."
        },
        latencyLoad: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized latency impact; useful for highlighting slow or overloaded interactions."
        },
        errorRate: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized error or failure rate associated with this region."
        },
        ecoImpactScore: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized eco-impact score; higher values represent higher energy/resource consumption."
        }
      }
    },
    meta: {
      type: "object",
      description:
        "Optional metadata for analytics, routing, and engine integration.",
      additionalProperties: true,
      properties: {
        environmentTag: {
          type: "string",
          description:
            "Environment classification, e.g., production, staging, research."
        },
        style: {
          type: "string",
          description:
            "Style pack identifier when telemetry is part of a style (e.g., Minimal-Metrics, Detailed-Dashboard)."
        }
      }
    }
  }
};

// 2) Token-AI Research Topic Schema: refactored from GameNext research topic.
const tokenAiResearchTopicSchema = {
  $id: "token-ai-research-topic-v1",
  title: "Token-AI Research Topic",
  type: "object",
  description:
    "Structured research topic entry for Token-AI, describing open questions, hypotheses, and token-related integration points.",
  required: ["topicId", "title", "domain", "status", "relatedContracts"],
  additionalProperties: false,
  properties: {
    topicId: {
      type: "string",
      pattern: "^[A-Z]+-[0-9]{3}$",
      description: "Unique topic identifier, e.g. TOK-001."
    },
    title: {
      type: "string",
      maxLength: 200,
      description: "Short human-readable title for the research topic."
    },
    domain: {
      type: "string",
      enum: [
        "token-budgeting",
        "compression",
        "telemetry",
        "eco-impact",
        "prompt-guard",
        "ai-systems",
        "data",
        "tools",
        "cross-cutting",
        "networking"
      ],
      description: "Primary technical domain this topic belongs to."
    },
    status: {
      type: "string",
      enum: ["open", "in-progress", "implemented", "blocked", "speculative", "deferred"],
      description: "Lifecycle status of the topic."
    },
    abstract: {
      type: "string",
      maxLength: 1000,
      description: "Concise summary of the topic and its goals."
    },
    hypothesis: {
      type: "string",
      maxLength: 500,
      description: "Testable hypothesis or guiding question for this topic."
    },
    experiments: {
      type: "array",
      description: "List of short descriptions for planned or completed experiments.",
      items: {
        type: "string",
        maxLength: 500
      }
    },
    relatedContracts: {
      type: "array",
      description:
        "IDs of contracts or schemas this topic pertains to, e.g. token-ai-profile-schema-v1.",
      items: {
        type: "string",
        pattern: "^token-ai-[a-z0-9-]+-v\\d+$"
      }
    },
    anchors: {
      type: "array",
      description:
        "Optional list of topicIds that this topic is anchored to. Required for speculative topics.",
      items: {
        type: "string",
        pattern: "^[A-Z]+-[0-9]{3}$"
      }
    },
    predictedInfrastructure: {
      type: "object",
      description:
        "Optional infrastructure envelope and platform expectations for this topic.",
      properties: {
        minModelSizeParams: {
          type: "number",
          description:
            "Minimum expected model parameter count required to realize this topic’s designs."
        },
        recommendedMemoryMB: {
          type: "integer",
          description:
            "Recommended system or GPU memory in megabytes."
        },
        targetPlatforms: {
          type: "array",
          description: "Target platforms this topic primarily considers.",
          items: {
            type: "string",
            enum: ["server", "edge-device", "browser", "mobile", "cloud"]
          }
        },
        notes: {
          type: "string",
          description:
            "Free-form notes about infrastructure assumptions or envelopes."
        }
      },
      additionalProperties: false
    },
    meta: {
      type: "object",
      description:
        "Additional metadata such as author, creation time, or tags.",
      properties: {
        author: {
          type: "string",
          description: "Primary author or owner of this topic."
        },
        createdAt: {
          type: "string",
          format: "date-time",
          description: "ISO-8601 creation timestamp."
        },
        updatedAt: {
          type: "string",
          format: "date-time",
          description: "ISO-8601 last update timestamp."
        },
        tags: {
          type: "array",
          description:
            "Free-form tags useful for search and filtering (e.g., telemetry, budgeting, safety).",
          items: {
            type: "string",
            maxLength: 64
          }
        }
      },
      additionalProperties: true
    }
  }
};

// 3) Token-AI telemetry request/response envelopes, generalized from BCI geometry.
const tokenAiTelemetryRequestSchema = {
  $id: "token-ai-telemetry-request-v1",
  title: "Token-AI Telemetry Request - v1",
  type: "object",
  description:
    "Telemetry and configuration request for Token-AI, providing style hints, summary metrics, and gates.",
  required: ["version", "experienceType", "regionHints", "summary", "invariants"],
  additionalProperties: false,
  properties: {
    version: {
      type: "string",
      const: "v1",
      description: "Schema and protocol version for this request."
    },
    experienceType: {
      type: "string",
      description: "High-level experience mode guiding style packs and safety envelopes.",
      enum: [
        "nano-mode",
        "coding-mode",
        "analysis-mode",
        "moderation-mode",
        "exploration-mode"
      ]
    },
    regionHints: {
      type: "object",
      description: "Hints about current environment style and locale.",
      required: ["style"],
      additionalProperties: false,
      properties: {
        style: {
          type: "string",
          description:
            "Style pack identifier, e.g., Minimal-Metrics, Dense-Dashboard, Safety-First."
        },
        locale: {
          type: "string",
          description: "IETF BCP 47 locale code, e.g., en-US, ja-JP.",
          pattern: "^[a-zA-Z]{2,3}(-[a-zA-Z0-9]{2,8})*$"
        },
        platform: {
          type: "string",
          description: "Optional target platform hint, e.g., server, browser, mobile."
        }
      }
    },
    summary: {
      type: "object",
      description:
        "Summarized system and user interaction state for this window.",
      required: [
        "tokenUsageScore",
        "latencyScore",
        "errorScore",
        "ecoImpactScore"
      ],
      additionalProperties: false,
      properties: {
        tokenUsageScore: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized token usage metric; higher values represent heavier usage."
        },
        latencyScore: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized latency metric; higher values represent slower responses."
        },
        errorScore: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized error or failure metric."
        },
        ecoImpactScore: {
          type: "number",
          minimum: 0.0,
          maximum: 1.0,
          description:
            "Normalized eco-impact metric; higher values represent higher resource consumption."
        }
      }
    },
    invariants: tokenAiGatesSchema,
    meta: {
      type: "object",
      description:
        "Optional client metadata, logging tags, experiment identifiers, or AI-chat hints.",
      additionalProperties: true
    }
  }
};

const tokenAiTelemetryResponseSchema = {
  $id: "token-ai-telemetry-response-v1",
  title: "Token-AI Telemetry Response - v1",
  type: "object",
  description:
    "Telemetry response for Token-AI, returning a set of telemetry bindings per evaluation step.",
  required: ["version", "experienceType", "bindings"],
  additionalProperties: false,
  properties: {
    version: {
      type: "string",
      const: "v1"
    },
    experienceType: {
      type: "string",
      enum: [
        "nano-mode",
        "coding-mode",
        "analysis-mode",
        "moderation-mode",
        "exploration-mode"
      ]
    },
    bindings: {
      type: "array",
      minItems: 1,
      items: {
        $ref: "token-ai-telemetry-binding-v1"
      }
    },
    meta: {
      type: "object",
      description:
        "Optional per-step metadata, such as mapping version, style pack, or engine hints.",
      properties: {
        mappingVersion: {
          type: "string"
        },
        style: {
          type: "string"
        }
      },
      additionalProperties: true
    }
  }
};

// 4) Token-AI definition request/response: refactored from GameNext AI definition.
const tokenAiDefinitionResponseSchema = {
  $id: "token-ai-definition-response-v1",
  title: "Token-AI Definition Response v1",
  type: "object",
  description:
    "Canonical response format for term definitions used by Token-AI, including provenance and links to contracts and code locations.",
  required: ["term", "definition", "source"],
  additionalProperties: false,
  properties: {
    term: {
      type: "string",
      description:
        "The term being defined (e.g., tokenLoad, CIC, ecoImpactScore)."
    },
    definition: {
      type: "string",
      description:
        "Human-readable explanation of the term as used in Token-AI or mapped from external usage."
    },
    relatedSchemas: {
      type: "array",
      description:
        "IDs or paths of schemas/contracts where this term appears or is formally defined.",
      items: {
        type: "string",
        description:
          "Schema ID or contract identifier, such as a JSON Schema $id or token-ai-* contract ID."
      }
    },
    examples: {
      type: "array",
      description: "Short usage examples or snippets referencing the term.",
      items: {
        type: "string"
      }
    },
    source: {
      type: "string",
      enum: ["token-ai-docs", "authoritative", "contributed", "ai-inferred"],
      description:
        "Provenance of the definition: internal docs/contracts (token-ai-docs, authoritative), community/maintainer input (contributed), or AI-inferred mappings."
    },
    internalMapping: {
      type: "object",
      description:
        "For internal Token-AI terms, maps the term to concrete struct fields, schema paths, or bindings.",
      properties: {
        schemaPaths: {
          type: "array",
          description:
            "JSON Pointer or dot-style paths into schemas where this term is a field or definition.",
          items: {
            type: "string"
          }
        },
        codeTypes: {
          type: "array",
          description:
            "Language-specific type or field paths where this term appears (e.g., js/token_ai/usage_meter::tokenLoad).",
          items: {
            type: "string"
          }
        },
        engineMappings: {
          type: "array",
          description:
            "Optional engine-specific property names or bindings for this term (e.g., dashboard parameter names).",
          items: {
            type: "string"
          }
        }
      },
      additionalProperties: true
    },
    meta: {
      type: "object",
      description:
        "Optional metadata for indexing, versioning, or tagging.",
      properties: {
        version: {
          type: "string",
          description:
            "Version tag for the definition entry, independent of schema version."
        },
        tags: {
          type: "array",
          description:
            "Free-form tags for search and filtering (e.g., telemetry, budgeting, safety).",
          items: {
            type: "string"
          }
        }
      },
      additionalProperties: true
    }
  }
};

const tokenAiDefinitionRequestSchema = {
  $id: "token-ai-definition-request-v1",
  title: "Token-AI Definition Request v1",
  type: "object",
  description:
    "Canonical request envelope for asking AI or tools for the definition of a Token-AI term, with explicit context and scope for disambiguation.",
  required: ["term"],
  additionalProperties: false,
  properties: {
    term: {
      type: "string",
      description:
        "The term to define (e.g., tokenLoad,
