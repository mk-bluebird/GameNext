// File: crates/game-next-bci-geometry/src/lib.rs
// Destination: GameNext/crates/game-next-bci-geometry/src/lib.rs

#![feature(rust_2024_preview)]

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BciSummary {
    pub stress_score: f32,
    pub stress_band: StressBand,
    pub attention_band: AttentionBand,
    pub visual_overload_index: f32,
    pub startle_spike: f32,
    pub signal_quality: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum StressBand {
    Low,
    Mid,
    High,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum AttentionBand {
    Drifting,
    Focused,
    Locked,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Invariants {
    pub cic: f32,
    pub aos: f32,
    pub det: f32,
    pub lsg: f32,
    #[serde(default)]
    pub uec: Option<f32>,
    #[serde(default)]
    pub emd: Option<f32>,
    #[serde(default)]
    pub stci: Option<f32>,
    #[serde(default)]
    pub cdl: Option<f32>,
    #[serde(default)]
    pub arr: Option<f32>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiBciGeometryRequestV1 {
    pub version: String,
    pub experience_type: String,
    pub region_hints: RegionHints,
    pub bci_summary: BciSummary,
    pub invariants: Invariants,
    #[serde(default)]
    pub meta: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct RegionHints {
    pub style: String,
    #[serde(default)]
    pub locale: Option<String>,
    #[serde(default)]
    pub platform: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct VisualParams {
    pub mask_radius: f32,
    pub mask_feather: f32,
    pub decay_grain: f32,
    pub color_desat: f32,
    pub vein_overlay: f32,
    pub motion_smear: f32,
    #[serde(default)]
    pub palette_hex: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AudioParams {
    pub infected_channel_gain: f32,
    pub squad_muffle: f32,
    pub heartbeat_gain: f32,
    pub breath_gain: f32,
    pub ringing_level: f32,
    pub direct: f32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BciGeometryBindingV1 {
    pub id: String,
    pub region: String,
    pub gates: Invariants,
    pub visual: VisualParams,
    pub audio: AudioParams,
    #[serde(default)]
    pub meta: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct AiBciGeometryResponseV1 {
    pub version: String,
    pub experience_type: String,
    pub bindings: Vec<BciGeometryBindingV1>,
    #[serde(default)]
    pub meta: serde_json::Value,
}

fn clamp01(v: f32) -> f32 {
    v.clamp(0.0, 1.0)
}

fn stress_band_weight(band: &StressBand) -> f32 {
    match band {
        StressBand::Low => 0.15,
        StressBand::Mid => 0.55,
        StressBand::High => 0.9,
    }
}

fn attention_focus_weight(band: &AttentionBand) -> f32 {
    match band {
        AttentionBand::Drifting => 0.2,
        AttentionBand::Focused => 0.6,
        AttentionBand::Locked => 0.9,
    }
}

fn compute_quality_guard(signal_quality: f32, threshold: f32) -> f32 {
    let sq = clamp01(signal_quality);
    if sq >= threshold {
        1.0
    } else {
        clamp01(sq / threshold)
    }
}

fn apply_quality_guard_visual(v: &mut VisualParams, guard: f32) {
    let neutral_mask_radius = 0.95;
    let neutral_mask_feather = 0.6;
    v.mask_radius = 0.95 + (v.mask_radius - 0.95) * guard;
    v.mask_feather = 0.6 + (v.mask_feather - 0.6) * guard;
    v.decay_grain *= guard;
    v.color_desat *= guard;
    v.vein_overlay *= guard;
    v.motion_smear *= guard;
    v.mask_radius = v.mask_radius.clamp(0.02, 1.0);
    let _ = neutral_mask_radius;
    let _ = neutral_mask_feather;
}

fn apply_quality_guard_audio(a: &mut AudioParams, guard: f32) {
    a.infected_channel_gain *= guard;
    a.squad_muffle *= guard;
    a.heartbeat_gain *= guard;
    a.breath_gain *= guard;
    a.ringing_level *= guard;
    a.direct = a.direct.max(0.5_f32.min(a.direct + (1.0 - guard) * 0.1));
}

fn compute_system_health_gate(inv: &Invariants) -> f32 {
    let cic = clamp01(inv.cic);
    let det = clamp01(inv.det);
    let health = clamp01(0.5 * cic + 0.5 * det);
    0.6 + 0.4 * health
}

fn apply_system_health_gate(v: &mut VisualParams, a: &mut AudioParams, inv: &Invariants) {
    let gate = compute_system_health_gate(inv);
    v.decay_grain *= gate;
    v.motion_smear *= gate;
    a.infected_channel_gain *= gate;
    a.heartbeat_gain *= gate;
    a.ringing_level *= gate;
}

pub fn compute_visual_params(
    bci: &BciSummary,
    inv: &Invariants,
) -> VisualParams {
    let sbw = stress_band_weight(&bci.stress_band);
    let afw = attention_focus_weight(&bci.attention_band);

    let mut v = VisualParams {
        mask_radius: clamp01(0.95 - 0.55 * bci.stress_score - 0.35 * bci.visual_overload_index),
        mask_feather: clamp01(0.6 - 0.35 * bci.stress_score + 0.2 * (1.0 - bci.visual_overload_index)),
        decay_grain: clamp01(0.2 + 0.7 * bci.stress_score + 0.3 * sbw),
        color_desat: clamp01(0.25 + 0.55 * bci.stress_score + 0.2 * bci.visual_overload_index),
        vein_overlay: clamp01(0.3 + 0.5 * bci.stress_score + 0.4 * clamp01(bci.startle_spike)),
        motion_smear: clamp01(0.15 + 0.4 * bci.visual_overload_index + 0.25 * (1.0 - afw) + 0.15 * bci.startle_spike),
        palette_hex: Vec::new(),
    };

    let guard = compute_quality_guard(bci.signal_quality, 0.3);
    apply_quality_guard_visual(&mut v, guard);
    let mut audio_dummy = AudioParams {
        infected_channel_gain: 0.0,
        squad_muffle: 0.0,
        heartbeat_gain: 0.0,
        breath_gain: 0.0,
        ringing_level: 0.0,
        direct: 1.0,
    };
    apply_system_health_gate(&mut v, &mut audio_dummy, inv);

    v
}

pub fn compute_audio_params(
    bci: &BciSummary,
    inv: &Invariants,
) -> AudioParams {
    let afw = attention_focus_weight(&bci.attention_band);

    let mut a = AudioParams {
        infected_channel_gain: clamp01(0.3 + 0.7 * bci.stress_score + 0.3 * bci.startle_spike),
        squad_muffle: clamp01(0.2 + 0.6 * bci.visual_overload_index + 0.2 * bci.stress_score),
        heartbeat_gain: clamp01(0.25 + 0.6 * bci.stress_score + 0.3 * bci.startle_spike),
        breath_gain: {
            let base = clamp01(0.2 + 0.5 * bci.stress_score + 0.3 * (1.0 - afw));
            base * clamp01(bci.signal_quality)
        },
        ringing_level: clamp01(0.1 + 0.7 * bci.visual_overload_index + 0.2 * (1.0 - bci.signal_quality)),
        direct: clamp01(0.9 - 0.5 * bci.stress_score - 0.3 * bci.visual_overload_index),
    };

    let guard = compute_quality_guard(bci.signal_quality, 0.3);
    apply_quality_guard_audio(&mut a, guard);
    let mut visual_dummy = VisualParams {
        mask_radius: 0.95,
        mask_feather: 0.6,
        decay_grain: 0.0,
        color_desat: 0.0,
        vein_overlay: 0.0,
        motion_smear: 0.0,
        palette_hex: Vec::new(),
    };
    apply_system_health_gate(&mut visual_dummy, &mut a, inv);

    a
}

pub fn handle_ai_bci_geometry_request(
    req: AiBciGeometryRequestV1,
) -> AiBciGeometryResponseV1 {
    let visual = compute_visual_params(&req.bci_summary, &req.invariants);
    let audio = compute_audio_params(&req.bci_summary, &req.invariants);

    let binding = BciGeometryBindingV1 {
        id: "game-next-default-region".to_string(),
        region: "foveal".to_string(),
        gates: req.invariants.clone(),
        visual,
        audio,
        meta: serde_json::json!({
            "style": req.region_hints.style,
            "geometryVersion": "game-next-v1"
        }),
    };

    AiBciGeometryResponseV1 {
        version: "v1".to_string(),
        experience_type: req.experience_type,
        bindings: vec![binding],
        meta: serde_json::json!({
            "mappingVersion": "game-next-v1"
        }),
    }
}
