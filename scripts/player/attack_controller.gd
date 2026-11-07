extends Node

const AttackData = preload("res://scripts/combat/attack_data.gd")
const ActionState = preload("res://scripts/player/action_state.gd")
enum AttackKind { LIGHT_1, LIGHT_2, HEAVY_1 }
enum Phase { NONE, STARTUP, ACTIVE, RECOVERY }

signal attack_started(attack_name: StringName, swing_id: int)
signal phase_changed(phase: Phase)
signal attack_finished(attack_name: StringName, completed: bool)
signal attack_rejected(reason: StringName)

@export var player: CharacterBody3D
@export var combat_pivot: Node3D
@export var hitbox: Area3D
@export var sword_mesh: MeshInstance3D
@export var faction: StringName = &"player"
@export var light_1: AttackData
@export var light_2: AttackData
@export var heavy_1: AttackData
@export var input_enabled: bool = true
@export var debug_enabled: bool = true:
	set(value):
		debug_enabled = value
		if is_node_ready():
			call_deferred("refresh_debug")
@export var animation_driven: bool = false

var phase: Phase = Phase.NONE
var elapsed: float = 0.0
var swing_id: int = 0
var _active: bool = false
var _kind: AttackKind = AttackKind.LIGHT_1
var _data: Dictionary = {}
var _yaw: float = 0.0
var _initial_yaw: float = 0.0
var _buffered: bool = false
var _buffer_deadline: float = 0.0
var _pending_kind: int = -1
var _latched: Dictionary = {"light_attack":false,"heavy_attack":false}
var _impact_material: StandardMaterial3D


func initialize() -> void:
	player.action_states.state_changed.connect(_on_action_changed)
	player.attributes.fully_restored.connect(_on_reset)
	_impact_material = StandardMaterial3D.new()
	_impact_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_impact_material.albedo_color = Color(1.0,0.55,0.15)
	call_deferred("refresh_debug")


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	for action in ["light_attack","heavy_attack"]:
		if not event.is_action(action):
			continue
		var pressed := Input.is_action_pressed(action)
		var rising: bool = pressed and not _latched[action]
		_latched[action] = pressed
		if rising and input_enabled and _pending_kind == -1:
			_pending_kind = AttackKind.LIGHT_1 if action == "light_attack" else AttackKind.HEAVY_1


func process_pending_request() -> void:
	var pending := _pending_kind
	_pending_kind = -1
	if pending != -1 and input_enabled:
		request_attack(pending)


func request_attack(kind: int) -> bool:
	if player.has_method("can_accept_action_input") and not player.can_accept_action_input():
		return _reject(&"input_unavailable")
	if kind != AttackKind.LIGHT_1 and kind != AttackKind.HEAVY_1:
		return _reject(&"kind")
	if _active:
		if kind == AttackKind.LIGHT_1 and _kind == AttackKind.LIGHT_1 and not _buffered \
			and elapsed + 0.0000001 >= _data.combo_open and elapsed < _data.combo_close - 0.0000001:
			_buffered = true
			_buffer_deadline = elapsed + _data.buffer_lifetime
			return true
		return _reject(&"busy_or_combo_window")
	if kind == AttackKind.LIGHT_1 and player.has_method("get_riposte_controller"):
		var contextual: int = player.get_riposte_controller().try_contextual()
		if contextual != 0:
			return contextual == 1
	return _start(kind)


func _start(kind: int) -> bool:
	if not player.can_move() or not player.is_on_floor():
		return _reject(&"unavailable")
	var resource: Resource
	if player.has_method("get_attack_variant"):
		resource = player.get_attack_variant(kind)
	if resource == null:
		resource = [light_1,light_2,heavy_1][kind]
	if resource == null:
		return _reject(&"data")
	var data: Dictionary = resource.snapshot()
	if data.is_empty() or not player.attributes.has_stamina(data.cost):
		return _reject(&"stamina_or_data")
	if not player.action_states.claim_state(ActionState.State.ATTACKING,self):
		return _reject(&"state")
	if not player.attributes.consume_stamina(data.cost):
		player.action_states.complete_owned_state(self)
		return _reject(&"stamina")
	_kind = kind as AttackKind
	_data = data
	elapsed = 0.0
	_buffered = false
	_active = true
	swing_id += 1
	_initial_yaw = player.visual.global_rotation.y
	_yaw = _initial_yaw
	combat_pivot.global_rotation = Vector3(0,_yaw,0)
	player.attributes.set_regeneration_blocked(&"attack",true)
	var packet := data.duplicate()
	packet["direction"] = get_attack_direction()
	hitbox.configure_volume(data)
	hitbox.begin_swing(player,faction,data.damage,swing_id,packet)
	_change_phase(Phase.STARTUP)
	attack_started.emit(data.name,swing_id)
	return true


func is_active() -> bool:
	return _active


func current_attack_name() -> StringName:
	if player.has_method("get_riposte_controller") and player.get_riposte_controller().is_active():
		return player.get_riposte_controller().current_critical_name()
	return _data.name if _active else &"NONE"


func has_buffered_attack() -> bool:
	return _buffered


func get_attack_direction() -> Vector3:
	return Vector3(-sin(_yaw),0,-cos(_yaw))


func sync_idle_pose() -> void:
	if not _active:
		combat_pivot.global_rotation = Vector3(0,player.visual.global_rotation.y,0)


func advance_clock(delta: float) -> void:
	if not _active:
		return
	if phase == Phase.STARTUP:
		_steer(minf(delta,maxf(float(_data.startup)-elapsed,0.0)))
	elapsed += delta
	if _buffered and elapsed > _buffer_deadline + 0.0000001:
		_buffered = false
	if not animation_driven:
		if elapsed + 0.0000001 < _data.startup:
			_change_phase(Phase.STARTUP)
		elif elapsed + 0.0000001 < _data.startup + _data.active:
			_change_phase(Phase.ACTIVE)
		else:
			_change_phase(Phase.RECOVERY)


func after_physics_step() -> void:
	if not _active:
		return
	hitbox.sample_hits()
	if not animation_driven and elapsed + 0.0000001 >= _data.total:
		_complete()


func _steer(delta: float) -> void:
	var desired: Vector3
	if player.has_method("get_attack_aim_direction"):
		desired = player.get_attack_aim_direction()
	else:
		var input_vector := Input.get_vector("move_left","move_right","move_forward","move_backward",player.input_deadzone)
		desired = player.resolve_movement_direction(Vector2.UP) if player.has_movement_reference() else player.camera_relative_direction(input_vector)
	if not desired.is_zero_approx():
		var target_yaw := atan2(-desired.x,-desired.z)
		var correction := clampf(angle_difference(_initial_yaw,target_yaw),-deg_to_rad(_data.correction_limit),deg_to_rad(_data.correction_limit))
		_yaw = rotate_toward(_yaw,_initial_yaw+correction,deg_to_rad(_data.turn_speed)*delta)
	combat_pivot.global_rotation = Vector3(0,_yaw,0)
	player.face_attack_direction(get_attack_direction())


func _change_phase(next_phase: Phase) -> void:
	if phase == next_phase:
		return
	phase = next_phase
	if phase == Phase.ACTIVE:
		hitbox.set_attack_direction(get_attack_direction())
	hitbox.set_active(phase == Phase.ACTIVE)
	sword_mesh.material_override = _impact_material if debug_enabled and phase == Phase.ACTIVE else null
	phase_changed.emit(phase)


func _complete() -> void:
	var combo: bool = _buffered and _kind == AttackKind.LIGHT_1 and elapsed <= _buffer_deadline + 0.0000001
	var name: StringName = _data.name
	_active = false
	_buffered = false
	_change_phase(Phase.NONE)
	player.attributes.set_regeneration_blocked(&"attack",false)
	player.attributes.restart_stamina_regeneration_delay()
	player.action_states.complete_owned_state(self)
	attack_finished.emit(name,true)
	if combo:
		_start(AttackKind.LIGHT_2)


func _on_action_changed(_previous: int, current: int) -> void:
	if current != ActionState.State.ATTACKING:
		_abort()


func _on_reset() -> void:
	_abort()


func _abort() -> void:
	_pending_kind = -1
	_buffered = false
	if _active:
		var name: StringName = _data.name
		_active = false
		_change_phase(Phase.NONE)
		player.attributes.set_regeneration_blocked(&"attack",false)
		attack_finished.emit(name,false)


func set_phase_from_animation(next_phase: int) -> bool:
	if not animation_driven or not _active or next_phase != phase + 1 or next_phase > Phase.RECOVERY:
		return false
	_change_phase(next_phase as Phase)
	return true


func finish_from_animation() -> bool:
	if not animation_driven or not _active or phase != Phase.RECOVERY:
		return false
	_complete()
	return true


func interrupt_for_damage() -> bool:
	# Explicit future integration point; hurtboxes do not invoke it automatically.
	if not _active or player.action_states.current_state == ActionState.State.DEAD:
		return false
	_abort()
	if not player.action_states.complete_owned_state(self):
		return false
	return player.action_states.transition_to(ActionState.State.STAGGERED)


func interrupt_for_parry() -> bool:
	if not _active or player.action_states.current_state != ActionState.State.ATTACKING:
		return false
	_abort()
	return player.action_states.complete_owned_state(self)


func refresh_debug() -> void:
	if is_instance_valid(hitbox):
		hitbox.debug_enabled = debug_enabled
		hitbox.set_active(hitbox.is_active())
	for hurtbox in get_tree().get_nodes_in_group("combat_hurtboxes"):
		hurtbox.set_debug_enabled(debug_enabled)
		if is_instance_valid(hurtbox.actor) and hurtbox.actor.has_method("set_combat_debug"):
			hurtbox.actor.set_combat_debug(debug_enabled)
	if is_instance_valid(sword_mesh):
		sword_mesh.material_override = _impact_material if debug_enabled and phase == Phase.ACTIVE else null


func _reject(reason: StringName) -> bool:
	attack_rejected.emit(reason)
	return false
