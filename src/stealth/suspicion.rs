pub struct ObserverContext {
    pub npc_id: i32,
    pub is_enforcer: bool,
    pub base_suspicion: f32,
    pub current_suspicion: f32,
    pub max_suspicion: f32,
}

pub struct PlayerState {
    pub disguise_tag: String,
    pub is_in_restricted_area: bool,
    pub is_committing_illegal_action: bool,
    pub held_item_tag: Option<String>,
    pub notoriety: f32, // 0.0 - 100.0
}

pub fn update_suspicion(
    observer: &mut ObserverContext,
    player: &PlayerState,
    in_line_of_sight: bool,
    delta_time: f32,
) {
    let mut change = 0.0;

    if in_line_of_sight {
        // Base curiosity.
        change += 0.5;

        // Illegal context.
        if player.is_in_restricted_area {
            change += 2.0;
        }
        if player.is_committing_illegal_action {
            change += 4.0;
        }

        // Illegal item heuristic (e.g., unsilenced rifle, explosives).
        if let Some(tag) = &player.held_item_tag {
            if is_illegal_item_for_disguise(tag, &player.disguise_tag) {
                change += 3.0;
            }
        }

        // Enforcers and notoriety scale.
        if observer.is_enforcer {
            change *= 1.5;
        }
        change *= 1.0 + (player.notoriety / 150.0);
    } else {
        // Decay when out of sight.
        change -= 1.5;
    }

    observer.current_suspicion =
        (observer.current_suspicion + change * delta_time).clamp(observer.base_suspicion, observer.max_suspicion);
}

fn is_illegal_item_for_disguise(item_tag: &str, disguise_tag: &str) -> bool {
    // To be filled with data-driven checks (SQLite or config).
    // Example: shotguns legal for "security_heavy", illegal for "waiter".
    todo!()
}
