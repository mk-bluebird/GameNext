# Evidence System v1

## Purpose

Provide a unified, data-driven representation of "evidence" across all Hitman-inspired titles and tools. The system should be:

- Backwards-compatible with classic mechanics (cameras, witnesses, tapes, photos).
- Extensible for new devices (drones, smart glasses, IoT microphones).
- Queryable via SQLite for tools, analytics, and CI checks.

## Core Concepts

- Evidence Source: The origin that can record or remember Agent 47's incriminating activity.
- Evidence Instance: A specific record created at runtime (e.g., camera #12 captures 47 strangling a guard at 04:32).
- Cleanup Action: Any action that modifies or invalidates an evidence instance.

## Data Model (SQLite-oriented)

Tables (minimal baseline):

- evidence_source
  - id (PK)
  - kind (camera, witness, item_log, digital_log, forensic)
  - map_id
  - location_x, location_y, location_z
  - radius_or_fov (for trigger logic)
  - flags (bitfield: is_recording, is_destroyable, requires_power, etc.)

- evidence_instance
  - id (PK)
  - source_id (FK -> evidence_source.id)
  - mission_run_id
  - timecode
  - subject (agent47, npc, other)
  - action_tag (kill, trespass, disguise_theft, gunshot, explosion, etc.)
  - severity (0–100)
  - visibility_state (hidden, discoverable, discovered)
  - cleanup_state (intact, partially_cleaned, fully_cleaned, destroyed)
  - linked_npc_id (if a witness)
  - linked_item_id (if an item, e.g., security tape, USB stick)

- cleanup_action
  - id (PK)
  - evidence_instance_id (FK -> evidence_instance.id)
  - timecode
  - actor (agent47, npc, scripted_event)
  - action_tag (erase_footage, destroy_item, intimidate_witness, kill_witness, hack_server)
  - success (boolean)
  - notes (text)

## Runtime Hooks (Lua/ALN)

### Creation

- on_incriminating_action(agent, action_tag, location):
  - Query nearby evidence_source entries.
  - For each that can see/hear the action, create evidence_instance row.

### Cleanup

- on_evidence_container_interaction(agent, container_id, action_tag):
  - Mark related evidence_instance rows as partially_cleaned or destroyed.
  - Emit events for scoring / notoriety updates.

### Query Helpers

- evidence.get_active_for_run(mission_run_id)
- evidence.get_unresolved_severe(mission_run_id, min_severity)
- evidence.is_fully_clean(mission_run_id) -> bool

## Integration Points

- Rating System: Use active unresolved evidence_instance rows to penalize mission ratings.
- Notoriety System: Convert unresolved high-severity evidence into notoriety deltas.
- Narrative: Drive post-mission headlines, security briefings, and dialogue.
