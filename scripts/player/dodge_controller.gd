extends Node
## Captures short-release requests; Player alone executes physical movement.

const Profile = preload("res://scripts/player/dodge_profile.gd")
const ActionState = preload("res://scripts/player/action_state.gd")
enum WeightClass { FAST, MEDIUM, HEAVY, OVERLOADED }

signal dodge_started(profile: StringName, direction: Vector3, backstep: bool)
signal dodge_finished
signal dodge_rejected(reason: StringName)

@export var player: CharacterBody3D
@export_group("Entrada y depuración")
@export var input_enabled: bool = true
@export var debug_enabled: bool = true
@export_group("Carga provisional")
@export_range(0.0, 200.0, 0.1, "suffix:%") var equipment_load_percent: float = 25.0
@export_group("Costes")
@export_range(0.0, 100.0, 1.0) var roll_cost: float = 25.0
@export_range(0.0, 100.0, 1.0) var backstep_cost: float = 15.0
@export_group("Perfiles")
@export var fast_profile: Profile
@export var medium_profile: Profile
@export var heavy_profile: Profile
@export var backstep_profile: Profile

var direction: Vector3 = Vector3.ZERO
var elapsed: float = 0.0
var is_backstep: bool = false
var _active: bool = false
var _profile: Dictionary = {}
var _pending: Dictionary = {}


func initialize() -> void:
	player.sprint_dodge_released.connect(_on_button_released)
	player.attributes.fully_restored.connect(_on_reset)
	player.action_states.state_changed.connect(_on_action_changed)


func get_weight_class() -> WeightClass:
	if equipment_load_percent <= 25.0:
		return WeightClass.FAST
	if equipment_load_percent <= 50.0:
		return WeightClass.MEDIUM
	if equipment_load_percent <= 100.0:
		return WeightClass.HEAVY
	return WeightClass.OVERLOADED


func get_profile_name() -> StringName:
	if _active:
		return _profile.name
	return StringName(WeightClass.keys()[get_weight_class()])


func is_active() -> bool:
	return _active


func is_invulnerable() -> bool:
	return _active and player.action_states.current_state == ActionState.State.DODGING \
		and elapsed + 0.0000001 >= _profile.iframes_start and elapsed < _profile.iframes_end - 0.0000001


func is_recovering() -> bool:
	return _active and elapsed + 0.0000001 >= _profile.total - _profile.recovery


func _on_button_released(_held_seconds: float, was_long_press: bool) -> void:
	if not input_enabled or was_long_press or _active or not player.can_move():
		return
	# Sample direction at release, not on the next frame after the stick changes.
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward", player.input_deadzone)
	_pending = _resolve_request(input_vector)


func process_pending_request() -> void:
	if not input_enabled:
		_pending = {}
		return
	if _pending.is_empty():
		return
	var request := _pending
	_pending = {}
	_start(request)


func try_dodge(input_vector: Vector2) -> bool:
	# Technical/API entry point, independent of the optional input listener.
	if not input_vector.is_finite():
		return _reject(&"input")
	return _start(_resolve_request(input_vector.limit_length()))


func _resolve_request(input_vector: Vector2) -> Dictionary:
	var backstep := input_vector.is_zero_approx()
	# Preserve the full analog angle in camera space, including while locked on.
	var world_direction: Vector3 = player.visual.global_basis.z if backstep else player.camera_relative_direction(input_vector)
	world_direction.y = 0.0
	return {"direction": world_direction.normalized(), "backstep": backstep}


func _start(request: Dictionary) -> bool:
	if _active or not player.can_move():
		return _reject(&"busy")
	if not player.is_on_floor():
		return _reject(&"airborne")
	if not is_finite(equipment_load_percent) or get_weight_class() == WeightClass.OVERLOADED:
		return _reject(&"overloaded")
	var profile: Profile = backstep_profile if request.backstep else [fast_profile, medium_profile, heavy_profile][get_weight_class()]
	if profile == null or profile.snapshot().is_empty():
		return _reject(&"profile")
	var cost := backstep_cost if request.backstep else roll_cost
	if not player.attributes.has_stamina(cost):
		return _reject(&"stamina")
	if not player.action_states.claim_state(ActionState.State.DODGING, self):
		return _reject(&"state")
	if not player.attributes.consume_stamina(cost):
		player.action_states.complete_owned_state(self)
		return _reject(&"stamina")
	_profile = profile.snapshot()
	direction = request.direction
	is_backstep = request.backstep
	elapsed = 0.0
	_active = true
	player.attributes.set_regeneration_blocked(&"dodge", true)
	dodge_started.emit(_profile.name, direction, is_backstep)
	return true


func advance_motion(delta: float) -> Vector3:
	if not _active or delta <= 0.0:
		return Vector3.ZERO
	var start := elapsed
	elapsed = minf(elapsed + delta, _profile.total)
	var a := clampf(start / float(_profile.movement), 0.0, 1.0)
	var b := clampf(elapsed / float(_profile.movement), 0.0, 1.0)
	# Integrate an ease-out distance curve exactly over this tick.
	var distance_this_tick: float = _profile.distance * ((2.0 * b - b * b) - (2.0 * a - a * a))
	return direction * distance_this_tick / delta


func finish_physics_step() -> void:
	if _active and elapsed >= _profile.total - 0.000001:
		_active = false
		player.attributes.set_regeneration_blocked(&"dodge", false)
		player.attributes.restart_stamina_regeneration_delay()
		player.action_states.complete_owned_state(self)
		dodge_finished.emit()


func _on_action_changed(_previous: int, current: int) -> void:
	if _active and current != ActionState.State.DODGING:
		_abort()


func _on_reset() -> void:
	_pending = {}
	_abort()


func _abort() -> void:
	if _active:
		_active = false
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.attributes.set_regeneration_blocked(&"dodge", false)
		dodge_finished.emit()


func _reject(reason: StringName) -> bool:
	dodge_rejected.emit(reason)
	return false
