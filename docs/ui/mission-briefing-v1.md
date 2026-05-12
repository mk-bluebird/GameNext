# Mission Briefing UI v1

## Purpose

Define a mission-briefing screen that:

- Preserves the feel of Hitman: Blood Money briefings (intel cards, upgrades, money and notoriety tradeoffs).
- Integrates modern trilogy-style visuals and reactive narration.
- Exposes structured data hooks for loadout selection, notoriety, intel, and Contracts mode.

The briefing is a **single, layered hub** the player visits before each mission.

---

## High-Level Structure

Tabs / sections:

- OVERVIEW
- TARGETS & WORLD
- LOADOUT & UPGRADES
- NOTORIETY & RISK
- INTEL MARKET
- CONTRACT OPTIONS (optional / Contracts mode)

Each tab uses the same base layout:

- Left column: Visuals (images, short clips, target portraits, diagrams).
- Center column: Primary text and interactive lists.
- Right column: Contextual info panels (stats, modifiers, hints, money/notoriety indicators).

---

## Tab: OVERVIEW

### Fields

- Mission Title
- Location Name and Tagline (e.g., “New Orleans – The Bayou Gala”)
- Brief Synopsis (2–3 sentences)
- Objectives List
  - Main objectives (targets, key items).
  - Optional objectives (bonus intel, accidents, challenges).

### Interactive Elements

- Difficulty selector (simple slider or presets).
- “Recommended Preset” button:
  - Uses player history to pick a template (e.g., Silent Professional, Social Engineer).

### Example Diana Lines (by notoriety)

- Low notoriety:
  - “Our client expects a clean operation. As always, your presence should be nothing more than a rumor.”
- Medium notoriety:
  - “Some of the security staff have been briefed on recent incidents. You may encounter officers with sharper memories than usual.”
- High notoriety:
  - “Your recent work has not gone unnoticed. Facial composites are circulating, and some officials will be on edge. Choose your entry and appearance carefully.”

---

## Tab: TARGETS & WORLD

### Fields

- Target cards:
  - Name, title, age (optional), photo/portrait.
  - Role summary (1–2 sentences).
  - Key vulnerability tags (schedule, vice, routine, entourage).
- World context:
  - Event type (gala, expo, private meeting).
  - Security posture (relaxed, professional, paranoid).
  - Crowd density profile (sparse, mixed, heavy).

### Interactive Elements

- “Show Routes” toggle:
  - Highlights high-level ingress/egress points in a 2D map or 3D overview.
- “Behavior Preview” button:
  - Plays a short loop showing a typical moment in the target’s routine (walking stage route, visiting bar, inspecting security).

### Example Lines

- Schedule-focused:
  - “Your primary target follows a strict routine, appearing on the balcony every hour. It’s the only time she’s exposed to open air.”
- Vice-focused:
  - “He has a weakness for late-night gambling. The VIP lounge may offer opportunities if you can blend with the regulars.”
- Security posture:
  - “Security is professional, but not paranoid. Disguises should hold, as long as you respect local boundaries.”

---

## Tab: LOADOUT & UPGRADES

### Fields

- Suit / starting outfit selector.
- Primary tool slots:
  - Slot 1: Neutralization tool (fiber wire, contact tool).
  - Slot 2: Precision sidearm (customizable Silverballer-style).
  - Slot 3: Access tool (lockpick, crowbar, breaching tool).
  - Slot 4: Distraction gadget (coin, noise devices, signal gadgets).
- Stash locations list:
  - Each with a short description and recommended stash item type.

### Weapon/Tool Upgrades

- Inline upgrade panel for each weapon, inspired by Blood Money:
  - Upgrades grouped by type (ammo, suppressor, optics, handling).[web:61][web:64][web:71]
  - Tier display showing unlocked upgrade tiers based on campaign money total.[web:71]
  - Live preview of stealth profile (noise, visibility, range).

### Interactive Elements

- “Recommended Loadout” button:
  - Suggests a preset based on mission tags and player history.
- “Save as Preset” button:
  - Stores current loadout as a named profile.
- Budget bar:
  - Shows current funds, cost of selected upgrades, and remaining budget.

### Example Lines

- Based on mission profile:
  - “Given the tight corridors and overlapping patrols, a compact suppressed sidearm and light access tools are advisable.”
- Based on player style:
  - “You’ve favored distance solutions recently. The rooftop stash could support a long-range configuration if you’re willing to invest in optics.”

---

## Tab: NOTORIETY & RISK

### Fields

- Current notoriety level (0–100) with tier label:
  - Ghost, Known Face, Person of Interest, High-Profile.
- Breakdown of previous mission contributions:
  - Unresolved evidence severity (abstract score).
  - Civilian witnesses.
  - Loud incidents (area-effect device events, high-intensity impulses).
- Upcoming mission modifiers:
  - Enforcer density.
  - Suspicion acceleration.
  - Security checks (frisks, ID checks).

### Interactive Elements

- Bribe / mitigation panel:
  - Options like:
    - Local bribe (reduce enforcers in this mission only).
    - Record scrub (reduce notoriety globally).
    - Disinformation campaign (convert some risk into gossip rather than official heat).
- Slider or buttons showing:
  - Cost in money.
  - Change to notoriety level.
  - Preview of AI behavior (small text/icons).

### Example Lines

- Low notoriety:
  - “Officially, you don’t exist. Any extra precautions are personal paranoia on their part.”
- Mid notoriety:
  - “Some security staff have been shown your picture. Bribing the local chief could ensure it never reaches the patrols.”
- High notoriety:
  - “You are a priority subject. Without intervention, some guards will recognize your face, even in the crowd.”

---

## Tab: INTEL MARKET

### Fields

- Intel cards with cost (in-game currency):
  - Layout:
    - Title (e.g., “Alternate Staff Entrance”).
    - Category: Access / Distraction / Accident / Escape / Target Routine.
    - Short effect description (what it reveals or changes).
- Purchased intel list:
  - Shows which cards are already owned for this mission.

### Interactive Elements

- Category filters:
  - Access, Distraction, Accident, Escape, Routine, Security.[web:59][web:70]
- “Preview on Map” button:
  - Temporarily overlays intel effect on the mini-map or 3D overview.
- Bundle suggestions:
  - “Silent route” bundle.
  - “Accident route” bundle.
  - “Improvised chaos” bundle.

### Example Lines

- Access intel:
  - “For a modest fee, our contact will mark a staff entrance rarely used by supervisors.”
- Accident intel:
  - “There’s an unmaintained lighting rig above the main stage. The contractor’s report suggests it might not withstand much interference.”
- Escape intel:
  - “A catering van leaves through the side gate every thirty minutes. If you’re dressed appropriately, no one will ask questions.”

---

## Tab: CONTRACT OPTIONS (Optional / Contracts Mode)

### Fields

- Custom target list:
  - Checkboxes to promote notable NPCs to targets.
- Restrictions:
  - Suit-only, no intel purchase, limited gadgets, no neutralization tools, etc.
- Payout preview:
  - Base reward plus modifiers for restrictions.

### Interactive Elements

- “Generate Contract Code”:
  - Produces a shareable code or descriptor for community contracts.
- “Test Contract Briefing”:
  - Shows what other players will see as the briefing for this custom contract.

### Example Lines

- Contract pitch:
  - “You can formalize this as a contract: three staff members, no external support, and a clean exit. The Syndicate will pay accordingly.”
- Restriction explanation:
  - “Limiting yourself to standard equipment will increase the payout, but removes the safety net of specialized tools.”

---

## Data & Telemetry Hooks

For each mission briefing session, log:

- Chosen difficulty and preset name.
- Selected suit, weapons, gadgets, stash locations.
- Purchased intel card IDs and bundles.
- Notoriety mitigation choices.
- Contracts-mode decisions (targets, restrictions).

This structured data can be stored via SQLite and analyzed by AI-Chat agents and CI pipelines to:

- Suggest better defaults for new players.
- Evaluate balance of intel pricing and upgrade costs.[web:48][web:50][web:51]
- Generate dynamic briefing commentary in future missions based on history.

---

## Implementation Notes

- All in-briefing text and tags should use **neutral, policy-safe vocabulary**, consistent with `docs/policy/action-tag-abstractions-v1.md`.
- Dialogue lines are templates:
  - Inputs: notoriety tier, mission tags, player playstyle profile, loadout choices.
  - Outputs: short, context-aware lines for the voice briefing and subtitles.
- The UI spec is engine-agnostic:
  - Tabs and fields should map directly to data structures accessible from Lua/ALN and C++/Rust code.
