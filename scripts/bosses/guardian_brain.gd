extends Node
const Actions = preload("res://scripts/player/action_state.gd")
const Queries = preload("res://scripts/enemies/enemy_world_queries.gd")
const VariantProfile = preload("res://scripts/combat/attack_variant.gd")
enum State { IDLE, INTRO, APPROACH, REPOSITION, ATTACK, RECOVERY, PHASE_TRANSITION, STAGGERED, DEAD }
signal state_changed(previous: State, current: State)
signal encounter_started
signal encounter_ended(reason: StringName)
signal phase_changed(phase: int)
signal victory
signal pattern_started(id: StringName)
@export var actor: CharacterBody3D
@export var target: CharacterBody3D
@export var warning_mesh: MeshInstance3D
@export var transition_marker: MeshInstance3D
@export var patterns: Array[Resource] = []
@export var enabled: bool = true
@export_group("Encuentro y movimiento")
@export var arena_half_extents: Vector2 = Vector2(8.8,8.8)
@export var arena_center: Vector3 = Vector3.ZERO
@export var intro_duration: float = 1.0
@export var preferred_distance: float = 2.7
@export var reposition_duration: float = 0.6
@export var decision_time: float = 0.85
@export var decision_variation: float = 0.15
@export var recent_pattern_limit: int = 1
@export var random_seed: int = 3301
@export_group("Fase 2")
@export_range(0.1,0.9,0.05) var phase_health_ratio: float = 0.5
@export var transition_duration: float = 1.4
@export_range(0.5,1,0.05) var phase_two_recovery_multiplier: float = 0.8
@export_range(0.5,1,0.05) var phase_two_decision_multiplier: float = 0.7
@export_group("Stagger")
@export var interruption_threshold: float = 55.0
@export var stagger_duration: float = 0.8
var state: State = State.IDLE
var origin: Vector3
var origin_yaw: float = 0.0
var encounter_active: bool = false
var phase_two: bool = false
var transition_count: int = 0
var current_pattern: StringName = &"NONE"
var attack_resource: Resource
var decision_remaining: float = 0.0
var elapsed: float = 0.0
var _pending_transition: bool = false
var _sequence: Array[Resource] = []
var _sequence_index: int = 0
var _cooldowns: Dictionary = {}
var _history: Array[StringName] = []
var _rng := RandomNumberGenerator.new()
var _side: float = 1.0
var _restart_delay: float = 0.0
var _warning_material: StandardMaterial3D

func initialize() -> void:
	origin = actor.global_position
	origin_yaw = actor.visual.global_rotation.y
	actor.attributes.health_changed.connect(_on_health_changed)
	actor.attributes.fully_restored.connect(reset_brain)
	actor.attributes.died.connect(_on_died)
	actor.hurtbox.impact_resolved.connect(_on_impact)
	actor.attack_controller.attack_finished.connect(_on_attack_finished)
	actor.attack_controller.phase_changed.connect(_on_attack_phase)
	_warning_material = StandardMaterial3D.new()
	_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warning_mesh.material_override = _warning_material
	reset_brain()

func reset_brain() -> void:
	var was_active: bool = encounter_active
	encounter_active = false
	phase_two = false
	transition_count = 0
	_pending_transition = false
	_sequence.clear()
	attack_resource = null
	current_pattern = &"NONE"
	_cooldowns.clear()
	_history.clear()
	_rng.seed = random_seed
	decision_remaining = 0.0
	elapsed = 0.0
	_restart_delay = 1.5
	warning_mesh.visible = false
	transition_marker.visible = false
	_change(State.IDLE)
	phase_changed.emit(1)
	if was_active: encounter_ended.emit(&"reset")
	set_physics_process(true)

func state_name() -> String:
	return State.keys()[state]

func target_alive() -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.attributes.current_health > 0.0 and target.action_states.current_state != Actions.State.DEAD

func direction_to_target() -> Vector3:
	if not target_alive(): return Vector3.ZERO
	var toward: Vector3 = target.global_position-actor.global_position
	toward.y = 0.0
	return toward.normalized()

func inside_arena(point: Vector3) -> bool:
	var relative: Vector3 = point-arena_center
	return absf(relative.x) <= arena_half_extents.x and absf(relative.z) <= arena_half_extents.y

func start_encounter() -> bool:
	if not enabled or encounter_active or actor.boss_defeated_this_session or actor.attributes.current_health <= 0.0 \
		or not target_alive() or not inside_arena(target.global_position) or _restart_delay > 0.0 \
		or not Queries.has_sight(actor,target,2.0): return false
	encounter_active = true
	_change(State.INTRO)
	encounter_started.emit()
	return true

func _physics_process(delta: float) -> void:
	actor.set_move_intent(Vector3.ZERO)
	if not enabled or state == State.DEAD: return
	_restart_delay = maxf(_restart_delay-delta,0.0)
	if not encounter_active: return
	if not target_alive():
		_end_encounter(&"player_dead")
		return
	if not inside_arena(target.global_position) or not inside_arena(actor.global_position):
		actor.restore_at_checkpoint()
		return
	for id in _cooldowns: _cooldowns[id] = maxf(float(_cooldowns[id])-delta,0.0)
	if state == State.PHASE_TRANSITION:
		elapsed += delta
		if elapsed + 0.0000001 >= transition_duration:
			phase_two = true
			_pending_transition = false
			transition_count += 1
			actor.action_states.complete_owned_state(self)
			transition_marker.visible = false
			phase_changed.emit(2)
			decision_remaining = _next_wait()
			_change(State.REPOSITION)
		return
	if actor.action_states.current_state == Actions.State.STAGGERED:
		_change(State.STAGGERED)
		elapsed += delta
		if elapsed + 0.0000001 >= stagger_duration:
			actor.action_states.complete_owned_state(self) # No effect on a critical's owner.
		return
	if actor.attack_controller.is_active():
		_change(State.RECOVERY if actor.attack_controller.phase == 3 else State.ATTACK)
		return
	if actor.action_states.current_state != Actions.State.FREE: return
	if _pending_transition and _sequence.is_empty():
		_begin_transition()
		return
	decision_remaining = maxf(decision_remaining-delta,0.0)
	var toward := direction_to_target()
	actor.face_direction(toward,delta)
	if state == State.INTRO:
		elapsed += delta
		if elapsed + 0.0000001 >= intro_duration: _change(State.APPROACH)
		return
	if state == State.STAGGERED:
		decision_remaining = _next_wait()
		_change(State.REPOSITION)
	var distance: float = actor.global_position.distance_to(target.global_position)
	if decision_remaining > 0.0:
		_change(State.REPOSITION)
		if elapsed < reposition_duration:
			elapsed += delta
			_move(toward.cross(Vector3.UP)*_side*0.5)
		return
	var selected: Resource = choose_pattern()
	if selected != null:
		start_pattern(selected.pattern_id)
		return
	_change(State.APPROACH)
	if distance > preferred_distance: _move(toward)
	elif distance < 1.6: _move(-toward*0.4)
	else:
		_move(toward.cross(Vector3.UP)*_side*0.4)

func _move(direction: Vector3) -> void:
	var destination: Vector3 = actor.global_position+direction.normalized()*0.8
	if inside_arena(destination) and Queries.can_step(actor,direction,0.55,2.4,1.4):
		actor.set_move_intent(direction)

func eligible_patterns() -> Array[Resource]:
	var result: Array[Resource] = []
	if not encounter_active or not target_alive() or not actor.can_move() or _pending_transition \
		or state not in [State.APPROACH,State.REPOSITION,State.RECOVERY] \
		or decision_remaining > 0.0 or not Queries.has_sight(actor,target,2.0): return result
	var distance: float = actor.global_position.distance_to(target.global_position)
	var dot: float = (-actor.visual.global_basis.z).dot(direction_to_target())
	for pattern in patterns:
		if pattern == null or not pattern.is_valid(): continue
		var weight: float = pattern.phase_two_weight if phase_two else pattern.phase_one_weight
		if weight <= 0.0 or distance < pattern.minimum_distance or distance > pattern.maximum_distance \
			or dot < cos(deg_to_rad(pattern.half_angle)) or _cooldowns.get(pattern.pattern_id,0.0) > 0.0 \
			or pattern.pattern_id in _history: continue
		result.append(pattern)
	return result

func choose_pattern() -> Resource:
	var choices := eligible_patterns()
	var total: float = 0.0
	for pattern in choices: total += pattern.phase_two_weight if phase_two else pattern.phase_one_weight
	if total <= 0.0: return null
	var cursor: float = _rng.randf()*total
	for pattern in choices:
		cursor -= pattern.phase_two_weight if phase_two else pattern.phase_one_weight
		if cursor <= 0.0: return pattern
	return choices.back()

func start_pattern(id: StringName) -> bool:
	if actor.attack_controller.is_active() or not _sequence.is_empty(): return false
	for pattern in eligible_patterns():
		if pattern.pattern_id != id: continue
		_sequence.assign(pattern.attacks)
		_sequence_index = 0
		current_pattern = id
		if not _start_hit():
			_sequence.clear()
			current_pattern = &"NONE"
			return false
		_cooldowns[id] = pattern.cooldown
		_history.append(id)
		while _history.size() > maxi(recent_pattern_limit,1): _history.pop_front()
		pattern_started.emit(id)
		_change(State.ATTACK)
		return true
	return false

func _start_hit() -> bool:
	var source: Resource = _sequence[_sequence_index]
	attack_resource = source
	if phase_two:
		var variant := VariantProfile.new()
		variant.source = source
		variant.attack_name = source.attack_name
		variant.damage_multiplier = 1.0
		variant.stamina_multiplier = 1.0
		variant.recovery_multiplier = phase_two_recovery_multiplier
		attack_resource = variant
	return actor.attack_controller.request_attack(0)

func _on_attack_finished(_name: StringName, completed: bool) -> void:
	warning_mesh.visible = false
	if not completed:
		_sequence.clear()
		return
	if not encounter_active or not target_alive():
		_sequence.clear()
		return
	_sequence_index += 1
	# The complete two-hit pattern was committed; finish it before phase transition.
	if _sequence_index < _sequence.size() and _start_hit(): return
	_sequence.clear()
	decision_remaining = _next_wait()
	_side = 1.0 if _rng.randf() < 0.5 else -1.0
	_change(State.REPOSITION)

func _on_attack_phase(phase: int) -> void:
	warning_mesh.visible = current_pattern == &"RUIN_BURST" and phase in [1,2]
	if warning_mesh.visible:
		var shape: BoxShape3D = actor.attack_controller.hitbox.collider.shape
		var mesh := BoxMesh.new()
		mesh.size = Vector3(shape.size.x,0.025,shape.size.z)
		warning_mesh.mesh = mesh
		_warning_material.albedo_color = Color(1,0.15,0.05,0.5) if phase == 2 else Color(1,0.7,0.1,0.25)

func _on_health_changed(current: float, maximum: float) -> void:
	if current > 0.0 and not phase_two and transition_count == 0 and current <= maximum*phase_health_ratio:
		_pending_transition = true

func _begin_transition() -> void:
	if actor.action_states.claim_state(Actions.State.STAGGERED,self):
		_change(State.PHASE_TRANSITION)
		transition_marker.visible = true
		actor.attack_controller.hitbox.set_active(false)

func _on_impact(result: Dictionary) -> void:
	if not encounter_active or state == State.PHASE_TRANSITION or actor.attributes.current_health <= 0.0 \
		or result.outcome != &"normal" or result.damage < interruption_threshold or actor.critical_vulnerability.is_reserved(): return
	if actor.attack_controller.is_active():
		if actor.attack_controller.phase != 1: return # ACTIVE/RECOVERY have interruption armor.
		actor.attack_controller.interrupt_for_parry()
	if actor.action_states.claim_state(Actions.State.STAGGERED,self):
		_sequence.clear()
		_change(State.STAGGERED)

func _next_wait() -> float:
	var multiplier: float = phase_two_decision_multiplier if phase_two else 1.0
	return maxf(0.2,(decision_time+_rng.randf_range(-decision_variation,decision_variation))*multiplier)

func _end_encounter(reason: StringName) -> void:
	encounter_active = false
	_sequence.clear()
	if actor.attack_controller.is_active(): actor.attack_controller.interrupt_for_parry()
	actor.action_states.complete_owned_state(self)
	_pending_transition = false
	warning_mesh.visible = false
	transition_marker.visible = false
	_change(State.IDLE)
	encounter_ended.emit(reason)

func _on_died() -> void:
	encounter_active = false
	_sequence.clear()
	_pending_transition = false
	warning_mesh.visible = false
	transition_marker.visible = false
	_change(State.DEAD)
	encounter_ended.emit(&"defeated")
	victory.emit()
	set_physics_process(false)

func _change(next: State) -> void:
	if state == next: return
	var previous := state
	state = next
	elapsed = 0.0
	state_changed.emit(previous,state)
