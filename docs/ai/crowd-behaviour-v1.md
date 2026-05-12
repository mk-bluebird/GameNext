# Crowd Behaviour v1

## Core Concept

Represent dense crowds as overlapping "crowd cells" with shared properties, plus a smaller set of promoted "foreground NPCs" with full AI.

## Parameters

- cell_id
- density (0–1)
- movement_flow_dir (angle)
- collision_mode (ghost, soft_push, hard_block)
- attention_bias (how likely a random NPC in the cell will notice 47)
- audio_masking (how much the crowd masks gunshots/footsteps/explosions)
- panic_threshold (how easily the cell transitions to panic)

## Behaviour Rules (Sketch)

- Normal state:
  - Low attention_bias, high audio_masking.
  - 47 can blend; suspicion grows slowly unless extremely illegal actions occur.

- Suspicious state:
  - Triggered by small weapons seen, loud arguments, nearby subdued NPCs.
  - Attention_bias increases, some foreground NPCs spawn as enforcers.

- Panic state:
  - Triggered by gunshots, explosions, obvious corpses.
  - Crowd cells change to high movement_flow_dir speed, drop audio_masking.
  - New evidence_instance rows created for multiple human witnesses in one go.
