extends Node
## Level-scoped lifecycle coordinator. All references are injected; no disk persistence.
const Actions = preload("res://scripts/player/action_state.gd")
enum Phase { NONE, DEATH_DELAY, DEATH_SCREEN, RESTORING }
signal checkpoint_activated(id: StringName)
signal rested(id: StringName)
signal death_started
signal death_visibility_changed(visible: bool)
signal respawned(id: StringName)
@export var player: CharacterBody3D
@export var lock_controller: Node
@export var camera_rig: Node3D
@export var initial_spawn: Marker3D
@export var interaction_enabled: bool = true
@export var automatic_respawn_enabled: bool = true
@export_range(0,5,0.05) var death_delay: float = 0.6
@export_range(0.1,10,0.05) var death_screen_duration: float = 2.0
var phase: Phase = Phase.NONE
var elapsed: float = 0.0
var active_id: StringName = &""
var _bonfires: Dictionary = {}
var _active_spawn: Transform3D
var _fallback_spawn: Transform3D
var _pending_interact: bool = false
var _interact_latched: bool = false
var _sequence_delay: float = 0.0
var _sequence_duration: float = 0.0
var _saved_camera_angles: Vector2
var _camera_frozen: bool = false

func _ready() -> void:
	_fallback_spawn = player.global_transform
	player.attributes.died.connect(_on_player_died)
	player.attributes.fully_restored.connect(_on_external_restore)
	for bonfire in get_tree().get_nodes_in_group("bonfires"):
		if bonfire.manager == self: register_bonfire(bonfire)
	if is_instance_valid(initial_spawn):
		var forward: Vector3 = -initial_spawn.global_basis.z
		var yaw: float = atan2(-forward.x,-forward.z)
		player.visual.global_rotation = Vector3(0,yaw,0)
		camera_rig.set_orbit_angles(yaw,deg_to_rad(camera_rig.initial_pitch))
		camera_rig.snap_to_target()

func register_bonfire(bonfire: Node3D) -> bool:
	if not is_instance_valid(bonfire) or bonfire.bonfire_id.is_empty(): return false
	var id: StringName = bonfire.bonfire_id
	if _bonfires.has(id) and is_instance_valid(_bonfires[id]) and _bonfires[id] != bonfire:
		return false
	_bonfires[id] = bonfire
	return true

func unregister_bonfire(bonfire: Node3D) -> void:
	if _bonfires.get(bonfire.bonfire_id) == bonfire:
		_bonfires.erase(bonfire.bonfire_id)
	# Retain the last activated transform if the visual instance goes away.

func get_active_bonfire() -> Node3D:
	var result: Node = _bonfires.get(active_id)
	return result if is_instance_valid(result) else null

func get_bonfire_count() -> int:
	return _bonfires.size()

func get_respawn_transform() -> Transform3D:
	var bonfire := get_active_bonfire()
	if is_instance_valid(bonfire): return bonfire.get_spawn_transform()
	if not active_id.is_empty(): return _active_spawn
	return initial_spawn.global_transform if is_instance_valid(initial_spawn) else _fallback_spawn

func can_interact() -> bool:
	return interaction_enabled and phase == Phase.NONE and player.can_accept_action_input() \
		and player.action_states.current_state == Actions.State.FREE and player.is_on_floor()

func activate_bonfire(bonfire: Node3D) -> bool:
	if not _valid_interaction(bonfire): return false
	_activate(bonfire)
	return true

func _valid_interaction(bonfire: Node3D) -> bool:
	return can_interact() and is_instance_valid(bonfire) and _bonfires.get(bonfire.bonfire_id) == bonfire \
		and bonfire.contains_player(player)

func _activate(bonfire: Node3D) -> void:
	var changed: bool = active_id != bonfire.bonfire_id or not bonfire.lit
	active_id = bonfire.bonfire_id
	_active_spawn = bonfire.get_spawn_transform()
	bonfire.set_lit(true)
	if changed: checkpoint_activated.emit(active_id)

func rest_at(bonfire: Node3D) -> bool:
	if not _valid_interaction(bonfire): return false
	phase = Phase.RESTORING # Guard against re-entry through restore signals.
	_activate(bonfire)
	_pending_interact = false
	lock_controller.release_lock(&"bonfire_rest")
	player.restore_at_checkpoint(get_respawn_transform(),false)
	restore_enemies()
	phase = Phase.NONE
	rested.emit(active_id)
	return true

func restore_enemies() -> int:
	var restored: int = 0
	for enemy in get_tree().get_nodes_in_group("checkpoint_enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion() and enemy.has_method("restore_at_checkpoint"):
			if enemy.restore_at_checkpoint(): restored += 1
	for auxiliary in get_tree().get_nodes_in_group("checkpoint_auxiliary_resets"):
		if is_instance_valid(auxiliary) and auxiliary.has_method("reset_after_checkpoint"):
			auxiliary.reset_after_checkpoint()
	return restored

func request_respawn() -> bool:
	if phase != Phase.NONE or player.attributes.current_health > 0.0 \
		or player.action_states.current_state != Actions.State.DEAD:
		return false
	phase = Phase.DEATH_DELAY
	elapsed = 0.0
	_pending_interact = false
	_sequence_delay = maxf(death_delay,0.0)
	_sequence_duration = maxf(death_screen_duration,0.1)
	lock_controller.release_lock(&"death")
	_saved_camera_angles = camera_rig.get_orbit_angles()
	_camera_frozen = true
	camera_rig.set_control_mode(1)
	camera_rig.set_follow_target(null,false)
	death_started.emit()
	return true

func is_death_visible() -> bool:
	return phase == Phase.DEATH_SCREEN

func _input(event: InputEvent) -> void:
	if event.is_action("interact") and not event.is_echo():
		var pressed := Input.is_action_pressed("interact")
		if pressed and not _interact_latched and interaction_enabled and phase == Phase.NONE:
			_pending_interact = true
		_interact_latched = pressed

func _physics_process(delta: float) -> void:
	if phase == Phase.RESTORING:
		# Overlay was hidden on the previous tick, before any control can resume.
		var spawn := get_respawn_transform()
		restore_enemies()
		player.restore_at_checkpoint(spawn)
		_restore_camera(true,spawn)
		phase = Phase.NONE
		respawned.emit(active_id)
		return
	if phase == Phase.DEATH_DELAY or phase == Phase.DEATH_SCREEN:
		elapsed += delta
		if phase == Phase.DEATH_DELAY and elapsed + 0.0000001 >= _sequence_delay:
			phase = Phase.DEATH_SCREEN
			elapsed = 0.0
			death_visibility_changed.emit(true)
		elif phase == Phase.DEATH_SCREEN and elapsed + 0.0000001 >= _sequence_duration:
			phase = Phase.RESTORING
			death_visibility_changed.emit(false)
		return
	if _pending_interact:
		_pending_interact = false
		var best: Node3D
		var distance: float = INF
		for bonfire in _bonfires.values():
			if is_instance_valid(bonfire) and bonfire.contains_player(player):
				var d: float = player.global_position.distance_squared_to(bonfire.global_position)
				if d < distance:
					best = bonfire
					distance = d
		if is_instance_valid(best): rest_at(best)

func _on_player_died() -> void:
	if automatic_respawn_enabled: request_respawn()

func _on_external_restore() -> void:
	if phase == Phase.DEATH_DELAY or phase == Phase.DEATH_SCREEN:
		cancel_pending_respawn()

func cancel_pending_respawn() -> void:
	phase = Phase.NONE
	elapsed = 0.0
	_pending_interact = false
	death_visibility_changed.emit(false)
	if _camera_frozen: _restore_camera(false,Transform3D.IDENTITY)

func _restore_camera(recenter: bool, spawn: Transform3D) -> void:
	camera_rig.set_follow_target(player,false)
	camera_rig.set_control_mode(0)
	if recenter:
		var forward: Vector3 = -spawn.basis.z
		camera_rig.set_orbit_angles(atan2(-forward.x,-forward.z),deg_to_rad(camera_rig.initial_pitch))
	else:
		camera_rig.set_orbit_angles(_saved_camera_angles.x,_saved_camera_angles.y)
	camera_rig.snap_to_target()
	_camera_frozen = false
