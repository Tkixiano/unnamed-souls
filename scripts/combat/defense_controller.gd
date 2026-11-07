extends Node
## Owns defensive action state; Hurtbox alone applies resolved health damage.
const Actions = preload("res://scripts/player/action_state.gd")
enum Mode { NONE, BLOCK, PARRY, GUARD_BREAK }
enum ParryPhase { NONE, STARTUP, ACTIVE, RECOVERY }
signal defense_event(event: StringName)
@export var player: CharacterBody3D
@export var shield_mesh: MeshInstance3D
@export var input_enabled: bool = true
@export var debug_enabled: bool = true
@export_group("Escudo")
@export_range(0,100) var absorption: float = 100.0
@export_range(0,100) var stability: float = 60.0
@export_range(1,180) var frontal_cone: float = 120.0
@export_range(0,1) var movement_multiplier: float = 0.45
@export_range(0,1) var regeneration_multiplier: float = 0.2
@export var locked_turn_speed: float = 120.0
@export_group("Guard break")
@export var guard_break_recovery: float = 1.0
@export var guard_break_health_multiplier: float = 1.0
@export_group("Parry")
@export var parry_startup: float = 0.12
@export var parry_active: float = 0.15
@export var parry_recovery: float = 0.55
@export var parry_cost: float = 15.0
@export var vulnerability_duration: float = 1.8
var mode: Mode = Mode.NONE
var parry_phase: ParryPhase = ParryPhase.NONE
var elapsed: float = 0.0
var last_event: StringName = &""
var feedback_remaining: float = 0.0
var _guard_yaw: float = 0.0
var _requires_block_release: bool = false
var _pending_parry: bool = false
var _parry_latched: bool = false

func initialize() -> void:
	player.action_states.state_changed.connect(_on_state_changed)
	player.attributes.fully_restored.connect(_reset)
	shield_mesh.visible = false

func _input(event: InputEvent) -> void:
	if event.is_action("parry") and not event.is_echo():
		var pressed := Input.is_action_pressed("parry")
		if pressed and not _parry_latched and input_enabled:
			_pending_parry = true
		_parry_latched = pressed

func process_requests() -> void:
	var held: bool = input_enabled and player.can_accept_action_input() and player.grip_controller.shield_available() and Input.is_action_pressed("block")
	if not held:
		_requires_block_release = false
	if _pending_parry:
		_pending_parry = false
		try_parry()
	if is_blocking() and not held:
		_end_owned()
	elif held and not _requires_block_release and mode == Mode.NONE and player.action_states.current_state == Actions.State.FREE:
		mode = Mode.BLOCK
		_guard_yaw = player.visual.global_rotation.y
		if player.action_states.claim_state(Actions.State.BLOCKING,self):
			player.attributes.set_regeneration_multiplier(&"shield",regeneration_multiplier)
			_event(&"shield_raised")
		else:
			mode = Mode.NONE
	shield_mesh.visible = mode in [Mode.BLOCK,Mode.PARRY]

func is_blocking() -> bool:
	return mode == Mode.BLOCK and player.action_states.current_state == Actions.State.BLOCKING

func try_parry() -> bool:
	if not player.can_accept_action_input():
		return false
	if not player.grip_controller.shield_available() or mode not in [Mode.NONE,Mode.BLOCK] or not player.is_on_floor() or not player.attributes.has_stamina(parry_cost):
		return false
	if is_blocking():
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
	shield_mesh.visible = true
	_event(&"parry_startup")
	return true

func advance_clock(delta: float) -> void:
	feedback_remaining = maxf(feedback_remaining-delta,0.0)
	if is_blocking():
		if player.has_movement_reference():
			var toward: Vector3 = player.resolve_movement_direction(Vector2.UP)
			_guard_yaw = rotate_toward(_guard_yaw,atan2(-toward.x,-toward.z),deg_to_rad(locked_turn_speed)*delta)
		player.face_defense_direction(Vector3(-sin(_guard_yaw),0,-cos(_guard_yaw)))
	elif mode == Mode.PARRY:
		elapsed += delta
		if elapsed + 0.0000001 >= parry_startup + parry_active + parry_recovery:
			_end_owned()
		elif elapsed + 0.0000001 < parry_startup:
			parry_phase = ParryPhase.STARTUP
		elif elapsed + 0.0000001 < parry_startup + parry_active:
			parry_phase = ParryPhase.ACTIVE
		else:
			parry_phase = ParryPhase.RECOVERY
	elif mode == Mode.GUARD_BREAK:
		elapsed += delta
		if elapsed + 0.0000001 >= guard_break_recovery:
			_end_owned()

func resolve_contact(attacker: Node3D, packet: Dictionary) -> Dictionary:
	var normal := {"outcome":&"normal","health_damage":packet.damage,"consumed":true}
	var toward: Vector3 = attacker.global_position-player.global_position
	toward.y = 0.0
	var forward: Vector3 = -player.visual.global_basis.z
	var frontal: bool = not toward.is_zero_approx() and forward.dot(toward.normalized()) >= cos(deg_to_rad(frontal_cone*0.5))
	if mode == Mode.PARRY and parry_phase == ParryPhase.ACTIVE and frontal and packet.get("parryable",false):
		var incoming: Vector3 = packet.get("direction",Vector3.ZERO)
		var aimed: bool = incoming.normalized().dot(-toward.normalized()) >= cos(deg_to_rad(60.0))
		if aimed and attacker.has_method("get_critical_vulnerability"):
			var vulnerable: Node = attacker.get_critical_vulnerability()
			if is_instance_valid(vulnerable) and vulnerable.open_from_parry(vulnerability_duration):
				_event(&"parry_success")
				return {"outcome":&"parried","health_damage":0.0,"consumed":true}
	if not is_blocking() or not frontal or not packet.get("blockable",false) or packet.get("damage_type",&"physical") != &"physical":
		return normal
	var required: float = maxf(float(packet.get("stamina_damage",0.0)),0.0)*(1.0-clampf(stability/100.0,0.0,1.0))
	if required > player.attributes.current_stamina + 0.0000001:
		player.attributes.consume_stamina(player.attributes.current_stamina)
		_end_owned()
		mode = Mode.GUARD_BREAK
		_requires_block_release = true
		elapsed = 0.0
		player.action_states.claim_state(Actions.State.STAGGERED,self)
		_event(&"guard_break")
		return {"outcome":&"guard_break","health_damage":packet.damage*maxf(guard_break_health_multiplier,0.0),"consumed":true,"stamina_cost":required}
	player.attributes.consume_stamina(required)
	_event(&"blocked")
	return {"outcome":&"blocked","health_damage":packet.damage*(1.0-clampf(absorption/100.0,0.0,1.0)),"consumed":true,"stamina_cost":required}

func _end_owned() -> void:
	mode = Mode.NONE
	parry_phase = ParryPhase.NONE
	player.attributes.clear_regeneration_multiplier(&"shield")
	player.action_states.complete_owned_state(self)
	shield_mesh.visible = false

func release_for_grip() -> void:
	if is_blocking():
		_end_owned()

func _on_state_changed(_previous: int, current: int) -> void:
	var expected: int = Actions.State.BLOCKING if mode == Mode.BLOCK else Actions.State.PARRYING if mode == Mode.PARRY else Actions.State.STAGGERED
	if mode != Mode.NONE and current != expected:
		mode = Mode.NONE
		parry_phase = ParryPhase.NONE
		player.attributes.clear_regeneration_multiplier(&"shield")
		shield_mesh.visible = false

func _reset() -> void:
	mode = Mode.NONE
	parry_phase = ParryPhase.NONE
	_pending_parry = false
	_requires_block_release = false
	last_event = &""
	player.attributes.clear_regeneration_multiplier(&"shield")
	shield_mesh.visible = false

func _event(value: StringName) -> void:
	last_event = value
	feedback_remaining = 0.65
	defense_event.emit(value)
