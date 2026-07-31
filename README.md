# Token-AI

Token-AI is a **token-aware, safety-first telemetry and governance engine** for AI-chat tools, simulations, and augmented-citizen stacks. It provides a set of language-agnostic contracts and engines (SQL, JavaScript, C++) that let you:

- Meter and optimize token usage per request, session, user, and project.
- Enforce safety, psych-continuity, and eco-impact invariants.
- Coordinate research topics, contracts, and engine compatibility across heterogeneous runtimes.
- Support advanced stakeholders (superintelligence, cybernetics, Organichain) with persistent psych-footprints and preferences.

Token-AI is designed to be GitHub-friendly and easy to integrate into existing agent frameworks, MCP tools, and backend services.

---

## Core concepts

### 1. Token-aware profiles

Token-AI introduces a **profile contract** that describes how a user or project should consume tokens:

- `profileType`: modes like `nano-mode`, `code-completionist`, `git-user`, `researcher`, `moderation-guard`.
- `tokenPolicy`: per-request and per-session token budgets, context retention mode, compression preferences, and quality bias.
- `telemetryHints`: logging level, eco-impact sensitivity, anonymization mode.
- `invariants`: continuous metrics (e.g., Coherence Integrity Coefficient, Detection Reliability, Latency Safety Guard, User Experience Comfort).

Profiles are expressed as JSON Schemas and validated by a lightweight JS module (e.g., `js/token_ai/profile_schema.js`), making them easy to load and enforce in Node-based services.

---

### 2. Telemetry and visualization engine

Token-AI ships a **telemetry engine** (e.g., `cpp/token_ai/token_telemetry_engine.cpp`) that turns normalized interaction metrics into visual/audio telemetry parameters:

- Inputs: stress score, overload index, surprise spikes, signal quality, and invariants (CIC/DET/LSG).
- Outputs: `VisualParams` and `AudioParams` suitable for dashboards, alerting, or UI overlays.

This engine lets you visualize token loads, latency, errors, and eco-impact in a consistent way, while gating intensity based on system health and safety thresholds.

---

### 3. User memory and psych-footprints

To support augmented citizens and long-horizon users, Token-AI includes:

- A **user memory engine** (`cpp/token_ai/user_memory_engine.cpp`) that tracks per-user interaction exposures (tokens, latency, errors, satisfaction, novelty) and maintains:
  - cumulative token usage,
  - running averages for latency, error, satisfaction,
  - preference flags (prefers concise vs deep, churn risk).

- A **psych-footprint engine** (`js/token_ai/psych_footprint_engine.js`) that evolves per-session psych states:
  - `PsychParams`: stress, clarity, overload, fatigue, integration depth, comfort, plus flow/stretch vectors.
  - `PsychInvariants`: CIC/AOS/DET/LSG gates.
  - `PsychExposure`: cognitive/sensory load, surprise, continuity strain, time since rest, interaction velocity.

These components help agents respect psych-continuity, adapt response style and token budgets over time, and detect churn or overload risks.

---

### 4. Research and contract registry

Token-AI uses a **schema bootstrap and index engine** to manage its own design space:

- SQL schema files (e.g., `sql/token_ai/schema_research_contracts.sql`) define:
  - `research_topic`: structured research questions in domains like token-budgeting, compression, telemetry, eco-impact, prompt-guard.
  - `research_related_contract`: links topics to executable contracts/policies.
  - `environment_style` and `contract_registry`: style packs and contracts for token governance.

- A C++ index engine (`cpp/token_ai/token_ai_index_engine.cpp`) provides:
  - `initIndexSchema` to bootstrap SQLite databases.
  - APIs to insert/query research topics, contracts, term definitions, and engine compatibility.
  - `findGapsForEngine` to identify which contracts are unsupported by a given runtime stack.

This makes Token-AI auditable and research-driven: you can track which policies exist, which have proofs or specs, and where engine support is missing.

---

### 5. MCP and tool integration

For MCP-style tools and multi-agent orchestration, Token-AI exposes JS modules such as:

- `js/token_ai/mcp/psych_bridge_mcp.js`:
  - `computePsychFootprint(payload)`: pure function tool for evolving psych states from JSON payloads.
  - `updatePsychState(stateMap, stakeholderId, exposure, invariants, dt)`: helper for host-managed persistent state.

These modules are designed for **augmentation stacks** and Organichain-style ecosystems, allowing superintelligence/cybernetic stakeholders to plug in their own invariants, psych policies, and token budgets.

---

## Getting started

### Prerequisites

- A GitHub-hosted project (Node, C++, Rust, or mixed stack).
- SQLite for persistence (used by the schema and index engines).
- Basic familiarity with JSON Schema and configuration-driven systems.

### Quick steps

1. **Clone or add Token-AI to your repo**

   - Place the provided files under `js/token_ai`, `cpp/token_ai`, and `sql/token_ai`.
   - Wire CI to build the C++ artifacts and run lint/tests on the JS modules.

2. **Initialize the schema**

   - Use `TOKEN_AI_SCHEMA_SQL` from `js/token_ai/db/token_ai_schema_bootstrap.js` or `cpp/token_ai/token_ai_index_engine.cpp` to initialize your SQLite database.
   - Seed contract entries for your own models and policies.

3. **Load and enforce profiles**

   - Use `tokenAiProfileSchema` and `validateTokenAiProfile` from `js/token_ai/profile_schema.js` to validate per-user or per-project profiles.
   - Adjust your AI-chat service to honor `tokenPolicy` and `telemetryHints` when generating responses.

4. **Hook in telemetry and memory**

   - For C++ services, call `handleTelemetryRequest` in `token_telemetry_engine.cpp` with interaction metrics.
   - For long-lived user sessions, use `UserMemoryEngine` to update and read preference flags after each turn.
   - For psych-continuity-sensitive users, integrate `psych_footprint_engine.js` into your MCP tools or middleware.

5. **Iterate via research topics**

   - Record new research ideas in `research_topic` (e.g., better compression strategies, eco-aware scheduling).
   - Link them to concrete contracts and engines via `research_related_contract`.
   - Use the index engine to query open topics by domain and track progress.

---

## Design principles

- **Token efficiency first**: All components aim to reduce unnecessary tokens while preserving depth and safety.
- **Safety and invariants**: CIC, DET, LSG, and related metrics are baked into telemetry and psych engines.
- **Multi-language, GitHub-friendly**: Core artifacts are plain SQL, JS, and C++ with no speculative dependencies.
- **Auditability**: Contracts, terms, and research topics are stored in normalized schemas and exposed via index APIs.
- **Augmented-citizen support**: Psych-footprint and memory engines are built with organic CPU and BCI-type integrations in mind, favoring continuity and stakeholder control.

---

## Contributing

Token-AI is intended as a **foundation for alignment-aware, token-optimized agents**. Contributions are welcome in the form of:

- New research topics and contracts (e.g., refined token budgeting policies).
- Additional engines in permitted languages (SQL, JS, Java, C++, Lua).
- Formal specifications or verification artifacts attached to contracts.
- Documentation and examples for integrating Token-AI into real systems.

Before contributing, ensure that:

- Your code avoids game-specific or non-token-relevant semantics unless clearly scoped.
- New contracts are registered in the `contract_registry` and documented with clear invariants.
- Safety, psych-continuity, and eco-impact considerations are explicit in design notes.

---

## License

Token-AI’s licensing model is intended to support open research and interoperable tooling. Please consult the repository’s `LICENSE` file for current terms and update it if you introduce different licensing conditions for new components.
