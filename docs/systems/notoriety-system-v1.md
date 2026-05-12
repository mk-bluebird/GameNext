# Notoriety System v1

## Purpose

Model a persistent "heat" level for Agent 47 across a campaign, driven by mission behaviour and unresolved evidence. This mirrors classic Blood Money behaviour while remaining configurable.

## Core Variable

- notoriety (integer 0–100)
  - Stored per profile in a campaign_state table.
  - 0 = Unknown ghost.
  - 100 = Globally recognized, extreme risk.

## Mission Delta Calculation

Given a completed mission:

- Base_Gain:
  - Derived from:
    - unresolved_evidence_severity_sum
    - civilian_witness_count
    - non_target_casualty_count
    - loud_events_count (open firefights, explosions in public)
- Mitigation:
  - Successful cleanup actions (evidence fully cleared).
  - Optional narrative actions: bribes, false flag operations, sabotaging news feeds.

Example (pseudo-formula):

- notoriety_delta =
  clamp(
    (unresolved_evidence_severity_sum * 0.5)
    + (civilian_witness_count * 4)
    + (non_target_casualties * 3)
    + (loud_events * 2)
    - (post_mission_bribes * 8)
    - (cleanup_bonus * 5),
    -20,
    +20
  )

## Gameplay Effects

Notoriety affects:

- Disguise tolerance:
  - At higher notoriety, more NPC archetypes start as "pre-enforcers" against default suit and suspicious disguises.
- Suspicion acceleration:
  - Suspicion meters fill faster when NPCs look at 47.
- Checkpoint difficulty:
  - Stricter frisk checks, more cameras, extra guards.

## UX Guidelines

- Always surface notoriety changes in post-mission screens.
- Provide clear tooltips for what raised or lowered notoriety.
- Allow designers to switch notoriety off for isolated contracts or arcade modes.
