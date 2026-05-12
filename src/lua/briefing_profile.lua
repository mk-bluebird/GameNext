-- briefing_profile.lua
-- Agent-47-Wiki: Lua helper for briefing profiles and payments.
--
-- Depends on schema from docs/sql/briefing_profile-v1.sql
-- and a DB object with :eval(sql, params?, row_callback?) or similar.

local Briefing = {}
Briefing.__index = Briefing

function Briefing.new(db)
    local self = setmetatable({}, Briefing)
    self.db = db
    return self
end

------------------------------------------------------------
-- Utility
------------------------------------------------------------

local function now_iso8601()
    -- Simple placeholder; you can replace with an engine clock.
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function first_row(db, sql, params)
    local result
    db:eval(sql, params or {}, function(row)
        result = row
        return 1 -- stop after first
    end)
    return result
end

------------------------------------------------------------
-- Campaign helpers
------------------------------------------------------------

function Briefing:create_campaign(profile_name, difficulty_preset)
    self.db:eval([[
        INSERT INTO campaign_profile (profile_name, difficulty_preset, created_at)
        VALUES (:name, :difficulty, :created_at);
    ]], {
        name       = profile_name,
        difficulty = difficulty_preset or "normal",
        created_at = now_iso8601(),
    })

    local row = first_row(self.db, "SELECT last_insert_rowid() AS id;", {})
    local campaign_id = tonumber(row.id)

    self.db:eval([[
        INSERT INTO campaign_state (campaign_id, total_funds, notoriety)
        VALUES (:cid, 0, 0);
    ]], { cid = campaign_id })

    return campaign_id
end

------------------------------------------------------------
-- Start a mission run from a briefing profile
------------------------------------------------------------

-- profile:
-- {
--   campaign_id,
--   mission_code,
--   difficulty_preset,
--   playstyle_preset,
--   loadout = { { item_code="SUIT_CLASSIC", slot_tag="suit" }, ... },
--   is_contract_mode = false
-- }
function Briefing.start_run_from_briefing(self, profile)
    -- 1) Look up mission_id by mission_code.
    local mission_row = first_row(self.db,
        "SELECT id, base_fee FROM mission WHERE code = :code;",
        { code = profile.mission_code }
    )
    assert(mission_row, "Unknown mission code: " .. tostring(profile.mission_code))
    local mission_id = tonumber(mission_row.id)

    -- 2) Insert mission_run.
    local run_code = string.format("%s_RUN_%d", profile.mission_code, os.time())
    self.db:eval([[
        INSERT INTO mission_run
        (campaign_id, mission_id, run_code, started_at, is_contract_mode)
        VALUES (:cid, :mid, :run_code, :started_at, :contract_mode);
    ]], {
        cid           = profile.campaign_id,
        mid           = mission_id,
        run_code      = run_code,
        started_at    = now_iso8601(),
        contract_mode = profile.is_contract_mode and 1 or 0,
    })

    local run_row = first_row(self.db, "SELECT last_insert_rowid() AS id;", {})
    local mission_run_id = tonumber(run_row.id)

    -- 3) Insert briefing_profile row.
    self.db:eval([[
        INSERT INTO briefing_profile
        (mission_run_id, difficulty_preset, playstyle_preset,
         expected_payout_min, expected_payout_max,
         expected_notoriety_delta_min, expected_notoriety_delta_max)
        VALUES (:run_id, :difficulty, :playstyle, :pay_min, :pay_max, :not_min, :not_max);
    ]], {
        run_id   = mission_run_id,
        difficulty = profile.difficulty_preset or "normal",
        playstyle = profile.playstyle_preset or "unspecified",
        pay_min  = profile.expected_payout_min or 0,
        pay_max  = profile.expected_payout_max or tonumber(mission_row.base_fee) or 0,
        not_min  = profile.expected_notoriety_delta_min or 0,
        not_max  = profile.expected_notoriety_delta_max or 0,
    })

    -- 4) Insert briefing_loadout rows.
    if profile.loadout then
        for _, entry in ipairs(profile.loadout) do
            local item_row = first_row(self.db,
                "SELECT id FROM item_catalog WHERE code = :code;",
                { code = entry.item_code }
            )
            assert(item_row, "Unknown item code: " .. tostring(entry.item_code))
            local item_id = tonumber(item_row.id)

            self.db:eval([[
                INSERT INTO briefing_loadout
                (mission_run_id, item_id, slot_tag, is_stash)
                VALUES (:run_id, :item_id, :slot_tag, :is_stash);
            ]], {
                run_id  = mission_run_id,
                item_id = item_id,
                slot_tag = entry.slot_tag or "misc",
                is_stash = entry.is_stash and 1 or 0,
            })
        end
    end

    return {
        mission_run_id = mission_run_id,
        run_code       = run_code,
        mission_id     = mission_id,
    }
end

------------------------------------------------------------
-- Finalize payment after run completion
------------------------------------------------------------

-- run_outcome:
-- {
--   mission_run_id,
--   result_rating,
--   result_success,
--   unresolved_evidence_score,
--   equipment_outcomes = {
--     { item_code="SUIT_CLASSIC", status="returned"|"lost"|"abandoned"|"confiscated" },
--     ...
--   },
--   notoriety_delta,
--   intel_cost,
--   bribe_cost
-- }
function Briefing.finalize_run_payment(self, run_outcome)
    local mission_run_id = run_outcome.mission_run_id

    -- 1) Mark mission_run completed.
    self.db:eval([[
        UPDATE mission_run
        SET completed_at = :completed_at,
            result_rating = :rating,
            result_success = :success
        WHERE id = :id;
    ]], {
        completed_at = now_iso8601(),
        rating       = run_outcome.result_rating or "Unknown",
        success      = run_outcome.result_success and 1 or 0,
        id           = mission_run_id,
    })

    -- 2) Fetch campaign_id, mission base_fee, current campaign_state.
    local row = first_row(self.db, [[
        SELECT mr.campaign_id AS cid, m.base_fee AS base_fee
        FROM mission_run mr
        JOIN mission m ON mr.mission_id = m.id
        WHERE mr.id = :id;
    ]], { id = mission_run_id })
    assert(row, "Mission run not found for finalize_run_payment")
    local campaign_id = tonumber(row.cid)
    local base_fee = tonumber(row.base_fee) or 0

    local state = first_row(self.db, [[
        SELECT total_funds, notoriety, total_equipment_lost, total_suit_losses
        FROM campaign_state
        WHERE campaign_id = :cid;
    ]], { cid = campaign_id })
    assert(state, "Missing campaign_state for campaign " .. tostring(campaign_id))

    -- 3) Apply equipment outcomes and compute penalties.
    local equipment_loss_penalty = 0
    local suit_loss_penalty = 0

    if run_outcome.equipment_outcomes then
        for _, eo in ipairs(run_outcome.equipment_outcomes) do
            local item_row = first_row(self.db,
                "SELECT id, kind, base_cost FROM item_catalog WHERE code = :code;",
                { code = eo.item_code }
            )
            if item_row then
                local item_id   = tonumber(item_row.id)
                local kind      = item_row.kind
                local base_cost = tonumber(item_row.base_cost) or 0
                local status    = eo.status or "returned"

                self.db:eval([[
                    INSERT INTO run_equipment_outcome
                    (mission_run_id, item_id, status)
                    VALUES (:run_id, :item_id, :status);
                ]], {
                    run_id = mission_run_id,
                    item_id = item_id,
                    status = status,
                })

                if status == "lost" or status == "abandoned" then
                    equipment_loss_penalty = equipment_loss_penalty + base_cost

                    if kind == "suit" then
                        local suit_mult = 2.5 -- heavier penalty for suit losses
                        suit_loss_penalty = suit_loss_penalty + math.floor(base_cost * suit_mult)

                        -- Update campaign_suit_state.
                        self.db:eval([[
                            INSERT INTO campaign_suit_state
                            (campaign_id, item_id, times_used, times_lost, suit_heat)
                            VALUES (:cid, :iid, 1, 1, 10)
                            ON CONFLICT(campaign_id, item_id)
                            DO UPDATE SET
                                times_used = times_used + 1,
                                times_lost = times_lost + 1,
                                suit_heat  = MIN(suit_heat + 10, 100);
                        ]], {
                            cid = campaign_id,
                            iid = item_id,
                        })
                    end
                elseif status == "returned" then
                    if kind == "suit" then
                        self.db:eval([[
                            INSERT INTO campaign_suit_state
                            (campaign_id, item_id, times_used, times_lost, suit_heat)
                            VALUES (:cid, :iid, 1, 0, suit_heat)
                            ON CONFLICT(campaign_id, item_id)
                            DO UPDATE SET
                                times_used = times_used + 1;
                        ]], {
                            cid = campaign_id,
                            iid = item_id,
                        })
                    end
                end
            end
        end
    end

    -- 4) Compute rating / stealth bonuses and notoriety penalty.
    local rating_bonus = 0
    local stealth_bonus = 0
    local notoriety_penalty = 0

    if run_outcome.result_rating == "Silent Assassin" then
        rating_bonus = math.floor(base_fee * 0.5)      -- +50% for perfect runs
        stealth_bonus = math.floor(base_fee * 0.25)    -- extra stealth credit
    end

    if run_outcome.unresolved_evidence_score and run_outcome.unresolved_evidence_score > 0 then
        notoriety_penalty = math.floor(run_outcome.unresolved_evidence_score * 2)
    end

    local intel_cost = run_outcome.intel_cost or 0
    local bribe_cost = run_outcome.bribe_cost or 0

    local gross = base_fee + rating_bonus + stealth_bonus
    local deductions = notoriety_penalty + equipment_loss_penalty + suit_loss_penalty + intel_cost + bribe_cost
    local net_payment = gross - deductions

    -- 5) Insert payment breakdown row.
    self.db:eval([[
        INSERT INTO run_payment_breakdown
        (mission_run_id, base_fee, rating_bonus, stealth_bonus,
         notoriety_penalty, equipment_loss_penalty, suit_loss_penalty,
         intel_cost, bribe_cost, net_payment)
        VALUES (:run_id, :base_fee, :r_bonus, :s_bonus,
                :n_pen, :eq_pen, :suit_pen,
                :intel_cost, :bribe_cost, :net);
    ]], {
        run_id    = mission_run_id,
        base_fee  = base_fee,
        r_bonus   = rating_bonus,
        s_bonus   = stealth_bonus,
        n_pen     = notoriety_penalty,
        eq_pen    = equipment_loss_penalty,
        suit_pen  = suit_loss_penalty,
        intel_cost = intel_cost,
        bribe_cost = bribe_cost,
        net       = net_payment,
    })

    -- 6) Update campaign_state.
    local new_funds = (tonumber(state.total_funds) or 0) + net_payment
    local new_notoriety = (tonumber(state.notoriety) or 0) + (run_outcome.notoriety_delta or 0)

    self.db:eval([[
        UPDATE campaign_state
        SET total_funds = :funds,
            notoriety   = MAX(MIN(:notoriety, 100), 0),
            total_missions_completed = total_missions_completed + 1,
            total_equipment_lost = total_equipment_lost + :eq_lost,
            total_suit_losses    = total_suit_losses + :suit_lost
        WHERE campaign_id = :cid;
    ]], {
        funds      = new_funds,
        notoriety  = new_notoriety,
        eq_lost    = equipment_loss_penalty > 0 and 1 or 0,
        suit_lost  = suit_loss_penalty > 0 and 1 or 0,
        cid        = campaign_id,
    })

    return {
        net_payment          = net_payment,
        base_fee             = base_fee,
        rating_bonus         = rating_bonus,
        stealth_bonus        = stealth_bonus,
        notoriety_penalty    = notoriety_penalty,
        equipment_loss_penalty = equipment_loss_penalty,
        suit_loss_penalty    = suit_loss_penalty,
        intel_cost           = intel_cost,
        bribe_cost           = bribe_cost,
        new_total_funds      = new_funds,
        new_notoriety        = new_notoriety,
    }
end

return Briefing
