# Agent-47-Wiki

Agent-47-Wiki is a fictional, fan-made documentation wizard and systems spine for the Hitman series.  
It is designed to plug into AI-Chat, code agents, and CI/CD pipelines to help developers reason about stealth, evidence, inventory, crowds, and narrative while preserving the core feel of the games.

> This project is non-commercial, fan-made, and respects IO Interactive and all rightful owners of Hitman-related IP.  
> It does not ship game assets and is intended only as design, tooling, and documentation scaffolding.

---

## Goals

- Provide a **plausible systems backbone** for future Hitman-like titles (or mods).
- Keep **strict continuity with core gameplay DNA** (disguises, social stealth, evidence, rating systems).[web:6][web:10][web:37]
- Offer **clean, neutral abstractions** that are safe for AI-Chat and automated coding agents.
- Integrate easily with **Rust, C++, Lua/ALN, and SQLite** for scripting, telemetry, and testing.
- Serve as **open, community-friendly grounding** for experiments on GitHub, AI-Chat, and other platforms.

---

## Core Modules

Agent-47-Wiki is organized into several systems. Each system has:

- A Markdown spec in `docs/`
- Optional reference code (Rust/C++/Lua) in `src/`
- SQLite-oriented schemas in `docs/sql/` or inline in spec docs

### Evidence System

- Models abstract “evidence sources” (cameras, witnesses, intel) and “evidence instances”.
- Tracks what the world has recorded about the player, how it can be cleaned up, and how it affects ratings and campaign state.[web:10]
- SQLite-first: tables like `evidence_source`, `evidence_instance`, and `cleanup_action` for consistent logging and tooling.

Key doc: `docs/systems/evidence-system-v1.md`

### Notoriety System

- Campaign-level **profile visibility** inspired by Hitman: Blood Money’s notoriety, but parameterized and data-driven.[web:10]
- Connects unresolved evidence and loud playstyles to future-mission difficulty (enforcers, suspicion speed, stricter security).
- Supports mitigation actions: bribes, cleanups, narrative triggers.

Key doc: `docs/systems/notoriety-system-v1.md`

### Stealth & Suspicion

- Encodes **social stealth** and suspicion rules as logic, not visuals.[web:15][web:37]
- Uses per-observer suspicion values influenced by:
  - Disguise appropriateness
  - Illegal actions and items
  - Line-of-sight and crowd density
  - Notoriety level
- Reference implementation in Rust, intended to be portable to C++/Lua/ALN.

Key file: `src/stealth/suspicion.rs`  
Key doc: `docs/systems/stealth-suspicion-v1.md` (planned)

### Inventory & Quick-Access

- Proposes a **minimal quick-access layer** over a full inventory wheel:
  - Fiber wire / neutralization tool
  - Lockpick / access tools
  - Silenced sidearm
  - Coin / distraction gadget
- Focuses on **muscle memory** and **few, consistent gamepad hotkeys**, staying close to the trilogy’s feel.[web:15]

Key doc: `docs/ui/inventory-quick-access-v1.md`

### Crowded Areas & Crowd Logic

- Defines a **crowd cell** model for dense environments:
  - Density, flow direction, collision mode
  - Audio masking, attention bias, panic thresholds
- Keeps performance reasonable while enabling:
  - Blending, cover, and chaos scenes
  - Evidence bursts when many people “see” a key event

Key doc: `docs/ai/crowd-behaviour-v1.md`

### Gadgets & Interaction Types

- Creates a **neutral taxonomy of gadgets**:
  - Distraction devices
  - Area-effect devices
  - Signal and jamming tools
- Pairs with action tags so scripting and telemetry use safe, abstract terms rather than graphic wording.

Key doc: `docs/systems/gadgets-v1.md` (planned)

---

## Policy-Safe Action Tags

To keep AI-Chat and automated agents policy-aligned, the project defines **neutral, invariant action tags** for all gameplay telemetry and scripting.

Examples:

- `state_neutralize` — character neutralization event  
- `access_restricted_entry` — entry into a restricted area  
- `device_area_effect` — area-of-effect device activation  
- `signal_impulse_high` — high-intensity impulse event  

Raw verbs like “kill”, “gunshot”, or “explosion” are mapped to these neutral tags via an alias table in SQLite, so tools and prompts always reason over the safe abstraction layer.

Key doc: `docs/policy/action-tag-abstractions-v1.md`

---

## Tech Stack

You can use Agent-47-Wiki in different ways depending on your stack:

- **Rust / C++**
  - Core simulation / AI logic
  - Stealth, suspicion, and AI-visibility helpers
- **Lua / ALN**
  - Mission scripting and Contracts-mode logic
  - Dialogue conditions and mission story branching
- **SQLite**
  - Telemetry, evidence, notoriety, and configuration storage
  - Safe action tags and policy alias mappings

The repo is intentionally **engine-agnostic**. You can adapt it to:

- Custom engines
- Modding toolchains
- Analysis / research pipelines

---

## Use Cases

- Prototype a **Hitman-like sandbox** with a consistent ruleset.
- Run **CI tests** against stealth logic, evidence tracking, and notoriety changes.
- Feed **AI-Chat agents** with structured, neutral game state for:
  - Dynamic dialogue
  - Mission story suggestions
  - Design reviews and balancing ideas
- Explore new systems (e.g., Blood Money 2–style campaigns) without rewriting the core vocabulary every time.

---

## Contributing

Because this is a fan-made project:

- Do **not** submit copyrighted game assets (models, textures, audio, or proprietary code).
- Focus contributions on:
  - Systems design docs (`docs/`)
  - Engine-agnostic code samples (`src/`)
  - SQLite schemas and migration scripts (`docs/sql/`)
- Keep naming neutral and policy-safe so it remains usable in AI-Chat environments.

Issue and PR templates (planned):

- `design-change.md` — for proposing new systems or adjustments.
- `scenario-pitch.md` — for mini “contracts” or story scenarios that exercise the systems.
- `integration-notes.md` — for engine / tooling integration guides.

---

## Status

Agent-47-Wiki is under active, iterative design.  
Specs may change as:

- Community feedback arrives.
- New stealth/narrative patterns are discovered.
- Tooling and AI-Chat capabilities evolve.

Contributions, critiques, and experimental forks are welcome—just remember: this is **for learning and inspiration**, not an official Hitman product.
