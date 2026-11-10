# Anexo técnico del informe parcial



Corte: 7 de noviembre de 2026. Rutas relativas a la raíz del proyecto. La nomenclatura descriptiva de componentes no implica que todos los scripts declaren class_name. No se crearon clases ni sistemas nuevos.



## 1. Configuración comprobada



Godot 4.6.3-stable oficial; GDScript; Compatibility/gl_compatibility; Jolt Physics; física efectiva 60 Hz; interpolación activada; viewport 1280 × 720; arranque arena_selector. Autoloads: ControllerRegistry y helper de Godot AI. Hay 21 acciones propias en InputMap. No hay guardado de partida.



El preset Windows Desktop existente usa x86_64 e incluye todos los recursos. No se ejecutó una exportación en esta auditoría ni se ensayó un binario externo. Revisar los metadatos de publicación del preset: sus valores no deben tomarse como identidad institucional ni nombre del equipo.



## 2. Escenas y dependencias



- arena_selector referencia PackedScene de test_arena y boss_arena. ArenaMenuLink es navegación opcional con ruta configurable al selector.

- test_arena compone Player, Soldier, objetivos de entrenamiento y actor técnico; cámara/lock-on; hoguera/checkpoint; HUD y DeathScreen.

- boss_arena instancia el mismo Player, cámara y servicios de ciclo, además de Boss, EncounterEntry y BossHUD.

- ruins_guardian hereda soldier.tscn; mantiene el nodo SoldierAI con guardian_brain.gd para conservar el protocolo del actor.

- La escena player asigna scripts/combat/defense_controller.gd, no scripts/player/defense_controller.gd. Este último archivo también existe, pero no se encontró una referencia activa a él en escenas o preloads del juego: no se le atribuye funcionalidad operativa adicional.



## 3. Reglas y orden de integración



PlayerController procesa solicitudes en física: cambio de empuñadura, defensa, Estus, esquiva y ataque. Los propietarios de estado impiden iniciar acciones incompatibles. El actor conserva el único move_and_slide.



Prioridad contextual del ataque ligero: riposte, backstab, LIGHT_1. Los críticos comparten ejecutor/reserva; el token admite un único daño. La stamina se consulta antes de reclamar acción y se consume una vez; el gasto de carrera es continuo.



Hurtbox valida identidad/facción, protección de pareja crítica, disponibilidad e i-frames, token o defensa, y descuenta vida una sola vez. AttackHitbox reserva al actor antes de callbacks. Un contacto evadido no se consume: si ACTIVE continúa al terminar la invulnerabilidad puede impactar.



DEAD=7 y SWITCHING_GRIP=8; las incorporaciones preservaron los IDs anteriores. La muerte cancela acciones; solo un reset explícito puede volver desde DEAD. El checkpoint devuelve ONE_HANDED y bloquea acciones hasta neutral.



## 4. Índice de APIs auditadas



Cada entrada enumera métodos públicos encontrados en la fuente; no implica que todos tengan una prueba independiente. Para firmas completas y dependencias consultar _verificacion/auditoria_api.json.



### scripts/bosses/boss_hud.gd

Hereda: `Control`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/bosses/boss_pattern.gd

Hereda: `Resource`.

APIs públicas: `is_valid()`



### scripts/bosses/encounter_entry.gd

Hereda: `Area3D`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/bosses/guardian_brain.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `reset_brain()`; `state_name()`; `target_alive()`; `direction_to_target()`; `inside_arena(point: Vector3)`; `start_encounter()`; `eligible_patterns()`; `choose_pattern()`; `start_pattern(id: StringName)`

Señales: `state_changed(previous: State, current: State)`, `encounter_started`, `encounter_ended(reason: StringName)`, `phase_changed(phase: int)`, `victory`, `pattern_started(id: StringName)`.

Referencias de carga: `res://scripts/player/action_state.gd`, `res://scripts/enemies/enemy_world_queries.gd`, `res://scripts/combat/attack_variant.gd`.



### scripts/bosses/ruins_guardian.gd

Hereda: `"res://scripts/enemies/soldier_actor.gd"`.

APIs públicas: `get_attack_variant(_kind: int)`

Referencias de carga: `res://scripts/systems/session_progress.gd`.



### scripts/combat/action_debug.gd

Hereda: `Label`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/combat/attack_data.gd

Hereda: `Resource`.

APIs públicas: `snapshot()`



### scripts/combat/attack_debug.gd

Hereda: `Label`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/combat/attack_hitbox.gd

Hereda: `Area3D`.

APIs públicas: `configure_volume(data: Dictionary = {})`; `begin_swing(attacker: Node, faction: StringName, damage: float, swing_id: int, context: Dictionary = {})`; `is_active()`; `set_attack_direction(direction: Vector3)`; `set_active(value: bool)`; `sample_hits()`

Señales: `hit_confirmed(actor: Node, damage: float, swing_id: int)`, `impact_resolved(actor: Node, result: Dictionary)`.

Referencias de carga: `res://scripts/combat/hurtbox.gd`, `res://scripts/combat/combat_debug_geometry.gd`.



### scripts/combat/attack_variant.gd

Hereda: `Resource`.

APIs públicas: `snapshot()`



### scripts/combat/combat_debug_geometry.gd

Hereda: `RefCounted`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/combat/critical_vulnerability.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `open_from_parry(duration: float)`; `is_available()`; `can_backstab()`; `reserve_backstab(requester: Node)`; `is_reserved()`; `reserve(requester: Node)`; `authorize_damage(requester: Node)`; `finish_reservation(requester: Node)`

Señales: `changed`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/combat/defense_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `process_requests()`; `is_blocking()`; `try_parry()`; `advance_clock(delta: float)`; `resolve_contact(attacker: Node3D, packet: Dictionary)`; `release_for_grip()`

Señales: `defense_event(event: StringName)`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/combat/defense_debug.gd

Hereda: `Label`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/combat/defense_test_attacker.gd

Hereda: `Node`.

APIs públicas: `reset_after_checkpoint()`; `execute_test(kind: int)`

Referencias de carga: `res://scripts/combat/attack_data.gd`.



### scripts/combat/hurtbox.gd

Hereda: `Area3D`.

APIs públicas: `set_debug_enabled(value: bool)`; `can_target(attacker: Node, attacker_faction: StringName)`; `can_receive(attacker: Node, attacker_faction: StringName)`; `receive_hit(attacker: Node, attacker_faction: StringName, damage: float, swing_id: int, context: Dictionary = {})`; `resolve_hit(attacker: Node, attacker_faction: StringName, damage: float, swing_id: int, context: Dictionary = {})`

Señales: `damage_received(amount: float, attacker: Node, swing_id: int)`, `impact_resolved(result: Dictionary)`.

Referencias de carga: `res://scripts/systems/actor_attributes.gd`, `res://scripts/combat/combat_debug_geometry.gd`.



### scripts/combat/riposte_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `is_active()`; `try_contextual()`; `advance_clock(delta: float)`; `after_physics_step()`; `current_critical_name()`

Señales: `riposte_event(event: StringName)`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/combat/training_dummy.gd

Hereda: `"res://scripts/systems/lockable_target.gd"`.

APIs públicas: `set_combat_debug(value: bool)`; `get_critical_vulnerability()`; `is_critical_committed()`; `can_receive_attack()`; `interrupt_attack_for_critical()`



### scripts/enemies/enemy_world_queries.gd

Hereda: `RefCounted`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/enemies/soldier_actor.gd

Hereda: `CharacterBody3D`.

APIs públicas: `set_move_intent(direction: Vector3)`; `face_direction(direction: Vector3, delta: float)`; `face_attack_direction(direction: Vector3)`; `get_attack_aim_direction()`; `can_move()`; `can_receive_attack()`; `get_critical_vulnerability()`; `is_critical_committed()`; `interrupt_attack_for_critical()`; `can_interrupt_for_backstab()`; `should_restore_at_checkpoint()`; `restore_at_checkpoint()`; `set_combat_debug(value: bool)`

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/enemies/soldier_ai.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `reset_brain()`; `state_name()`; `target_alive()`; `direction_to_target()`; `has_line_of_sight()`; `can_detect()`; `can_travel(direction: Vector3)`

Señales: `state_changed(previous: State, current: State)`.

Referencias de carga: `res://scripts/player/action_state.gd`, `res://scripts/enemies/enemy_world_queries.gd`.



### scripts/player/action_state.gd

Hereda: `Node`.

APIs públicas: `can_transition_to(next_state: int)`; `transition_to(next_state: int)`; `can_move()`; `can_sprint()`; `blocks_regeneration()`; `reset_to_free()`; `claim_state(next_state: int, owner: Node)`; `complete_owned_state(owner: Node)`

Señales: `state_changed(previous: State, current: State)`.



### scripts/player/attack_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `process_pending_request()`; `request_attack(kind: int)`; `is_active()`; `current_attack_name()`; `has_buffered_attack()`; `get_attack_direction()`; `sync_idle_pose()`; `advance_clock(delta: float)`; `after_physics_step()`; `set_phase_from_animation(next_phase: int)`; `finish_from_animation()`; `interrupt_for_damage()`; `interrupt_for_parry()`; `refresh_debug()`

Señales: `attack_started(attack_name: StringName, swing_id: int)`, `phase_changed(phase: Phase)`, `attack_finished(attack_name: StringName, completed: bool)`, `attack_rejected(reason: StringName)`.

Referencias de carga: `res://scripts/combat/attack_data.gd`, `res://scripts/player/action_state.gd`.



### scripts/player/defense_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `process_requests()`; `is_blocking()`; `try_parry()`; `advance_clock(delta: float)`; `resolve_contact(attacker: Node3D, packet: Dictionary)`

Señales: `defense_event(event: StringName)`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/player/dodge_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `get_weight_class()`; `get_profile_name()`; `is_active()`; `is_invulnerable()`; `is_recovering()`; `process_pending_request()`; `try_dodge(input_vector: Vector2)`; `advance_motion(delta: float)`; `finish_physics_step()`

Señales: `dodge_started(profile: StringName, direction: Vector3, backstep: bool)`, `dodge_finished`, `dodge_rejected(reason: StringName)`.

Referencias de carga: `res://scripts/player/dodge_profile.gd`, `res://scripts/player/action_state.gd`.



### scripts/player/dodge_profile.gd

Hereda: `Resource`.

APIs públicas: `snapshot()`



### scripts/player/estus_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `process_request()`; `try_use()`; `is_active()`; `advance_clock(delta: float)`; `interrupt_for_stagger()`

Señales: `charges_changed(current: int, capacity: int)`, `phase_changed(phase: Phase)`, `used(healing_applied: float)`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/player/grip_controller.gd

Hereda: `Node`.

APIs públicas: `initialize()`; `process_request()`; `try_toggle()`; `is_switching()`; `shield_available()`; `get_critical_multiplier()`; `get_attack_profile(kind: int)`; `advance_clock(delta: float)`; `sync_visual()`

Señales: `mode_changed(mode: Mode)`, `switching_changed(active: bool)`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/player/lock_on_controller.gd

Hereda: `Node`.

APIs públicas: `is_locked()`; `try_acquire()`; `can_acquire(target: LockableTarget)`; `has_line_of_sight(target: LockableTarget)`; `switch_target(direction: int)`; `release_lock(reason: StringName = &"manual")`

Señales: `target_changed(target: LockableTarget)`, `lock_released(reason: StringName)`.

Referencias de carga: `res://scripts/systems/lockable_target.gd`, `res://scripts/player/player_controller.gd`, `res://scripts/systems/orbit_camera.gd`.



### scripts/player/player_controller.gd

Hereda: `CharacterBody3D`.

APIs públicas: `camera_relative_direction(input_vector: Vector2)`; `set_movement_reference(forward: Vector3)`; `clear_movement_reference()`; `has_movement_reference()`; `resolve_movement_direction(input_vector: Vector2)`; `is_invulnerable()`; `can_receive_attack()`; `face_direction(direction: Vector3, delta: float)`; `face_attack_direction(direction: Vector3)`; `can_move()`; `can_lock_on()`; `can_accept_action_input()`; `restore_at_checkpoint(spawn: Transform3D, relocate: bool = true)`; `face_defense_direction(direction: Vector3)`; `get_defense_controller()`; `get_riposte_controller()`; `get_attack_variant(kind: int)`; `get_critical_vulnerability()`; `interrupt_attack_for_critical()`; `can_interrupt_for_backstab()`; `is_critical_committed()`

Señales: `locomotion_state_changed(state: LocomotionState)`, `sprint_dodge_released(held_seconds: float, was_long_press: bool)`.

Referencias de carga: `res://scripts/player/sprint_dodge_input.gd`, `res://scripts/systems/actor_attributes.gd`, `res://scripts/player/action_state.gd`, `res://scripts/player/dodge_controller.gd`, `res://scripts/player/attack_controller.gd`, `res://scripts/combat/defense_controller.gd`, `res://scripts/combat/riposte_controller.gd`, `res://scripts/combat/critical_vulnerability.gd`, `res://scripts/player/grip_controller.gd`, `res://scripts/player/estus_controller.gd`.



### scripts/player/sprint_dodge_input.gd

Hereda: `RefCounted`.

APIs públicas: `set_pressed(pressed: bool)`; `advance(delta: float, hold_threshold: float)`; `cancel()`

Señales: `released(held_seconds: float, was_long_press: bool)`.



### scripts/systems/actor_attributes.gd

Hereda: `Node`.

APIs públicas: `has_stamina(amount: float)`; `consume_stamina(amount: float)`; `restore_stamina(amount: float)`; `apply_damage(amount: float)`; `restore_health(amount: float)`; `restore_all()`; `set_regeneration_blocked(reason: StringName, blocked: bool)`; `is_regeneration_blocked()`; `set_regeneration_multiplier(reason: StringName, value: float)`; `clear_regeneration_multiplier(reason: StringName)`; `get_regeneration_multiplier()`; `restart_stamina_regeneration_delay()`; `advance_regeneration(delta: float)`

Señales: `health_changed(current: float, maximum: float)`, `stamina_changed(current: float, maximum: float)`, `died`, `fully_restored`.



### scripts/systems/arena_menu_link.gd

Hereda: `CanvasLayer`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/arena_selector.gd

Hereda: `Control`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/bonfire.gd

Hereda: `Node3D`.

APIs públicas: `contains_player(player: CharacterBody3D)`; `get_spawn_transform()`; `set_lit(value: bool)`



### scripts/systems/camera_spring_arm.gd

Hereda: `SpringArm3D`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/checkpoint_manager.gd

Hereda: `Node`.

APIs públicas: `register_bonfire(bonfire: Node3D)`; `unregister_bonfire(bonfire: Node3D)`; `get_active_bonfire()`; `get_bonfire_count()`; `get_respawn_transform()`; `can_interact()`; `activate_bonfire(bonfire: Node3D)`; `rest_at(bonfire: Node3D)`; `restore_enemies()`; `request_respawn()`; `is_death_visible()`; `cancel_pending_respawn()`

Señales: `checkpoint_activated(id: StringName)`, `rested(id: StringName)`, `death_started`, `death_visibility_changed(visible: bool)`, `respawned(id: StringName)`.

Referencias de carga: `res://scripts/player/action_state.gd`.



### scripts/systems/checkpoint_status.gd

Hereda: `Label`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/controller_registry.gd

Hereda: `Node`.

APIs públicas: `has_controller()`; `get_devices()`

Señales: `devices_changed`, `connection_reported(device_id: int, connected: bool)`.



### scripts/systems/death_screen.gd

Hereda: `Control`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/dodge_debug.gd

Hereda: `Label`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/estus_hud.gd

Hereda: `MarginContainer`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/lock_on_indicator.gd

Hereda: `Control`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/lockable_target.gd

Hereda: `Node3D`.

APIs públicas: `is_available()`; `get_aim_position()`; `get_reference_position()`; `get_collision_exclusions()`



### scripts/systems/orbit_camera.gd

Hereda: `Node3D`.

APIs públicas: `get_follow_target()`; `set_follow_target(target: Node3D, snap: bool = true)`; `snap_to_target()`; `get_orbit_angles()`; `set_orbit_angles(yaw_radians: float, pitch_radians: float)`; `set_control_mode(mode: ControlMode)`



### scripts/systems/player_vitals_hud.gd

Hereda: `MarginContainer`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.

Referencias de carga: `res://scripts/systems/actor_attributes.gd`.



### scripts/systems/session_progress.gd

Hereda: `RefCounted`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.



### scripts/systems/test_arena.gd

Hereda: `Node3D`.

APIs públicas: sin métodos públicos adicionales; callbacks del motor.

Referencias de carga: `res://scripts/systems/controller_registry.gd`.



## 5. Matriz de pruebas históricas



| Fase | Aprobadas/total en regresión final 3C | Fallos finales |

|---|---:|---|

| 1A | 16/16 | Ninguno |

| 1B | 44/44 | Ninguno |

| 1C | 38/38 | Ninguno |

| 1D | 47/47 | Ninguno |

| 2A | 59/59 | Ninguno |

| 2B | 63/63 | Ninguno |

| 2C | 60/60 | Ninguno |

| 2D | 63/63 | Ninguno |

| 2E | 77/77 | Ninguno |

| 3A | 61/61 | Ninguno |

| 3B | 62/62 | Ninguno |



Suma dentro de una sola pasada histórica: 590/590. Suite nueva 3C: 73/73. No sumar columnas de regresiones entre fases.



### Checks nuevos de 3C



- active_armor_keeps_attack_commitment: aprobado.

- active_orientation_committed: aprobado.

- area_active_and_damage_once: aprobado.

- area_can_be_escaped_by_walking: aprobado.

- area_full_preparation_no_damage: aprobado.

- area_no_duplicate_damage: aprobado.

- area_only_phase_two_and_starts: aprobado.

- area_roll_timing_evades_contact: aprobado.

- area_warning_off_in_recovery: aprobado.

- area_warning_precedes_damage: aprobado.

- arena_boundary_resets_safely: aprobado.

- autonomous_approach_and_pattern: aprobado.

- backstab_policy_can_be_enabled_independently: aprobado.

- bonfire_rest_after_victory: aprobado.

- boss_area_real_contact_kills_player: aprobado.

- boss_lockable: aprobado.

- boss_slam_guard_break: aprobado.

- checkpoint_retries_full_health_phase_one: aprobado.

- combo_first_impact: aprobado.

- combo_has_exactly_two_swings: aprobado.

- combo_second_impact_separate_window: aprobado.

- combo_second_separate_startup: aprobado.

- compatible_boss_attack_blocks: aprobado.

- cooldown_independently_prevents_repeat: aprobado.

- death_cancels_attacks_ai_and_lock_target: aprobado.

- death_has_absolute_priority: aprobado.

- death_releases_player_lock: aprobado.

- default_attack_rejects_parry_by_contact: aprobado.

- default_boss_backstab_rejected: aprobado.

- default_riposte_policy_off: aprobado.

- defeated_boss_never_respawns_on_rest: aprobado.

- entry_starts_real_encounter_intro: aprobado.

- horizontal_active_damage_and_wide_shape: aprobado.

- horizontal_starts: aprobado.

- hud_initially_hidden: aprobado.

- initial_boss_type_health_id: aprobado.

- intro_rejects_attack_requests: aprobado.

- main_scene_configuration_preserved: aprobado.

- one_damage_per_window: aprobado.

- parry_and_riposte_policy_future_opt_in: aprobado.

- phase_one_has_three_patterns_no_area: aprobado.

- phase_transition_after_committed_attack: aprobado.

- phase_two_decision_more_aggressive: aprobado.

- phase_two_legal_pattern_starts: aprobado.

- phase_two_once_without_heal: aprobado.

- phase_two_recovery_snapshot_reduced: aprobado.

- player_normal_hitbox_damages_boss: aprobado.

- post_attack_reposition_moves: aprobado.

- recent_pattern_prevents_repeat: aprobado.

- recovery_armor_keeps_commitment: aprobado.

- recovery_hitbox_disabled: aprobado.

- repeated_rest_no_boss_duplicates: aprobado.

- retry_clears_hitboxes_transitions_hud: aprobado.

- scene_reload_preserves_defeat_in_same_session: aprobado.

- selection_rejects_outside_range: aprobado.

- selection_rejects_solid_obstruction: aprobado.

- selection_rejects_wrong_angle: aprobado.

- session_defeat_recorded_by_stable_id: aprobado.

- shared_attack_damage_and_physical_nodes: aprobado.

- slam_hits_and_stamina_damage: aprobado.

- slam_long_recovery: aprobado.

- slam_long_startup: aprobado.

- slash_phase_clock: aprobado.

- stagger_recovers_owned_state: aprobado.

- startup_has_no_offense: aprobado.

- startup_stagger_rule: aprobado.

- threshold_does_not_retrigger: aprobado.

- threshold_queues_not_cancels_attack: aprobado.

- transition_begins_after_whole_combo: aprobado.

- transition_blocks_new_offense: aprobado.

- transition_preserves_second_committed_combo_hit: aprobado.

- victory_and_hud_end: aprobado.

- weighted_selection_seed_reproducible: aprobado.



### Aislamientos y compatibilidad de expectativas



Listener corto aislado en 1B/1D/2A; adquisición de backstab aislada en 2C; IA normal apartada de fixtures anteriores a 3A; ciclo automático de checkpoint aislado cuando las suites esperan DEAD terminal. Se mantienen casos integrados con componentes activos. Ver informes originales para cada contrato.



El selector posterior cambia intencionalmente application/run/main_scene. El check main_scene_configuration_preserved de 3C aún exige test_arena. El resultado 73/73 corresponde al cierre de 3C antes de ese cambio; no certifica que la suite sin adaptar pase actualmente. No se modificaron los tests históricos en esta auditoría.



No se reejecutaron suites que escriben JSON en tests/, para preservar íntegros los informes históricos. La verificación actual se limitó a arranques, consultas de configuración, estados de captura y logs.



## 6. Parámetros y recursos



Los valores detallados de marcha, cámara, esquivas, ataques, defensa, críticos, Estus y jefe constan en el informe principal. Los datos de ataques son .tres; se pueden revisar sin reescribir ejecutores. No son valores medidos de Dark Souls.



### Inventario de escenas y recursos



- scenes/bosses/ruins_guardian.tscn

- scenes/enemies/soldier.tscn

- scenes/levels/boss_arena.tscn

- scenes/levels/test_arena.tscn

- scenes/player/player.tscn

- scenes/props/bonfire.tscn

- scenes/props/camera_rig.tscn

- scenes/props/lockable_dummy.tscn

- scenes/props/training_dummy.tscn

- scenes/ui/arena_menu_link.tscn

- scenes/ui/arena_selector.tscn

- scenes/ui/boss_hud.tscn

- scenes/ui/death_screen.tscn

- scenes/ui/estus_hud.tscn

- scenes/ui/player_vitals.tscn

- resources/attacks/boss/combo_first.tres

- resources/attacks/boss/combo_second.tres

- resources/attacks/boss/horizontal_slash.tres

- resources/attacks/boss/ruin_burst.tres

- resources/attacks/boss/vertical_slam.tres

- resources/attacks/heavy_1.tres

- resources/attacks/light_1.tres

- resources/attacks/light_2.tres

- resources/attacks/soldier_light.tres

- resources/attacks/two_hand_heavy_1.tres

- resources/attacks/two_hand_light_1.tres

- resources/attacks/two_hand_light_2.tres

- resources/bosses/horizontal_slash.tres

- resources/bosses/ruin_burst.tres

- resources/bosses/two_hit_combo.tres

- resources/bosses/vertical_slam.tres

- resources/dodges/backstep.tres

- resources/dodges/fast.tres

- resources/dodges/heavy.tres

- resources/dodges/medium.tres



## 7. Evidencia gráfica y trazabilidad



Ver CAPTURAS/LEEME.md para método de captura y staging. Las originales no se retocaron. Los diagramas son representaciones documentales, identificados como D1 y D2; no son capturas del motor.



_verificacion/hashes_antes.json registra los archivos protegidos; la comparación final queda en _verificacion/validacion_final.json. Los scripts de generación están dentro de la entrega excluida de Godot. Las previsualizaciones del PDF son solo material de QA.



## 8. Observaciones que requieren completar o verificar



- No se encontraron .blend, .glb, .gltf, modelos externos ni audio dentro de assets. No se infiere que el equipo no trabaje en ellos fuera de esta carpeta.

- No se encontró un tutorial o recorrido completo integrado. El menú actual es un selector técnico, no una interfaz final.

- No se midieron gráficos integrados/4 GB, ni se probó joystick físico o distribución Windows final.

- scripts/player/player_controller.gd y action_state.gd conservan comentarios iniciales de fases anteriores que no describen todas las dependencias actuales; la auditoría usa el código efectivo y referencias de escena.

- README contiene párrafos históricos sobre F5 y ausencia de sistemas posteriores. Prevalece su apartado actual del selector y la configuración real.

- Falta completar identidades académicas y responsabilidades del equipo; Fase 4A no iniciada.

