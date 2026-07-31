local M = {}

local ALLOWED_ASPECTS = {
  governance = true,
  telemetry = true,
  infrastructure = true
}

local ALLOWED_ANALYSIS_LEVELS = {
  ["technical-implementation"] = true,
  ["system-behavior"] = true
}

local ALLOWED_ASSESSMENT_TYPES = {
  ["internal-coherence"] = true,
  ["external-comparison"] = true,
  ["deployment-guidance"] = true
}

local function utc_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function validate_choice(value, allowed)
  return type(value) == "string" and allowed[value] == true
end

function M.default_profile()
  return {
    focus_aspect = "governance",
    analysis_level = "technical-implementation",
    assessment_type = "internal-coherence",
    deployment_hint = nil,
    notes = nil
  }
end

function M.make_profile(opts)
  local p = M.default_profile()

  if type(opts) == "table" then
    if opts.focus_aspect and validate_choice(opts.focus_aspect, ALLOWED_ASPECTS) then
      p.focus_aspect = opts.focus_aspect
    end
    if opts.analysis_level and validate_choice(opts.analysis_level, ALLOWED_ANALYSIS_LEVELS) then
      p.analysis_level = opts.analysis_level
    end
    if opts.assessment_type and validate_choice(opts.assessment_type, ALLOWED_ASSESSMENT_TYPES) then
      p.assessment_type = opts.assessment_type
    end
    if opts.deployment_hint and type(opts.deployment_hint) == "string" then
      p.deployment_hint = opts.deployment_hint
    end
    if opts.notes and type(opts.notes) == "string" then
      p.notes = opts.notes
    end
  end

  return p
end

function M.to_insert_sql(profile)
  local created = utc_timestamp()
  local updated = created

  local function sql_escape(s)
    return "'" .. s:gsub("'", "''") .. "'"
  end

  local focus_aspect = sql_escape(profile.focus_aspect)
  local analysis_level = sql_escape(profile.analysis_level)
  local assessment_type = sql_escape(profile.assessment_type)
  local deployment_hint = profile.deployment_hint and sql_escape(profile.deployment_hint) or "NULL"
  local notes = profile.notes and sql_escape(profile.notes) or "NULL"

  local created_sql = sql_escape(created)
  local updated_sql = sql_escape(updated)

  local sql = table.concat({
    "INSERT INTO tokenai_research_focus (",
    "created_at_utc, updated_at_utc, ",
    "focus_aspect, analysis_level, assessment_type, ",
    "deployment_hint, notes",
    ") VALUES (",
    created_sql, ", ",
    updated_sql, ", ",
    focus_aspect, ", ",
    analysis_level, ", ",
    assessment_type, ", ",
    deployment_hint, ", ",
    notes,
    ");"
  })

  return sql
end

return M
