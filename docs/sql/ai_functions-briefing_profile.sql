-- ai_functions-briefing_profile.sql
-- Companion to ai_function_registry.sql
-- Registers briefing_profile-related functions so AI/chat agents
-- can reason about campaign, runs, and payments in a structured, safe way.

PRAGMA foreign_keys = ON;

------------------------------------------------------------
-- Briefing + Campaign functions (Lua)
------------------------------------------------------------

-- 1) create_campaign
INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'briefing_create_campaign',
  'src/lua/briefing_profile.lua',
  'lua',
  'Create a new campaign profile and initial campaign_state row for Blood Money 2–style progression.',
  '{
    "type": "object",
    "properties": {
      "profile_name": {
        "type": "string",
        "description": "Player-visible profile label, e.g. \"Main Campaign\""
      },
      "difficulty_preset": {
        "type": "string",
        "description": "Difficulty preset key, e.g. normal, professional, master"
      }
    },
    "required": ["profile_name"]
  }',
  '{
    "type": "object",
    "properties": {
      "campaign_id": {
        "type": "integer",
        "description": "Primary key of the new campaign_profile row."
      }
    }
  }',
  'Creates data only; does not start a mission. Use this to bootstrap a fresh campaign profile. Difficulty presets must be valid keys recognized by the game; avoid inventing arbitrary names in AI-generated calls.',
  'campaign,profile,setup'
);

-- 2) start_run_from_briefing
INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'briefing_start_run_from_profile',
  'src/lua/briefing_profile.lua',
  'lua',
  'Create a mission_run and associated briefing_profile + loadout rows based on a high-level briefing profile.',
  '{
    "type": "object",
    "properties": {
      "campaign_id": {
        "type": "integer",
        "description": "Existing campaign_profile.id."
      },
      "mission_code": {
        "type": "string",
        "description": "Mission code matching mission.code (e.g. BM2_M01_PIER)."
      },
      "difficulty_preset": {
        "type": "string",
        "description": "Difficulty preset key to apply for this run."
      },
      "playstyle_preset": {
        "type": "string",
        "description": "Optional style hint, e.g. silent_professional, social_engineer."
      },
      "expected_payout_min": {
        "type": "integer",
        "description": "Optional lower bound for projected payout."
      },
      "expected_payout_max": {
        "type": "integer",
        "description": "Optional upper bound for projected payout."
      },
      "expected_notoriety_delta_min": {
        "type": "integer",
        "description": "Optional min projected notoriety change."
      },
      "expected_notoriety_delta_max": {
        "type": "integer",
        "description": "Optional max projected notoriety change."
      },
      "loadout": {
        "type": "array",
        "description": "List of loadout entries selected in briefing.",
        "items": {
          "type": "object",
          "properties": {
            "item_code": {
              "type": "string",
              "description": "Item identifier from item_catalog.code."
            },
            "slot_tag": {
              "type": "string",
              "description": "Slot tag, e.g. suit, primary_tool, sidearm, gadget1."
            },
            "is_stash": {
              "type": "boolean",
              "description": "True if item should be placed in a stash instead of on-start."
            }
          },
          "required": ["item_code"]
        }
      },
      "is_contract_mode": {
        "type": "boolean",
        "description": "True for Contracts/free-roam style runs."
      }
    },
    "required": ["campaign_id", "mission_code"]
  }',
  '{
    "type": "object",
    "properties": {
      "mission_run_id": {
        "type": "integer",
        "description": "Primary key of mission_run row."
      },
      "run_code": {
        "type": "string",
        "description": "Unique textual run code (useful for cross-linking evidence)."
      },
      "mission_id": {
        "type": "integer",
        "description": "Resolved mission.id for the chosen mission_code."
      }
    }
  }',
  'Does not launch gameplay; only writes DB state for a new run and briefing profile. mission_code and item_code must already exist in mission and item_catalog. AI agents should not invent new codes at call time.',
  'briefing,run,loadout,notoriety'
);

-- 3) finalize_run_payment
INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'briefing_finalize_run_payment',
  'src/lua/briefing_profile.lua',
  'lua',
  'Finalize a mission run: store rating, compute payment and penalties, update campaign_state, and log equipment/suit losses.',
  '{
    "type": "object",
    "properties": {
      "mission_run_id": {
        "type": "integer",
        "description": "ID of the mission_run being completed."
      },
      "result_rating": {
        "type": "string",
        "description": "Rating label, e.g. Silent Assassin, Professional."
      },
      "result_success": {
        "type": "boolean",
        "description": "True if mission objectives were completed."
      },
      "unresolved_evidence_score": {
        "type": "number",
        "description": "Aggregate unresolved evidence severity from evidence system."
      },
      "equipment_outcomes": {
        "type": \"array\",
        \"description\": \"Outcome for each item taken into the mission.\",
        \"items\": {
          \"type\": \"object\",
          \"properties\": {
            \"item_code\": {
              \"type\": \"string\",
              \"description\": \"Item identifier from item_catalog.code.\"
            },
            \"status\": {
              \"type\": \"string\",
              \"description\": \"returned, lost, abandoned, or confiscated.\"
            }
          },
          \"required\": [\"item_code\", \"status\"]
        }
      },
      "notoriety_delta": {
        "type": "integer",
        "description": "Change in campaign notoriety for this run (can be negative)."
      },
      "intel_cost": {
        "type": "integer",
        "description": "Total funds spent on intel for this run."
      },
      "bribe_cost": {
        "type": "integer",
        "description": "Total funds spent on bribes/notoriety mitigation for this run."
      }
    },
    "required": ["mission_run_id", "result_success"]
  }',
  '{
    "type": "object",
    "properties": {
      "net_payment": {
        "type": "integer",
        "description": "Final payment credited (can be negative in extreme cases)."
      },
      "base_fee": { "type": "integer" },
      "rating_bonus": { "type": "integer" },
      "stealth_bonus": { "type": "integer" },
      "notoriety_penalty": { "type": "integer" },
      "equipment_loss_penalty": { "type": "integer" },
      "suit_loss_penalty": { "type": "integer" },
      "intel_cost": { "type": "integer" },
      "bribe_cost": { "type": "integer" },
      "new_total_funds": {
        "type": "integer",
        "description": "Updated campaign_state.total_funds."
      },
      "new_notoriety": {
        "type": "integer",
        "description": "Updated campaign_state.notoriety (0–100)."
      }
    }
  }',
  'This function operates on abstract, game-internal economic variables only. It must not be used to model real-world harm or financial crimes. Equipment statuses and penalties are purely fictional campaign mechanics.',
  'payments,notoriety,equipment,suits'
);

-- 4) get_campaign_summary (read-only helper)
INSERT OR IGNORE INTO ai_function (
  name, module, language, summary,
  input_schema, output_schema, invariants, tags
) VALUES (
  'briefing_get_campaign_summary',
  'src/lua/briefing_profile.lua',
  'lua',
  'Retrieve a concise summary of campaign funds, notoriety, and suit/equipment loss stats for briefing UI display.',
  '{
    "type": "object",
    "properties": {
      "campaign_id": {
        "type": "integer",
        "description": "Existing campaign_profile.id."
      }
    },
    "required": ["campaign_id"]
  }',
  '{
    "type": "object",
    "properties": {
      "total_funds": { "type": "integer" },
      "notoriety": { "type": "integer", "description": "0–100." },
      "total_missions_completed": { "type": "integer" },
      "total_equipment_lost": { "type": "integer" },
      "total_suit_losses": { "type": "integer" }
    }
  }',
  'Read-only helper for UI and dialogue systems. Returns aggregate campaign_state values; does not mutate any tables.',
  'campaign,summary,ui'
);

------------------------------------------------------------
-- Example entry for start_run_from_briefing
------------------------------------------------------------

INSERT OR IGNORE INTO ai_function_example (
  function_id, example_call, example_context
)
SELECT
  id,
  'briefing_start_run_from_profile({ campaign_id = 1, mission_code = "BM2_M01_PIER", difficulty_preset = "professional", playstyle_preset = "silent_professional", loadout = { { item_code = "SUIT_CLASSIC", slot_tag = "suit" }, { item_code = "PISTOL_SILVER_01", slot_tag = "sidearm" }, { item_code = "COIN_STANDARD", slot_tag = "gadget1" } }, is_contract_mode = false })',
  'Called when the player confirms the mission briefing for the first story run of BM2_M01_PIER using a silent-professional preset.',
FROM ai_function WHERE name = 'briefing_start_run_from_profile';
