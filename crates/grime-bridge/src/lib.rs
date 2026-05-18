// File: crates/grime-bridge/src/lib.rs
// Destination: GameNext/grime-bridge (Rust 2024 component for Bevy ↔ engine interop)

#![feature(rust_2024_preview)]

use bevy::ecs::system::SystemParam;
use bevy::prelude::*;

/// Grime parameters for a single character/material region.
/// These are normalized scalars in [0.0, 1.0] plus unit vectors for flow/stretch,
/// mirroring the RVBCI VisualParams style but specialized for grime.[file:2]
#[derive(Debug, Clone, Copy, Component, Reflect)]
#[reflect(Component)]
pub struct GrimeParams {
    pub wetness: f32,
    pub mud: f32,
    pub soot: f32,
    pub tear_intensity: f32,
    pub flow_dir: Vec2,
    pub stretch_dir: Vec2,
}

impl Default for GrimeParams {
    fn default() -> Self {
        Self {
            wetness: 0.0,
            mud: 0.0,
            soot: 0.0,
            tear_intensity: 0.0,
            flow_dir: Vec2::new(0.0, -1.0),
            stretch_dir: Vec2::X,
        }
    }
}

/// Invariant-style gates, analogous to CIC/AOS/DET/LSG,
/// used here as system-health and safety dampers on grime intensity.[file:2]
#[derive(Debug, Clone, Copy, Component, Reflect)]
#[reflect(Component)]
pub struct GrimeInvariants {
    pub cic: f32,
    pub aos: f32,
    pub det: f32,
    pub lsg: f32,
}

impl Default for GrimeInvariants {
    fn default() -> Self {
        Self {
            cic: 1.0,
            aos: 1.0,
            det: 1.0,
            lsg: 0.0,
        }
    }
}

fn clamp01(v: f32) -> f32 {
    v.clamp(0.0, 1.0)
}

fn lerp(a: f32, b: f32, t: f32) -> f32 {
    a + (b - a) * t
}

/// Compute a system-health gate from CIC/DET, mirroring RVBCI audio gating.[file:2]
fn compute_system_health_gate(inv: &GrimeInvariants) -> f32 {
    let cic = clamp01(inv.cic);
    let det = clamp01(inv.det);
    let health = clamp01(0.5 * cic + 0.5 * det);
    lerp(0.6, 1.0, health)
}

/// Compute a latency guard from LSG, used to damp extremes when latency safety is high.[file:2]
fn compute_latency_guard(inv: &GrimeInvariants) -> f32 {
    let guard = clamp01(inv.lsg);
    // High LSG → stronger safety → more damping.
    lerp(1.0, 0.7, guard)
}

/// Bevy material that exposes grime parameters as shader-accessible uniforms.
/// On UE5 side, you would mirror these as scalar/vec2 material parameters and
/// feed matching values through an FFI or bridge layer.[file:2]
#[derive(AsBindGroup, Debug, Clone, TypePath)]
pub struct GrimeMaterial {
    #[uniform(0)]
    pub wetness: f32,
    #[uniform(0)]
    pub mud: f32,
    #[uniform(0)]
    pub soot: f32,
    #[uniform(0)]
    pub tear_intensity: f32,
    #[uniform(0)]
    pub flow_dir: Vec2,
    #[uniform(0)]
    pub stretch_dir: Vec2,
}

impl Material for GrimeMaterial {
    fn fragment_shader() -> bevy::render::render_resource::ShaderRef {
        // Shader file path is engine-side; here we assume a grime fragment shader
        // that takes these uniforms and blends mud/wet/soot layers similar to RVBCI shaders.[file:2]
        "shaders/grime_layer.wgsl".into()
    }
}

/// Aggregated exposure inputs per frame for grime integration.
#[derive(Debug, Clone, Copy, Component, Reflect)]
#[reflect(Component)]
pub struct GrimeExposure {
    pub rain_intensity: f32,
    pub mud_contact: f32,
    pub dust_contact: f32,
    pub fire_soot: f32,
    pub slide_friction: f32,
    pub time_since_clean_sec: f32,
    pub movement_speed: f32,
}

impl Default for GrimeExposure {
    fn default() -> Self {
        Self {
            rain_intensity: 0.0,
            mud_contact: 0.0,
            dust_contact: 0.0,
            fire_soot: 0.0,
            slide_friction: 0.0,
            time_since_clean_sec: 0.0,
            movement_speed: 0.0,
        }
    }
}

/// SystemParam bundle for grime update systems.
#[derive(SystemParam)]
pub struct GrimeContext<'w, 's> {
    pub materials: ResMut<'w, Assets<GrimeMaterial>>,
    pub time: Res<'w, Time>,
    pub _marker: std::marker::PhantomData<&'s ()>,
}

/// Integrate grime based on exposure and invariants, following the same
/// pattern as RVBCI VisualParams: normalized scalars, clamped, gated.[file:2]
fn integrate_grime(
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

    let tear_grow =
        tear_rate * t + clamp01(exposure.time_since_clean_sec / 600.0) * 0.1 * t;
    let tear_decay = natural_clean * 0.25;
    next.tear_intensity = clamp01(prev.tear_intensity + tear_grow - tear_decay);

    next.flow_dir = Vec2::new(0.0, -1.0);
    next.stretch_dir = if exposure.movement_speed > 0.1 {
        Vec2::X
    } else {
        prev.stretch_dir
    };
    if let Some(flow) = next.flow_dir.try_normalize() {
        next.flow_dir = flow;
    }
    if let Some(stretch) = next.stretch_dir.try_normalize() {
        next.stretch_dir = stretch;
    }

    let system_gate = compute_system_health_gate(inv);
    let latency_gate = compute_latency_guard(inv);
    let gate = system_gate * latency_gate;

    next.wetness *= gate;
    next.mud *= gate;
    next.soot *= gate;
    next.tear_intensity *= gate;

    next
}

/// System: update GrimeParams from GrimeExposure + GrimeInvariants every frame.
pub fn grime_integration_system(
    time: Res<Time>,
    mut query: Query<(&mut GrimeParams, &GrimeExposure, &GrimeInvariants)>,
) {
    let dt = time.delta_secs();
    for (mut grime, exposure, inv) in query.iter_mut() {
        let next = integrate_grime(&*grime, exposure, inv, dt);
        *grime = next;
    }
}

/// System: push GrimeParams into Bevy GrimeMaterial instances.
/// This mirrors RVBCI’s “GLSL uniform mapping” section: a single binding sends
/// core params to all shaders that consume the style pack.[file:2]
pub fn grime_to_material_system(
    mut ctx: GrimeContext,
    mut query: Query<(&GrimeParams, &Handle<GrimeMaterial>)>,
) {
    let dt = ctx.time.delta_secs();
    let _ = dt; // keeps SystemParam used; dt can be used for future smoothing.

    for (grime, handle) in query.iter_mut() {
        if let Some(mat) = ctx.materials.get_mut(handle) {
            mat.wetness = grime.wetness;
            mat.mud = grime.mud;
            mat.soot = grime.soot;
            mat.tear_intensity = grime.tear_intensity;
            mat.flow_dir = grime.flow_dir;
            mat.stretch_dir = grime.stretch_dir;
        }
    }
}

/// Plugin to wire everything into a Bevy app.
/// On Unreal side, the pattern is equivalent: one native module computes
/// GrimeParams and writes to material parameter collections or dynamic instances.[file:2]
pub struct GrimeBridgePlugin;

impl Plugin for GrimeBridgePlugin {
    fn build(&self, app: &mut App) {
        app.register_type::<GrimeParams>()
            .register_type::<GrimeInvariants>()
            .register_type::<GrimeExposure>()
            .add_plugins(MaterialPlugin::<GrimeMaterial>::default())
            .add_systems(Update, (grime_integration_system, grime_to_material_system));
    }
}
