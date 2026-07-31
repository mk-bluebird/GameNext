PRAGMA foreign_keys = ON;

-- Core table capturing high-level research focus choices for Token-AI
CREATE TABLE IF NOT EXISTS tokenai_research_focus (
    focus_id              INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at_utc        TEXT NOT NULL,
    updated_at_utc        TEXT NOT NULL,

    -- Q1: primary aspect to prioritize
    focus_aspect          TEXT NOT NULL CHECK (
        focus_aspect IN (
            'governance',
            'telemetry',
            'infrastructure'
        )
    ),

    -- Q2: analysis lens
    analysis_level        TEXT NOT NULL CHECK (
        analysis_level IN (
            'technical-implementation',
            'system-behavior'
        )
    ),

    -- Q3: assessment type
    assessment_type       TEXT NOT NULL CHECK (
        assessment_type IN (
            'internal-coherence',
            'external-comparison',
            'deployment-guidance'
        )
    ),

    -- Optional: specific deployment or repo target (e.g., Horror$Place, Rotting-Visuals-BCI)
    deployment_hint       TEXT,

    -- Optional notes for more granular description (e.g., “BCI geometry bindings”, “CAN token registry”)
    notes                 TEXT
);

CREATE INDEX IF NOT EXISTS idx_tokenai_focus_created
    ON tokenai_research_focus (created_at_utc);

CREATE INDEX IF NOT EXISTS idx_tokenai_focus_aspect
    ON tokenai_research_focus (focus_aspect);

CREATE INDEX IF NOT EXISTS idx_tokenai_focus_assessment
    ON tokenai_research_focus (assessment_type);
