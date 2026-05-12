# Campaign as Data v1

## Purpose

Define a data-driven model for campaigns in a Blood Money 2–style game.

Goals:

- Treat the campaign as a **first-class data object**, not hard-coded flow.
- Support both **story-driven play** and **replayable / Contracts-style loops** using the same structures.
- Enable **randomized elements and procedural expansion** while preserving hand-authored Hitman-level quality.
- Make all state **queryable via SQLite** and accessible to AI/chat tools and CI pipelines.

This document builds on:
- docs/sql/briefing_profile-v1.sql
- docs/ui/mission-briefing-v1.md
- docs/policy/action-tag-abstractions-v1.md

---

## Core Concept

A campaign is a structured record that binds together:

- **Who the player is** in this run (funds, notoriety, progression, preferences).
- **Which locations** are available and how they can vary (templates + randomization).
- **How missions are sequenced** (linear story, semi-linear, or free-order contracts).
- **How consequences persist** across missions (money, notoriety, suit heat, equipment loss).

Everything is represented as tables and rows in SQLite, not hard-coded logic. Tools, AI agents, and UI can read/write this state, making the campaign:

- Observable (easy to inspect and debug).
- Extensible (easy to add new missions, arcs, or modes).
- Tunable (balance via data rather than code changes).

---

## Data Model Overview

Key tables (see docs/sql/briefing_profile-v1.sql for full SQL):

- `campaign_profile`
  - Identifies a specific campaign (save slot / profile).
  - Stores high-level configuration (difficulty preset, creation time).

- `campaign_state`
  - Stores mutable campaign variables:
    - total_funds
    - notoriety (0–100)
    - total_missions_completed
    - total_equipment_lost
    - total_suit_losses

- `mission`
  - Represents a **location template**:
    - code, name, location label.
    - is_story_mission (1/0).
    - base_fee (baseline payout).
    - (Future) randomization profile ID, archetype tags, etc.

- `mission_run`
  - Represents a **single attempt** at a mission:
    - campaign_id, mission_id, run_code.
    - timestamps, rating, success.
    - is_contract_mode (1/0).

- `briefing_profile`
  - Stores **how the player configured the run**:
    - difficulty_preset, playstyle_preset.
    - expected payout and notoriety ranges (for UI preview).

- `briefing_loadout`
  - Records the selected suit, weapons, gadgets, and stashes.

- `run_equipment_outcome`
  - Records what happened to each piece of gear (returned, lost, abandoned, confiscated).

- `campaign_suit_state`
  - Tracks per-suit lifetime usage and losses (times_used, times_lost, suit_heat).

- `run_payment_breakdown`
  - Stores per-run economic breakdown:
    - base_fee, rating_bonus, stealth_bonus.
    - penalties (notoriety, equipment loss, suit loss).
    - costs (intel, bribes).
    - net_payment.

These tables define the **campaign as a stateful data graph**. The engine, UI, and AI only need to follow the graph.

---

## Campaign Lifecycle (High-Level)

### 1. Campaign Creation

On new game:

- Insert into `campaign_profile` with:
  - profile_name
  - difficulty_preset
- Insert into `campaign_state` with:
  - total_funds = starting balance
  - notoriety = 0 (or scenario-defined starting value)

This is handled via `briefing_create_campaign` in `briefing_profile.lua`.

### 2. Mission Selection

The campaign selects a `mission` row using any combination of:

- Story order (e.g., by sequence index).
- Player choice from a location map.
- Procedural selection (e.g., random pick from missions with a given archetype).

Randomization metadata can live in separate tables (planned):

- `mission_variant_profile`
- `mission_random_rule`

The selected `mission` plus its variant configuration will define the next `mission_run`.

### 3. Briefing and Run Configuration

The briefing UI constructs a **briefing profile object**:

- campaign_id
- mission_code
- difficulty_preset
- playstyle_preset (e.g., `silent_professional`, `social_engineer`)
- expected payout / notoriety ranges (for UI only)
- loadout:
  - item_code, slot_tag, is_stash

The helper `briefing_start_run_from_profile`:

- Creates a `mission_run`.
- Inserts a `briefing_profile`.
- Writes `briefing_loadout` entries.

The game can then transition from UI into gameplay with a fully-defined data context.

### 4. Mission Execution and Telemetry

During the mission:

- Evidence, NPC behavior, suit interactions, and equipment usage are logged:
  - Evidence system writes to:
    - `evidence_source`, `evidence_instance`, `cleanup_action`.
  - Equipment outcomes are determined (what is dropped, confiscated, or left behind).
- This data is tied to `mission_run.run_code` for cross-reference.

### 5. Run Finalization

On mission completion or failure:

- The game passes a `run_outcome` object to `briefing_finalize_run_payment`:
  - mission_run_id
  - result_rating, result_success
  - unresolved_evidence_score (from evidence system)
  - equipment_outcomes (per item status)
  - notoriety_delta
  - intel_cost, bribe_cost

The helper then:

- Updates `mission_run` completion and rating.
- Inserts `run_equipment_outcome`.
- Updates or creates `campaign_suit_state` rows (tracking suit heat and losses).
- Computes and inserts `run_payment_breakdown`.
- Updates `campaign_state` (funds, notoriety, mission count, loss counters).

This closes the loop for one mission in the campaign.

---

## Randomization and Procedural Hooks

A data-driven campaign can introduce replayability by **parameterizing missions** rather than generating entirely random content.

### Mission Variant Data

Introduce variant-related fields (planned tables):

- `mission_variant_profile`
  - mission_id
  - name (e.g., "High Security", "Festival Crowd", "Storm Night")
  - security_profile_id
  - crowd_profile_id
  - weather_profile_id
  - enabled_targets (list or reference to target sets)

- `mission_run`
  - Add columns:
    - variant_profile_id
    - variant_seed

At run start:

- The campaign logic chooses a variant profile and/or seed.
- Gameplay systems (AI, crowds, weather, opportunities) read these values and configure the level accordingly.

### Procedural Starting-Point Maps

For new locations or future development:

- Store archetype metadata in tables like:
  - `map_archetype`
    - id, label, type (vineyard, riverboat, expo hall)
    - size, layer_count, default_security_profile
  - `map_layout_seed`
    - archetype_id, seed, designer_notes

Tools can generate blockouts from `map_archetype` + `map_layout_seed`, then designers refine them. The resulting mission uses the same `mission` + `mission_variant_profile` framework.

---

## Campaign Modes via Data Flags

Because campaigns are data objects, different modes are just configurations:

### 1. Story Mode

- `mission.is_story_mission = 1`
- Strict order (e.g., by `mission.sequence_index`).
- Certain systems forced on:
  - Full notoriety, full equipment/suit penalties.
- Briefing may lock some tabs or options when narrative requires.

### 2. Persistent Career / Hardcore

- Same as Story Mode but with:
  - Higher penalties for failures.
  - Less forgiving funds and notoriety caps.
  - Possibly no reload of specific mission runs (ironman-like).

### 3. Contracts / Free-Roam Mode

- `mission_run.is_contract_mode = 1`
- May:
  - Use separate `campaign_profile` row or a shared one.
  - Choose to reduce or disable persistent penalties from `run_equipment_outcome`.
- Allows:
  - User-defined targets and restrictions.
  - Custom payouts and challenge modifiers.

All of these are differences in **data interpretation**, not separate code paths.

---

## AI & Tooling Integration

Treat the campaign as a data source that AI and tools can query:

- Suggest loadouts and intel based on:
  - `campaign_state.total_funds`
  - `campaign_state.notoriety`
  - Historical `run_payment_breakdown` patterns.

- Generate reactive dialogue:
  - Input: `campaign_state`, last `mission_run`, `run_payment_breakdown`.
  - Output: templated lines in briefing and post-mission commentary.

- Balance analysis:
  - Query SQLite directly to understand:
    - Average payout per mission.
    - Typical notoriety progression curves.
    - Which missions or variants cause excessive suit/equipment losses.

Because everything is stored in SQLite with clear schemas, external tools (or AI agents) can run offline analyses and propose tuning adjustments.

---

## Implementation Notes

- Start with the **schema and Lua helpers**:
  - Ensure `briefing_profile.lua` and `evidence_system.lua` are working end-to-end.
- Keep the campaign model **engine-agnostic**:
  - C++/Rust or other languages should call into Lua or directly into SQLite, using the same schemas.
- Document all invariants:
  - e.g., notoriety must stay between 0 and 100.
  - mission_code and item_code must be from known catalogs.
- Version the schema:
  - Store a `schema_version` entry somewhere (e.g., a `meta` table) to support migrations as the design evolves.

This data-first campaign model provides a robust spine for Blood Money 2–style gameplay: systemic, persistent, replayable, and friendly to both developers and AI-assisted tools.
