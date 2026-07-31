-- lua/token_ai/suspicion_engine.lua
-- Token-AI Suspicion Engine
-- Pluggable heuristic core for evaluating "observer suspicion" about an agent/user.
-- Designed for integration into AI-chat tools and multi-agent simulations.

local SuspicionEngine = {}

-- ObserverContext models the perspective of a watcher (NPC, system monitor, moderator, etc.).
-- Fields:
--   npc_id            : numeric identifier for the observer instance
--   is_enforcer       : boolean, true if observer has enforcement powers (moderator, guard)
--   base_suspicion    : baseline suspicion level (lower bound)
--   current_suspicion : mutable, current suspicion value
--   max_suspicion     : upper bound for suspicion
function SuspicionEngine.new_observer_context(opts)
    return {
        npc_id = opts.npc_id or 0,
        is_enforcer = opts.is_enforcer or false,
        base_suspicion = opts.base_suspicion or 0.0,
        current_suspicion = opts.current_suspicion or (opts.base_suspicion or 0.0),
        max_suspicion = opts.max_suspicion or 100.0,
    }
end

-- PlayerState models the state of the agent being observed.
-- This can represent a game player, a chat user, or any controlled entity.
-- Fields:
--   disguise_tag              : semantic role or declared identity (e.g., "security_heavy", "waiter", "new_user")
--   is_in_restricted_area     : boolean, true if agent is operating in a sensitive scope
--   is_committing_illegal_action : boolean, flag for active violation (policy breach, exploit attempt)
--   held_item_tag             : optional tag for the active tool/object (e.g., "rifle_unsilenced", "exploit_script")
--   notoriety                 : 0.0 - 100.0, representing past offenses or risk profile
function SuspicionEngine.new_player_state(opts)
    return {
        disguise_tag = opts.disguise_tag or "",
        is_in_restricted_area = opts.is_in_restricted_area or false,
        is_committing_illegal_action = opts.is_committing_illegal_action or false,
        held_item_tag = opts.held_item_tag or nil,
        notoriety = opts.notoriety or 0.0,
    }
end

local function clamp(value, min_value, max_value)
    if value < min_value then
        return min_value
    elseif value > max_value then
        return max_value
    else
        return value
    end
end

-- Data-driven legality matrix.
-- This is intentionally simple and local; in a full Token-AI deployment, this
-- can be replaced by a configuration loader (JSON, SQLite, or remote policy).
--
-- Keys are disguise_tags, values are sets of allowed item_tags.
-- Any item_tag not present in the allowed set is treated as illegal for that disguise.
local LEGAL_ITEMS_BY_DISGUISE = {
    security_heavy = {
        rifle_unsilenced = true,
        rifle_silenced = true,
        shotgun = true,
        baton = true,
    },
    waiter = {
        tray = true,
        menu = true,
        notepad = true,
    },
    researcher = {
        tablet = true,
        laptop = true,
        notes = true,
    },
}

local function is_illegal_item_for_disguise(item_tag, disguise_tag)
    if disguise_tag == nil or disguise_tag == "" then
        -- No disguise: treat all items as legal. Token-AI can adjust this via config.
        return false
    end

    local allowed_items = LEGAL_ITEMS_BY_DISGUISE[disguise_tag]
    if not allowed_items then
        -- Unknown disguise: conservative rule, treat item as legal but logable.
        return false
    end

    -- If item is not explicitly allowed, treat it as illegal for this disguise.
    return allowed_items[item_tag] ~= true
end

-- Core heuristic:
--   update_suspicion(observer, player, in_line_of_sight, delta_time)
--
-- This function mutates observer.current_suspicion and returns its new value.
-- The heuristic is time-scaled (delta_time) and integrates several inputs:
--   - line of sight (direct observation vs decay)
--   - contextual illegality (restricted area, illegal action)
--   - item legality relative to disguise
--   - enforcer amplification
--   - notoriety scaling (more notorious agents accumulate suspicion faster)
function SuspicionEngine.update_suspicion(observer, player, in_line_of_sight, delta_time)
    local change = 0.0

    if in_line_of_sight then
        -- Base curiosity.
        change = change + 0.5

        -- Illegal context.
        if player.is_in_restricted_area then
            change = change + 2.0
        end
        if player.is_committing_illegal_action then
            change = change + 4.0
        end

        -- Illegal item heuristic (e.g., unsilenced rifle, explosives).
        if player.held_item_tag ~= nil then
            if is_illegal_item_for_disguise(player.held_item_tag, player.disguise_tag) then
                change = change + 3.0
            end
        end

        -- Enforcers and notoriety scale.
        if observer.is_enforcer then
            change = change * 1.5
        end

        local notoriety_scale = 1.0 + (player.notoriety / 150.0)
        change = change * notoriety_scale
    else
        -- Decay when out of sight.
        change = change - 1.5
    end

    local next_suspicion = observer.current_suspicion + (change * delta_time)
    observer.current_suspicion = clamp(next_suspicion, observer.base_suspicion, observer.max_suspicion)
    return observer.current_suspicion
end

-- Example adapter: compute suspicion delta for a generic AI-chat "interaction context".
-- This is a convenience API that translates chat/system fields into PlayerState/ObserverContext.
--
-- Input:
--   interaction = {
--       user_id             = <number|string>,
--       role_tag            = <string>,   -- e.g., "new_user", "expert", "moderator_undercover"
--       in_sensitive_channel = <bool>,    -- maps to is_in_restricted_area
--       violating_policy    = <bool>,     -- maps to is_committing_illegal_action
--       tool_tag            = <string|nil>, -- maps to held_item_tag
--       risk_score          = <number>,  -- 0.0 - 100.0, maps to notoriety
--   }
--   observer = ObserverContext
--   in_direct_focus = boolean, true if system is currently "watching" this interaction
--   delta_time = number, e.g., seconds or normalized time step
function SuspicionEngine.update_from_interaction(interaction, observer, in_direct_focus, delta_time)
    local player = SuspicionEngine.new_player_state({
        disguise_tag = interaction.role_tag or "",
        is_in_restricted_area = interaction.in_sensitive_channel or false,
        is_committing_illegal_action = interaction.violating_policy or false,
        held_item_tag = interaction.tool_tag or nil,
        notoriety = interaction.risk_score or 0.0,
    })

    return SuspicionEngine.update_suspicion(observer, player, in_direct_focus, delta_time)
end

-- Export module.
return SuspicionEngine
