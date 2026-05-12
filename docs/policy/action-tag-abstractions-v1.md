# Action Tag Abstractions v1

## Purpose

This document defines neutral, policy-friendly action tags for game telemetry and scripting.

Goals:

- Avoid graphic or extreme wording in code, docs, and AI prompts.
- Preserve enough semantic detail for research, analytics, and tooling.
- Provide a stable, SQLite-backed index that agents must obey as invariants.

These tags describe abstract interaction categories, not real-world harm.

---

## Category Overview

We group actions into high-level categories:

- ACT_STATE: Agent / NPC state changes.
- ACT_ACCESS: Movement through spaces and permissions.
- ACT_INTERACTION: Interactions with characters and props.
- ACT_DEVICE: Use of tools, gadgets, and devices.
- ACT_SIGNAL: Audio/visual/signal events.
- ACT_SYSTEM: System-level or meta events.

Each concrete tag has:

- `tag_code`: Stable, machine-friendly identifier.
- `category`: One of the categories above.
- `policy_hint`: How to describe it in neutral language.
- `notes`: Optional clarification for designers and tools.

---

## Core Tag Set

### 1. State & Outcome Tags (ACT_STATE)

- `state_neutralize`
  - category: ACT_STATE
  - policy_hint: "Character neutralization event"
  - notes: Abstracts any outcome where a character is removed from active participation.

- `state_incapacitate`
  - category: ACT_STATE
  - policy_hint: "Character temporarily incapacitated"
  - notes: Use for reversible outcomes (asleep, stunned, restrained).

- `state_down`
  - category: ACT_STATE
  - policy_hint: "Character downed"
  - notes: Non-specific; does not describe cause or permanence.

### 2. Access & Location Tags (ACT_ACCESS)

- `access_restricted_entry`
  - category: ACT_ACCESS
  - policy_hint: "Entry into a restricted area"
  - notes: Abstracts "trespass" without legal or moral judgment.

- `access_boundary_cross`
  - category: ACT_ACCESS
  - policy_hint: "Boundary crossing event"
  - notes: For any logical zone change that matters to stealth or AI.

- `access_identity_change`
  - category: ACT_ACCESS
  - policy_hint: "Identity or appearance change"
  - notes: Abstracts disguise changes, wardrobe swaps, etc.

### 3. Interaction Tags (ACT_INTERACTION)

- `interact_item_transfer`
  - category: ACT_INTERACTION
  - policy_hint: "Item transferred between entities"
  - notes: Covers picking up, handing off, or taking items.

- `interact_appearance_transfer`
  - category: ACT_INTERACTION
  - policy_hint: "Appearance or outfit transfer"
  - notes: Abstracts "disguise theft" in neutral terms.

- `interact_constraint_apply`
  - category: ACT_INTERACTION
  - policy_hint: "Constraint applied to a character"
  - notes: Handcuffs, bindings, non-specific restraints.

### 4. Device & Tool Tags (ACT_DEVICE)

- `device_projectile_use`
  - category: ACT_DEVICE
  - policy_hint: "Directed device use"
  - notes: Abstracts any precise, line-of-sight device action (e.g., ranged tools).

- `device_area_effect`
  - category: ACT_DEVICE
  - policy_hint: "Area-of-effect device activation"
  - notes: Abstracts "explosion" or gas, shock fields, etc.

- `device_contact_tool`
  - category: ACT_DEVICE
  - policy_hint: "Close-proximity tool use"
  - notes: Knives, wires, batons, or any close-contact tool.

- `device_signal_emitter`
  - category: ACT_DEVICE
  - policy_hint: "Signal-emitting gadget activation"
  - notes: Distractions, noise makers, signal jammers.

### 5. Signal & Perception Tags (ACT_SIGNAL)

- `signal_impulse_high`
  - category: ACT_SIGNAL
  - policy_hint: "High-intensity impulse event"
  - notes: Abstracts loud, short events (e.g., a report or blast).

- `signal_ambient_noise`
  - category: ACT_SIGNAL
  - policy_hint: "Ambient noise event"
  - notes: Drops, collisions, crowd surges.

- `signal_visual_alert`
  - category: ACT_SIGNAL
  - policy_hint: "Visual alert event"
  - notes: Flashing lights, HUD warnings, visible anomalies.

### 6. System & Meta Tags (ACT_SYSTEM)

- `system_evidence_create`
  - category: ACT_SYSTEM
  - policy_hint: "Evidence record created in system"
  - notes: Used when an action is captured by a sensor or witness.

- `system_evidence_resolve`
  - category: ACT_SYSTEM
  - policy_hint: "Evidence record resolved or cleared"
  - notes: Erasing, destroying, or invalidating an evidence item.

- `system_notoriety_delta`
  - category: ACT_SYSTEM
  - policy_hint: "Profile visibility level changed"
  - notes: Abstracts notoriety / heat changes.

---

## SQLite Schema (Invariants)

The following schema defines an indexable library of action tags.

```sql
CREATE TABLE IF NOT EXISTS action_tag (
  tag_code TEXT PRIMARY KEY,           -- e.g., "device_area_effect"
  category TEXT NOT NULL,             -- e.g., "ACT_DEVICE"
  policy_hint TEXT NOT NULL,          -- Neutral description for prompts / docs
  notes TEXT                          -- Optional designer notes
);

CREATE TABLE IF NOT EXISTS action_tag_alias (
  alias TEXT PRIMARY KEY,             -- e.g., "explosion", "gunshot", "kill"
  tag_code TEXT NOT NULL,             -- e.g., "device_area_effect"
  FOREIGN KEY (tag_code) REFERENCES action_tag(tag_code)
);
```

### Invariant Rules for AI-Chat and Coding Agents

- When reading or writing telemetry, scripts, or docs:
  - Use `tag_code` values only, not raw aliases.
  - If an alias like "explosion", "gunshot", or "kill" appears in input, map it through `action_tag_alias` to a neutral `tag_code` before storing or reasoning.
- Generated code and documents:
  - SHOULD reference `tag_code` and `policy_hint`.
  - SHOULD avoid embedding alias strings directly in user-facing text.
- Research and analytics tools:
  - MUST treat `tag_code` as the canonical identifier.
  - MAY expose `policy_hint` for human-readable dashboards.

---

## Example Aliases

```sql
INSERT INTO action_tag (tag_code, category, policy_hint) VALUES
  ('state_neutralize',      'ACT_STATE',   'Character neutralization event'),
  ('state_incapacitate',    'ACT_STATE',   'Character temporarily incapacitated'),
  ('state_down',            'ACT_STATE',   'Character downed'),
  ('access_restricted_entry','ACT_ACCESS','Entry into a restricted area'),
  ('access_identity_change','ACT_ACCESS',  'Identity or appearance change'),
  ('interact_appearance_transfer','ACT_INTERACTION','Appearance or outfit transfer'),
  ('device_projectile_use', 'ACT_DEVICE',  'Directed device use'),
  ('device_area_effect',    'ACT_DEVICE',  'Area-of-effect device activation'),
  ('device_contact_tool',   'ACT_DEVICE',  'Close-proximity tool use'),
  ('signal_impulse_high',   'ACT_SIGNAL',  'High-intensity impulse event'),
  ('system_evidence_create','ACT_SYSTEM',  'Evidence record created in system');

INSERT INTO action_tag_alias (alias, tag_code) VALUES
  ('kill',                'state_neutralize'),
  ('nonlethal_takedown',  'state_incapacitate'),
  ('body_down',           'state_down'),
  ('trespass',            'access_restricted_entry'),
  ('disguise_theft',      'interact_appearance_transfer'),
  ('gunshot',             'signal_impulse_high'),
  ('explosion',           'device_area_effect');
```

This abstraction layer lets game logic stay expressive while prompts, logs, and documentation remain neutral and policy-aligned.
