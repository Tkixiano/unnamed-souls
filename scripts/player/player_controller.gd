extends CharacterBody3D
## Physics, facing and locomotion are separate; no combat/animation dependencies.

const SprintDodgeInput = preload("res://scripts/player/sprint_dodge_input.gd")
const ActorAttributes = preload("res://scripts/systems/actor_attributes.gd")
const ActionState = preload("res://scripts/player/action_state.gd")
const DodgeController = preload("res://scripts/player/dodge_controller.gd")
const AttackController = preload("res://scripts/player/attack_controller.gd")
const DefenseController = preload("res://scripts/combat/defense_controller.gd")
const RiposteController = preload("res://scripts/combat/riposte_controller.gd")
const CriticalVulnerability = preload("res://scripts/combat/critical_vulnerability.gd")
const GripController = preload("res://scripts/player/grip_controller.gd")
const EstusController = preload("res://scripts/player/estus_controller.gd")
@export var controls_enabled: bool = true
@export var combat_faction: StringName = &"player"

enum LocomotionState { IDLE, WALK, RUN }

signal locomotion_state_changed(state: LocomotionState)
signal sprint_dodge_released(held_seconds: float, was_long_press: bool)

@export_group("Locomoción")
@export_range(0.1, 10.0, 0.1, "suffix:m/s") var walk_speed: float = 3.2
@export_range(0.1, 15.0, 0.1, "suffix:m/s") var run_speed: float = 6.0
@export_range(0.1, 60.0, 0.1, "suffix:m/s²") var acceleration: float = 14.0
@export_range(0.1, 60.0, 0.1, "suffix:m/s²") var deceleration: float = 20.0

@export_group("Entrada")
@export_range(0.0, 0.9, 0.01) var input_deadzone: float = 0.22
@export_range(0.05, 1.0, 0.01, "suffix:s") var sprint_hold_threshold: float = 0.25

@export_group("Orientación visual")
@export_range(1.0, 1080.0, 1.0, "suffix:°/s") var turn_speed: float = 540.0
@export var orient_to_movement: bool = true
@export var movement_camera: Camera3D

@export_group("Stamina de carrera")
@export_range(0.0, 100.0, 0.5, "suffix:pt/s") var sprint_stamina_cost: float = 12.0
@export_range(1.0, 100.0, 1.0) var sprint_resume_stamina: float = 15.0

var locomotion_state: LocomotionState = LocomotionState.IDLE
var movement_input: Vector2 = Vector2.ZERO
var movement_direction: Vector3 = Vector3.ZERO
var horizontal_speed: float = 0.0
var is_sprinting: bool = false
var checkpoint_input_blocked: bool = false
const CHECKPOINT_ACTIONS = ["light_attack","heavy_attack","block","parry","sprint_dodge","use_item","two_hand_toggle","interact","lock_on"]

var _sprint_button := SprintDodgeInput.new()
var _movement_reference: Vector3 = Vector3.ZERO
var _sprint_exhausted: bool = false
@onready var visual: Node3D = $Visual
@onready var attributes: ActorAttributes = $Attributes
@onready var action_states: ActionState = $ActionState
@onready var dodge_controller: DodgeController = $DodgeController
@onready var attack_controller: AttackController = $AttackController
@onready var defense_controller: DefenseController = $DefenseController
@onready var riposte_controller: RiposteController = $RiposteController
@onready var critical_vulnerability: CriticalVulnerability = $CriticalVulnerability
@onready var grip_controller: GripController = $GripController
@onready var estus_controller: EstusController = $EstusController


func _ready() -> void:
	_sprint_button.released.connect(_on_sprint_dodge_released)
	attributes.died.connect(_on_died)
	attributes.fully_restored.connect(_on_fully_restored)
	action_states.state_changed.connect(_on_action_state_changed)
	dodge_controller.initialize()
	attack_controller.initialize()
	defense_controller.initialize()
	riposte_controller.initialize()
	critical_vulnerability.initialize()
	grip_controller.initialize()
	estus_controller.initialize()
	attack_controller.faction = combat_faction
	$Hurtbox.faction = combat_faction
	if not controls_enabled:
		attack_controller.input_enabled = false
		dodge_controller.input_enabled = false
		defense_controller.input_enabled = false
		grip_controller.input_enabled = false
		estus_controller.input_enabled = false


func _input(event: InputEvent) -> void:
	if controls_enabled and can_move() and event.is_action("sprint_dodge") and not event.is_echo():
		# Also capture short press/release pairs that occur between physics ticks.
		_sprint_button.set_pressed(Input.is_action_pressed("sprint_dodge"))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_sprint_button.cancel()


func _physics_process(delta: float) -> void:
	if checkpoint_input_blocked:
		var held := false
		for action in CHECKPOINT_ACTIONS:
			held = held or Input.is_action_pressed(action)
		if not held:
			checkpoint_input_blocked = false
	movement_input = Input.get_vector(
		"move_left", "move_right", "move_forward", "move_backward", input_deadzone)
	if not controls_enabled:
		movement_input = Vector2.ZERO
	# Polling also supports Input.action_press in technical tests.
	_sprint_button.set_pressed(controls_enabled and Input.is_action_pressed("sprint_dodge"))
	_sprint_button.advance(delta, sprint_hold_threshold)
	grip_controller.process_request()
	grip_controller.advance_clock(delta)
	defense_controller.process_requests()
	defense_controller.advance_clock(delta)
	estus_controller.process_request()
	estus_controller.advance_clock(delta)
	dodge_controller.process_pending_request()
	attack_controller.process_pending_request()
	attack_controller.advance_clock(delta)
	riposte_controller.advance_clock(delta)
	if not can_move():
		movement_input = Vector2.ZERO
		_sprint_button.cancel()
	movement_direction = resolve_movement_direction(movement_input)
	_update_sprint(delta)
	if dodge_controller.is_active():
		var dodge_velocity := dodge_controller.advance_motion(delta)
		velocity.x = dodge_velocity.x
		velocity.z = dodge_velocity.z
	elif can_move():
		_update_horizontal_velocity(delta)
	else:
		velocity.x = 0.0
		velocity.z = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	dodge_controller.finish_physics_step()
	attack_controller.after_physics_step()
	riposte_controller.after_physics_step()
	horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if orient_to_movement and not movement_direction.is_zero_approx():
		face_direction(movement_direction, delta)
	_update_locomotion_state()
	attack_controller.sync_idle_pose()
	grip_controller.sync_visual()


func camera_relative_direction(input_vector: Vector2) -> Vector3:
	var camera := movement_camera
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	if is_instance_valid(camera):
		forward = -camera.global_basis.z
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	# get_vector supplies a circular deadzone and caps the diagonal length to 1.
	return right * input_vector.x - forward * input_vector.y


func set_movement_reference(forward: Vector3) -> void:
	# Optional horizontal basis supplied by another component. Zero restores camera.
	_movement_reference = Vector3(forward.x, 0.0, forward.z).normalized()


func clear_movement_reference() -> void:
	_movement_reference = Vector3.ZERO


func has_movement_reference() -> bool:
	return not _movement_reference.is_zero_approx()


func resolve_movement_direction(input_vector: Vector2) -> Vector3:
	if _movement_reference.is_zero_approx():
		return camera_relative_direction(input_vector)
	return _movement_reference.cross(Vector3.UP) * input_vector.x - _movement_reference * input_vector.y


func is_invulnerable() -> bool:
	return dodge_controller.is_invulnerable()


func can_receive_attack() -> bool:
	return attributes.current_health > 0.0 and action_states.current_state != ActionState.State.DEAD and not is_invulnerable()


func _update_horizontal_velocity(delta: float) -> void:
	var speed := run_speed if is_sprinting else walk_speed
	if defense_controller.is_blocking():
		speed *= defense_controller.movement_multiplier
	var target := movement_direction * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var braking := target.is_zero_approx() or horizontal.dot(target) < 0.0 \
		or target.length_squared() < horizontal.length_squared()
	var rate := deceleration if braking else acceleration
	horizontal = horizontal.move_toward(target, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func face_direction(direction: Vector3, delta: float) -> void:
	# Public facing entry point: future lock-on can disable automatic facing and
	# supply its own direction. Only Visual rotates; physics remains independent.
	if not can_move() or defense_controller.is_blocking():
		return
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001:
		return
	var target_yaw := atan2(-flat.x, -flat.z)
	var angles := visual.global_rotation
	angles.y = rotate_toward(angles.y, target_yaw, deg_to_rad(turn_speed) * delta)
	visual.global_rotation = angles


func face_attack_direction(direction: Vector3) -> void:
	# AttackController has already applied the configured angular limits.
	if action_states.current_state == ActionState.State.ATTACKING:
		var angles := visual.global_rotation
		angles.y = atan2(-direction.x,-direction.z)
		visual.global_rotation = angles


func _update_locomotion_state() -> void:
	var next_state := LocomotionState.IDLE
	if horizontal_speed > 0.05:
		next_state = LocomotionState.RUN if is_sprinting else LocomotionState.WALK
	if next_state != locomotion_state:
		locomotion_state = next_state
		locomotion_state_changed.emit(locomotion_state)


func _on_sprint_dodge_released(held_seconds: float, was_long_press: bool) -> void:
	sprint_dodge_released.emit(held_seconds, was_long_press)


func can_move() -> bool:
	return can_accept_action_input() and (action_states.can_move() or defense_controller.is_blocking())


func can_lock_on() -> bool:
	return can_accept_action_input()

func can_accept_action_input() -> bool:
	return not checkpoint_input_blocked and attributes.current_health > 0.0 and action_states.current_state != ActionState.State.DEAD

func restore_at_checkpoint(spawn: Transform3D, relocate: bool = true) -> void:
	# Existing restore signals cancel action owners, pending requests and critical pairs.
	checkpoint_input_blocked = true
	attributes.restore_all()
	clear_movement_reference()
	velocity = Vector3.ZERO
	movement_input = Vector2.ZERO
	movement_direction = Vector3.ZERO
	horizontal_speed = 0.0
	if relocate:
		global_position = spawn.origin
		var forward: Vector3 = -spawn.basis.z
		visual.global_rotation = Vector3(0,atan2(-forward.x,-forward.z),0)
	_update_locomotion_state()
	attack_controller.hitbox.set_active(false)
	attack_controller.sync_idle_pose()
	grip_controller.sync_visual()
	reset_physics_interpolation()


func _update_sprint(delta: float) -> void:
	is_sprinting = false
	if _sprint_exhausted and attributes.current_stamina >= minf(sprint_resume_stamina, attributes.max_stamina):
		_sprint_exhausted = false
	var requested := _sprint_button.is_long_press and not movement_input.is_zero_approx() and action_states.can_sprint()
	if requested and not _sprint_exhausted:
		var cost := maxf(sprint_stamina_cost, 0.0) * delta
		if cost > 0.0 and attributes.current_stamina <= cost:
			attributes.consume_stamina(attributes.current_stamina)
			_sprint_exhausted = true
		else:
			is_sprinting = attributes.consume_stamina(cost)
	attributes.set_regeneration_blocked(&"sprint", is_sprinting)


func _on_died() -> void:
	action_states.transition_to(ActionState.State.DEAD)


func _on_action_state_changed(_previous: int, _current: int) -> void:
	attributes.set_regeneration_blocked(&"action_state", action_states.blocks_regeneration() and not defense_controller.is_blocking())
	if not can_move():
		is_sprinting = false
		velocity.x = 0.0
		velocity.z = 0.0
		_sprint_button.cancel()
		attributes.set_regeneration_blocked(&"sprint", false)


func _on_fully_restored() -> void:
	_sprint_exhausted = false
	is_sprinting = false
	_sprint_button.cancel()
	action_states.reset_to_free()
	attributes.set_regeneration_blocked(&"action_state", action_states.blocks_regeneration())


func face_defense_direction(direction: Vector3) -> void:
	if defense_controller.is_blocking():
		visual.global_rotation = Vector3(0,atan2(-direction.x,-direction.z),0)

func get_defense_controller() -> Node:
	return defense_controller

func get_riposte_controller() -> Node:
	return riposte_controller

func get_attack_variant(kind: int) -> Resource:
	return grip_controller.get_attack_profile(kind)

func get_critical_vulnerability() -> Node:
	return critical_vulnerability

func interrupt_attack_for_critical() -> bool:
	return attack_controller.interrupt_for_parry()

func can_interrupt_for_backstab() -> bool:
	return attack_controller.is_active() and action_states.current_state == ActionState.State.ATTACKING

func is_critical_committed() -> bool:
	return riposte_controller.is_active() or critical_vulnerability.is_reserved()
