extends Node
const Actions = preload("res://scripts/player/action_state.gd")
enum Mode { NONE, BLOCK, PARRY, GUARD_BREAK }
enum ParryPhase { NONE, STARTUP, ACTIVE, RECOVERY }
signal defense_event(event: StringName)
@export var player: CharacterBody3D
@export var shield_mesh: MeshInstance3D
@export var input_enabled: bool = true
@export var debug_enabled: bool = true
@export_range(0.0,100.0,1.0) var physical_absorption: float = 100.0
@export_range(0.0,100.0,1.0) var stability: float = 60.0
@export_range(1.0,180.0,1.0) var frontal_cone: float = 120.0
@export_range(0.0,1.0,0.05) var block_movement_multiplier: float = 0.45
@export_range(0.0,1.0,0.05) var block_regeneration_multiplier: float = 0.20
@export var guard_break_recovery: float = 1.0
@export_range(0.0,1.0,0.05) var guard_break_health_multiplier: float = 1.0
@export var parry_startup: float = 0.12
@export var parry_active: float = 0.15
@export var parry_recovery: float = 0.55
@export var parry_cost: float = 15.0
@export var vulnerability_duration: float = 1.8
@export var locked_turn_speed: float = 120.0
var mode: Mode = Mode.NONE
var parry_phase: ParryPhase = ParryPhase.NONE
var elapsed: float = 0.0
var last_event: StringName = &""
var _feedback_time: float = 0.0
var _guard_yaw: float = 0.0
var _requires_block_release: bool = false
var _parry_pending: bool = false
var _parry_latched: bool = false


func initialize() -> void:
	player.action_states.state_changed.connect(_on_state_changed)
	player.attributes.fully_restored.connect(_reset)
	shield_mesh.visible = false


func _input(event: InputEvent) -> void:
	if event.is_action("parry") and not event.is_echo():
		var pressed := Input.is_action_pressed("parry")
		if pressed and not _parry_latched and input_enabled:
			_parry_pending = true
		_parry_latched = pressed


func process_requests() -> void:
	var held := input_enabled and Input.is_action_pressed("block")
	if not held:
		_requires_block_release = false
	if _parry_pending:
		_parry_pending = false
		try_parry()
	if mode == Mode.BLOCK and not held:
		_end_owned()
	elif held and mode == Mode.NONE and not _requires_block_release \
		and player.action_states.current_state == Actions.State.FREE and player.attributes.current_health > 0.0:
		mode = Mode.BLOCK
		_guard_yaw = player.visual.global_rotation.y
		if not player.action_states.claim_state(Actions.State.BLOCKING,self):
			mode = Mode.NONE
		else:
			player.attributes.set_regeneration_multiplier(&"shield",block_regeneration_multiplier)
			_event(&"shield_raised")
	shield_mesh.visible = mode == Mode.BLOCK or mode == Mode.PARRY


func is_blocking() -> bool:
	return mode == Mode.BLOCK and player.action_states.current_state == Actions.State.BLOCKING


func try_parry() -> bool:
	if mode != Mode.NONE and mode != Mode.BLOCK:
		return false
	if player.attributes.current_health <= 0.0 or not player.is_on_floor() or not player.attributes.has_stamina(parry_cost):
		return false
	if mode == Mode.BLOCK:
		_end_owned()
	if player.action_states.current_state != Actions.State.FREE:
		return false
	mode = Mode.PARRY
	if not player.action_states.claim_state(Actions.State.PARRYING,self):
		mode = Mode.NONE
		return false
	player.attributes.consume_stamina(parry_cost)
	elapsed = 0.0
	parry_phase = ParryPhase.STARTUP
	_event(&"parry_startup")
	return true


func advance_clock(delta: float) -> void:
	_feedback_time = maxf(_feedback_time-delta,0.0)
	if _feedback_time == 0.0:
		last_event = &""
	if is_blocking():
		if player.has_movement_reference():
			var toward: Vector3 = player.resolve_movement_direction(Vector2.UP)
			var wanted := atan2(-toward.x,-toward.z)
			_guard_yaw = rotate_toward(_guard_yaw,wanted,deg_to_rad(locked_turn_speed)*delta)
		player.face_defense_direction(Vector3(-sin(_guard_yaw),0,-cos(_guard_yaw)))
	elif mode == Mode.PARRY:
		elapsed += delta
		if elapsed + 0.0000001 < parry_startup:
			parry_phase = ParryPhase.STARTUP
		elif elapsed + 0.0000001 < parry_startup+parry_active:
			parry_phase = ParryPhase.ACTIVE
		else:
			parry_phase = ParryPhase.RECOVERY
		if elapsed + 0.0000001 >= parry_startup+parry_active+parry_recovery:
			_end_owned()
	elif mode == Mode.GUARD_BREAK:
		elapsed += delta
		if elapsed + 0.0000001 >= guard_break_recovery:
			_end_owned()


func resolve_contact(attacker: Node3D, packet: Dictionary) -> Dictionary:
	var normal := {"outcome":&"normal","health_damage":packet.damage,"consumed":true}
	var front := _in_front(attacker)
	if mode == Mode.PARRY and parry_phase == ParryPhase.ACTIVE and front and packet.parryable:
		var toward: Vector3 = (player.global_position-attacker.global_position).normalized()
		var incoming: Vector3 = packet.direction
		if incoming.dot(toward) >= cos(deg_to_rad(60.0)) and attacker.has_method("get_critical_vulnerability"):
			var vulnerability: Node = attacker.get_critical_vulnerability()
			if vulnerability.open_from_parry(vulnerability_duration):
				_event(&"parry_success")
				return {"outcome":&"parried","health_damage":0.0,"consumed":true}
	if not is_blocking() or not front or not packet.blockable or packet.damage_type != &"physical":
		return normal
	var required: float = packet.stamina_damage * (1.0-clampf(stability/100.0,0.0,1.0))
	if required > player.attributes.current_stamina + 0.0000001:
		player.attributes.consume_stamina(player.attributes.current_stamina)
		_end_owned()
		mode = Mode.GUARD_BREAK
		_requires_block_release = true
		elapsed = 0.0
		player.action_states.claim_state(Actions.State.STAGGERED,self)
		_event(&"guard_break")
		return {"outcome":&"guard_break","health_damage":packet.damage*guard_break_health_multiplier,"consumed":true,"stamina_cost":required}
	player.attributes.consume_stamina(required)
	_event(&"blocked")
	return {"outcome":&"blocked","health_damage":packet.damage*(1.0-clampf(physical_absorption/100.0,0.0,1.0)),"consumed":true,"stamina_cost":required}


func _in_front(attacker: Node3D) -> bool:
	var toward := attacker.global_position-player.global_position
	toward.y = 0.0
	return toward.length_squared() > 0.0001 and (-player.visual.global_basis.z).dot(toward.normalized()) >= cos(deg_to_rad(frontal_cone*0.5))


func _end_owned() -> void:
	mode = Mode.NONE
	parry_phase = ParryPhase.NONE
	player.attributes.clear_regeneration_multiplier(&"shield")
	player.action_states.complete_owned_state(self)
	shield_mesh.visible = false


func _on_state_changed(_previous: int, current: int) -> void:
	var expected := Actions.State.BLOCKING if mode == Mode.BLOCK else (Actions.State.PARRYING if mode == Mode.PARRY else Actions.State.STAGGERED)
	if mode != Mode.NONE and current != expected:
		mode = Mode.NONE
		parry_phase = ParryPhase.NONE
		player.attributes.clear_regeneration_multiplier(&"shield")
		shield_mesh.visible = false


func _reset() -> void:
	mode = Mode.NONE
	parry_phase = ParryPhase.NONE
	_parry_pending = false
	_requires_block_release = false
	last_event = &""
	player.attributes.clear_regeneration_multiplier(&"shield")
	shield_mesh.visible = false


func _event(value: StringName) -> void:
	last_event = value
	_feedback_time = 0.65
	defense_event.emit(value)
