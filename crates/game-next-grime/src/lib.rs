#![feature(rust_2024_preview)]

use rusqlite::{params, Connection, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GrimeParams {
    pub wetness: f32,
    pub mud: f32,
    pub soot: f32,
    pub dust: f32,
    pub tear_intensity: f32,
    pub roughness: f32,
    pub porosity: f32,
    pub flow_dir_x: f32,
    pub flow_dir_y: f32,
    pub stretch_dir_x: f32,
    pub stretch_dir_y: f32,
}

#[derive(Debug, Clone, Copy, Serialize, Deserialize)]
pub struct GrimeInvariants {
    #[serde(rename = "CIC")]
    pub cic: f32,
    #[serde(rename = "AOS")]
    pub aos: f32,
    #[serde(rename = "DET")]
    pub det: f32,
    #[serde(rename = "LSG")]
    pub lsg: f32,
}

#[derive(Debug, Clone, Copy)]
pub struct GrimeExposure {
    pub rain_intensity: f32,
    pub mud_contact: f32,
    pub dust_contact: f32,
    pub fire_soot: f32,
    pub slide_friction: f32,
    pub time_since_clean_sec: f32,
    pub movement_speed: f32,
}

#[inline]
fn clamp01(v: f32) -> f32 {
    v.max(0.0).min(1.0)
}

#[inline]
fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

fn compute_system_health_gate(inv: &GrimeInvariants) -> f32 {
    let cic = clamp01(inv.cic);
    let det = clamp01(inv.det);
    let health = clamp01(0.5 * cic + 0.5 * det);
    lerp(0.6, 1.0, health)
}

fn compute_latency_guard(inv: &GrimeInvariants) -> f32 {
    let guard = clamp01(inv.lsg);
    lerp(1.0, 0.7, guard)
}

pub fn integrate_grime(
    prev: &GrimeParams,
    exposure: &GrimeExposure,
    inv: &GrimeInvariants,
    dt: f32,
) -> GrimeParams {
    let t = dt.max(0.0);

    let wet_rate = clamp01(exposure.rain_intensity * 0.9 + exposure.mud_contact * 0.5);
    let mud_rate = clamp01(exposure.mud_contact * 0.8 + exposure.slide_friction * 0.4);
    let soot_rate = clamp01(exposure.fire_soot * 0.9 + exposure.dust_contact * 0.3);
    let tear_rate = clamp01(exposure.slide_friction * 0.7);

    let natural_dry = clamp01(t * 0.05);
    let natural_clean = clamp01(t * 0.02);

    let mut next = *prev;

    let wet_grow = wet_rate * t;
    let wet_decay = natural_dry * (1.0 - exposure.rain_intensity);
    next.wetness = clamp01(prev.wetness + wet_grow - wet_decay);

    let mud_grow = mud_rate * t;
    let mud_decay = clamp01((exposure.rain_intensity * 0.4 + exposure.movement_speed * 0.2) * t);
    next.mud = clamp01(prev.mud + mud_grow - mud_decay);

    let soot_grow = soot_rate * t;
    let soot_decay = clamp01(exposure.rain_intensity * 0.3 * t);
    next.soot = clamp01(prev.soot + soot_grow - soot_decay);

    let dust_grow = clamp01(exposure.dust_contact * 0.6 * t);
    let dust_decay = clamp01(exposure.rain_intensity * 0.5 * t);
    next.dust = clamp01(prev.dust + dust_grow - dust_decay);

    let tear_grow = tear_rate * t + clamp01(exposure.time_since_clean_sec / 600.0) * 0.1 * t;
    let tear_decay = natural_clean * 0.25;
    next.tear_intensity = clamp01(prev.tear_intensity + tear_grow - tear_decay);

    next.roughness = clamp01(0.5 + next.mud * 0.3 + next.soot * 0.2);
    next.porosity = clamp01(prev.porosity);

    next.flow_dir_x = 0.0;
    next.flow_dir_y = -1.0;
    next.stretch_dir_x = if exposure.movement_speed > 0.1 { 1.0 } else { prev.stretch_dir_x };
    next.stretch_dir_y = 0.0;

    let flow_len = (next.flow_dir_x * next.flow_dir_x + next.flow_dir_y * next.flow_dir_y).sqrt().max(0.0001);
    next.flow_dir_x /= flow_len;
    next.flow_dir_y /= flow_len;

    let stretch_len = (next.stretch_dir_x * next.stretch_dir_x + next.stretch_dir_y * next.stretch_dir_y).sqrt().max(0.0001);
    next.stretch_dir_x /= stretch_len;
    next.stretch_dir_y /= stretch_len;

    let system_gate = compute_system_health_gate(inv);
    let latency_gate = compute_latency_guard(inv);
    let gate = system_gate * latency_gate;

    next.wetness *= gate;
    next.mud *= gate;
    next.soot *= gate;
    next.dust *= gate;
    next.tear_intensity *= gate;

    next
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GrimeFrame {
    pub frame_ts_ms: i64,
    pub session_id: String,
    pub character_id: String,
    pub map_name: String,
    pub cic: f32,
    pub aos: f32,
    pub det: f32,
    pub lsg: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GrimeBinding {
    pub frame_id: i64,
    pub binding_key: String,
    pub region: String,
    pub wetness: f32,
    pub mud: f32,
    pub soot: f32,
    pub dust: f32,
    pub tear_intensity: f32,
    pub roughness: f32,
    pub porosity: f32,
    pub flow_dir_x: f32,
    pub flow_dir_y: f32,
    pub stretch_dir_x: f32,
    pub stretch_dir_y: f32,
}

pub fn init_grime_schema(conn: &Connection) -> Result<()> {
    conn.execute_batch(
        r#"
        PRAGMA foreign_keys = ON;
        PRAGMA journal_mode = WAL;

        CREATE TABLE IF NOT EXISTS grime_frame (
            frame_id      INTEGER PRIMARY KEY AUTOINCREMENT,
            frame_ts_ms   INTEGER NOT NULL,
            session_id    TEXT    NOT NULL,
            character_id  TEXT    NOT NULL,
            map_name      TEXT    NOT NULL,
            cic           REAL    NOT NULL CHECK (cic BETWEEN 0.0 AND 1.0),
            aos           REAL    NOT NULL CHECK (aos BETWEEN 0.0 AND 1.0),
            det           REAL    NOT NULL CHECK (det BETWEEN 0.0 AND 1.0),
            lsg           REAL    NOT NULL CHECK (lsg BETWEEN 0.0 AND 1.0)
        );

        CREATE INDEX IF NOT EXISTS idx_grime_frame_session_ts
            ON grime_frame (session_id, frame_ts_ms);
        CREATE INDEX IF NOT EXISTS idx_grime_frame_char
            ON grime_frame (character_id, frame_ts_ms);

        CREATE TABLE IF NOT EXISTS grime_binding (
            binding_id       INTEGER PRIMARY KEY AUTOINCREMENT,
            frame_id         INTEGER NOT NULL REFERENCES grime_frame(frame_id) ON DELETE CASCADE,
            binding_key      TEXT    NOT NULL,
            region           TEXT    NOT NULL,
            wetness          REAL    NOT NULL CHECK (wetness BETWEEN 0.0 AND 1.0),
            mud              REAL    NOT NULL CHECK (mud BETWEEN 0.0 AND 1.0),
            soot             REAL    NOT NULL CHECK (soot BETWEEN 0.0 AND 1.0),
            dust             REAL    NOT NULL CHECK (dust BETWEEN 0.0 AND 1.0),
            tear_intensity   REAL    NOT NULL CHECK (tear_intensity BETWEEN 0.0 AND 1.0),
            roughness        REAL    NOT NULL CHECK (roughness BETWEEN 0.0 AND 1.0),
            porosity         REAL    NOT NULL CHECK (porosity BETWEEN 0.0 AND 1.0),
            flow_dir_x       REAL    NOT NULL CHECK (flow_dir_x BETWEEN -1.0 AND 1.0),
            flow_dir_y       REAL    NOT NULL CHECK (flow_dir_y BETWEEN -1.0 AND 1.0),
            stretch_dir_x    REAL    NOT NULL CHECK (stretch_dir_x BETWEEN -1.0 AND 1.0),
            stretch_dir_y    REAL    NOT NULL CHECK (stretch_dir_y BETWEEN -1.0 AND 1.0)
        );

        CREATE INDEX IF NOT EXISTS idx_grime_binding_frame_region
            ON grime_binding (frame_id, region);
        CREATE INDEX IF NOT EXISTS idx_grime_binding_key
            ON grime_binding (binding_key);

        CREATE VIEW IF NOT EXISTS v_recent_grime AS
        SELECT 
            f.frame_id,
            f.frame_ts_ms,
            f.character_id,
            f.map_name,
            b.region,
            b.wetness,
            b.mud,
            b.soot,
            b.tear_intensity,
            f.lsg
        FROM grime_frame f
        JOIN grime_binding b ON f.frame_id = b.frame_id
        ORDER BY f.frame_ts_ms DESC
        LIMIT 1000;
        "#,
    )?;
    Ok(())
}

pub fn insert_grime_frame(conn: &Connection, frame: &GrimeFrame) -> Result<i64> {
    conn.execute(
        r#"INSERT INTO grime_frame (
            frame_ts_ms, session_id, character_id, map_name,
            cic, aos, det, lsg
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)"#,
        params![
            frame.frame_ts_ms,
            frame.session_id,
            frame.character_id,
            frame.map_name,
            frame.cic,
            frame.aos,
            frame.det,
            frame.lsg
        ],
    )?;
    Ok(conn.last_insert_rowid())
}

pub fn insert_grime_binding(conn: &Connection, binding: &GrimeBinding) -> Result<i64> {
    conn.execute(
        r#"INSERT INTO grime_binding (
            frame_id, binding_key, region,
            wetness, mud, soot, dust, tear_intensity,
            roughness, porosity,
            flow_dir_x, flow_dir_y,
            stretch_dir_x, stretch_dir_y
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14)"#,
        params![
            binding.frame_id,
            binding.binding_key,
            binding.region,
            binding.wetness,
            binding.mud,
            binding.soot,
            binding.dust,
            binding.tear_intensity,
            binding.roughness,
            binding.porosity,
            binding.flow_dir_x,
            binding.flow_dir_y,
            binding.stretch_dir_x,
            binding.stretch_dir_y
        ],
    )?;
    Ok(conn.last_insert_rowid())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_grime_integration_basic() {
        let prev = GrimeParams {
            wetness: 0.0, mud: 0.0, soot: 0.0, dust: 0.0,
            tear_intensity: 0.0, roughness: 0.5, porosity: 0.7,
            flow_dir_x: 0.0, flow_dir_y: -1.0,
            stretch_dir_x: 0.0, stretch_dir_y: 0.0,
        };
        let exposure = GrimeExposure {
            rain_intensity: 0.8,
            mud_contact: 0.3,
            dust_contact: 0.0,
            fire_soot: 0.0,
            slide_friction: 0.0,
            time_since_clean_sec: 0.0,
            movement_speed: 0.0,
        };
        let inv = GrimeInvariants { cic: 0.9, aos: 0.85, det: 0.9, lsg: 0.7 };
        
        let next = integrate_grime(&prev, &exposure, &inv, 1.0);
        
        assert!(next.wetness > 0.0);
        assert!(next.mud >= 0.0);
        assert_eq!(next.flow_dir_y, -1.0);
    }

    #[test]
    fn test_schema_init() {
        let conn = Connection::open_in_memory().unwrap();
        init_grime_schema(&conn).unwrap();
        
        let count: i64 = conn
            .query_row("SELECT COUNT(*) FROM sqlite_master WHERE type='table'", [], |r| r.get(0))
            .unwrap();
        assert!(count >= 2);
    }
}
