use bevy::prelude::*;
use game_next_grime::{GrimeParams, GrimeInvariants, GrimeExposure, integrate_grime};

#[derive(Component, Clone, Copy)]
pub struct GrimeState {
    pub params: GrimeParams,
    pub invariants: GrimeInvariants,
}

#[derive(Component)]
pub struct GrimeExposureSource {
    pub rain_intensity: f32,
    pub mud_contact: f32,
    pub fire_soot: f32,
    pub movement_speed: f32,
}

pub struct GrimeBridgePlugin;

impl Plugin for GrimeBridgePlugin {
    fn build(&self, app: &mut App) {
        app.add_systems(Update, update_grime_system);
    }
}

fn update_grime_system(
    mut query: Query<(&mut GrimeState, &GrimeExposureSource)>,
    time: Res<Time>,
) {
    let dt = time.delta_seconds();
    
    for (mut grime, exposure_src) in query.iter_mut() {
        let exposure = GrimeExposure {
            rain_intensity: exposure_src.rain_intensity,
            mud_contact: exposure_src.mud_contact,
            dust_contact: 0.0,
            fire_soot: exposure_src.fire_soot,
            slide_friction: 0.0,
            time_since_clean_sec: 0.0,
            movement_speed: exposure_src.movement_speed,
        };
        
        grime.params = integrate_grime(&grime.params, &exposure, &grime.invariants, dt);
    }
}
