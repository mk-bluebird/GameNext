-- briefing_profile-v1.sql
-- Agent-47-Wiki: Briefing + campaign profile schema
-- Focus: systemic complexity, replayability, payment + disguises,
--        persistent penalties for abandoned suits/equipment.

PRAGMA foreign_keys = ON;

------------------------------------------------------------
-- Core entities
------------------------------------------------------------

-- One row per player campaign profile.
CREATE TABLE IF NOT EXISTS campaign_profile (
  id INTEGER PRIMARY KEY,
  profile_name TEXT NOT NULL,
  difficulty_preset TEXT NOT NULL DEFAULT 'normal',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Per-campaign economy + notoriety state.
CREATE TABLE IF NOT EXISTS campaign_state (
  campaign_id INTEGER PRIMARY KEY,
  total_funds INTEGER NOT NULL DEFAULT 0,
  notoriety INTEGER NOT NULL DEFAULT 0,        -- 0–100
  total_missions_completed INTEGER NOT NULL DEFAULT 0,
  total_equipment_lost INTEGER NOT NULL DEFAULT 0,
  total_suit_losses INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (campaign_id) REFERENCES campaign_profile(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Missions and runs (replayability)
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS mission (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,                   -- e.g. "BM2_M01_PIER"
  name TEXT NOT NULL,
  location TEXT NOT NULL,                      -- city / location label
  is_story_mission INTEGER NOT NULL DEFAULT 1, -- 1 = story, 0 = free-roam/side
  base_fee INTEGER NOT NULL DEFAULT 0          -- base payment for completion
);

-- Each attempt is a "run" (supports replay & Contracts-style modes).
CREATE TABLE IF NOT EXISTS mission_run (
  id INTEGER PRIMARY KEY,
  campaign_id INTEGER NOT NULL,
  mission_id INTEGER NOT NULL,
  run_code TEXT NOT NULL,                      -- unique per campaign (for evidence link)
  started_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  completed_at TEXT,
  result_rating TEXT,                          -- "Silent Assassin", "Professional", etc.
  result_success INTEGER NOT NULL DEFAULT 0,   -- 1 = mission completed
  is_contract_mode INTEGER NOT NULL DEFAULT 0, -- 1 = replay/Contracts-style
  FOREIGN KEY (campaign_id) REFERENCES campaign_profile(id) ON DELETE CASCADE,
  FOREIGN KEY (mission_id) REFERENCES mission(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Briefing profile per mission_run
------------------------------------------------------------

CREATE TABLE IF NOT EXISTS briefing_profile (
  id INTEGER PRIMARY KEY,
  mission_run_id INTEGER NOT NULL UNIQUE,
  -- Systemic knobs chosen in the briefing:
  difficulty_preset TEXT NOT NULL,
  playstyle_preset TEXT,       -- e.g. "silent_professional", "social_engineer"
  expected_payout_min INTEGER,
  expected_payout_max INTEGER,
  expected_notoriety_delta_min INTEGER,
  expected_notoriety_delta_max INTEGER,
  FOREIGN KEY (mission_run_id) REFERENCES mission_run(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Loadout & disguises (with persistence)
------------------------------------------------------------

-- All items that can be taken into missions.
CREATE TABLE IF NOT EXISTS item_catalog (
  id INTEGER PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,         -- e.g. "SUIT_CLASSIC", "PISTOL_SILVER_01"
  name TEXT NOT NULL,
  kind TEXT NOT NULL,                -- "suit", "weapon", "gadget", "tool"
  base_cost INTEGER NOT NULL DEFAULT 0
);

-- Items selected in the briefing for a mission run.
CREATE TABLE IF NOT EXISTS briefing_loadout (
  id INTEGER PRIMARY KEY,
  mission_run_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  slot_tag TEXT NOT NULL,            -- "suit", "primary_tool", "sidearm", "gadget1", etc.
  is_stash INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (mission_run_id) REFERENCES mission_run(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES item_catalog(id) ON DELETE CASCADE
);

-- What actually happened to those items by the end of the run.
CREATE TABLE IF NOT EXISTS run_equipment_outcome (
  id INTEGER PRIMARY KEY,
  mission_run_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,
  status TEXT NOT NULL,              -- "returned", "lost", "confiscated", "abandoned"
  FOREIGN KEY (mission_run_id) REFERENCES mission_run(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES item_catalog(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Suit / identity penalties (persistent)
------------------------------------------------------------

-- Suit-specific tracking per campaign (for escalating penalties).
CREATE TABLE IF NOT EXISTS campaign_suit_state (
  id INTEGER PRIMARY KEY,
  campaign_id INTEGER NOT NULL,
  item_id INTEGER NOT NULL,          -- must refer to an item_catalog row with kind="suit"
  times_used INTEGER NOT NULL DEFAULT 0,
  times_lost INTEGER NOT NULL DEFAULT 0,
  -- Optional: heat/visibility for this specific suit model.
  suit_heat INTEGER NOT NULL DEFAULT 0, -- 0–100, can modify suspicion or intel prices.
  UNIQUE (campaign_id, item_id),
  FOREIGN KEY (campaign_id) REFERENCES campaign_profile(id) ON DELETE CASCADE,
  FOREIGN KEY (item_id) REFERENCES item_catalog(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Payment calculation & penalties
------------------------------------------------------------

-- Per-run breakdown of money flow (systemic, replayable).
CREATE TABLE IF NOT EXISTS run_payment_breakdown (
  id INTEGER PRIMARY KEY,
  mission_run_id INTEGER NOT NULL,
  base_fee INTEGER NOT NULL DEFAULT 0,
  rating_bonus INTEGER NOT NULL DEFAULT 0,
  stealth_bonus INTEGER NOT NULL DEFAULT 0,
  notoriety_penalty INTEGER NOT NULL DEFAULT 0,
  equipment_loss_penalty INTEGER NOT NULL DEFAULT 0,
  suit_loss_penalty INTEGER NOT NULL DEFAULT 0,
  intel_cost INTEGER NOT NULL DEFAULT 0,
  bribe_cost INTEGER NOT NULL DEFAULT 0,
  net_payment INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (mission_run_id) REFERENCES mission_run(id) ON DELETE CASCADE
);

------------------------------------------------------------
-- Example penalty logic (documentation snippet, not executable SQL)
------------------------------------------------------------

-- Conceptual formula for equipment/suit penalties per run:
--  equipment_loss_penalty = SUM( lost_item_value * 1.0 )
--  suit_loss_penalty      = SUM( lost_suit_value * SUIT_MULTIPLIER )
--
-- Where:
--  - lost_item_value is derived from item_catalog.base_cost,
--  - SUIT_MULTIPLIER is greater than 1 (e.g. 2.5x) to reflect
--    higher narrative and systemic risk of leaving identity evidence.
--
-- Campaign_state.total_equipment_lost and total_suit_losses should
-- be incremented whenever run_equipment_outcome.status IN ("lost", "abandoned").

------------------------------------------------------------
-- Free-roam / alternate mode flag
------------------------------------------------------------

-- mission.is_story_mission already marks story missions.
-- For free-roam, campaign_id can be NULL, or is_contract_mode = 1 on mission_run.
-- Briefing systems should:
-- - Use the same tables, but
-- - Skip persistent penalties when mission_run.is_contract_mode = 1
--   if game design chooses to keep Contracts "lighter" or separate.
