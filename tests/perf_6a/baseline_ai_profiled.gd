extends Node
var perf: Dictionary = {}
func perf_add(key: String, value: int) -> void:
	perf[key] = int(perf.get(key,0))+value
## Direct pursuit with solid/ground probes. No navmesh or alternate-route search.
const Actions = preload("res://scripts/player/action_state.gd")
const Queries = preload("res://tests/perf_6a/baseline_queries_profiled.gd")
enum State { IDLE, ALERT, CHASE, ATTACK, RECOVERY, STAGGERED, DEAD, RETURNING }
signal state_changed(previous: State, current: State)
@export var actor: CharacterBody3D
@export var target: CharacterBody3D
@export var enabled: bool = true
@export_group("Percepción")
@export var detection_radius: float = 7.0
@export_range(1,360,1) var vision_angle: float = 130.0
# Legacy serialized tuning kept for scene/test compatibility. Persistent aggro
# no longer uses distance or an unseen timeout to forget a living target.
@export var loss_radius: float = 12.0
@export var unseen_tolerance: float = 1.2
@export var maximum_pursuit_distance: float = 8.0
@export var initial_delay: float = 1.0
@export var alert_duration: float = 0.45
@export_group("Decisiones")
@export var preferred_distance: float = 1.85
@export var attack_range: float = 1.75
@export var attack_half_angle: float = 15.0
@export var decision_time: float = 0.9
@export var decision_variation: float = 0.2
@export var maximum_consecutive_attacks: int = 2
@export var extended_pause: float = 2.0
@export_range(0,1,0.05) var reposition_chance: float = 0.35
@export var random_seed: int = 3101
@export_group("Reacción")
@export var interruption_threshold: float = 15.0
@export var stagger_duration: float = 0.65
var state: State = State.IDLE
var origin: Vector3
var origin_yaw: float = 0.0
var decision_remaining: float = 0.0
var _elapsed: float = 0.0
var _acquired: bool = false
var _consecutive: int = 0
var _reposition: float = 0.0
var _stagger_remaining: float = 0.0
var _rng := RandomNumberGenerator.new()

func initialize() -> void:
	origin = actor.global_position
	origin_yaw = actor.visual.global_rotation.y
	actor.attack_controller.attack_finished.connect(_on_attack_finished)
	actor.hurtbox.impact_resolved.connect(_on_impact)
	actor.attributes.died.connect(_on_died)
	actor.attributes.fully_restored.connect(reset_brain)
	reset_brain()

func reset_brain() -> void:
	_rng.seed = random_seed
	_acquired = false
	_consecutive = 0
	_reposition = 0.0
	_stagger_remaining = 0.0
	decision_remaining = initial_delay
	_change(State.IDLE)
	set_physics_process(true)

func state_name() -> String:
	return State.keys()[state]

func has_aggro() -> bool:
	return _acquired and target_alive()

func target_alive() -> bool:
	return is_instance_valid(target) and not target.is_queued_for_deletion() and target.is_inside_tree() \
		and target.attributes.current_health > 0.0 and target.action_states.current_state != Actions.State.DEAD

func direction_to_target() -> Vector3:
	if not target_alive(): return Vector3.ZERO
	var direction: Vector3 = target.global_position-actor.global_position
	direction.y = 0.0
	return direction.normalized()

func has_line_of_sight() -> bool:
	if not target_alive(): return false
	return Queries.has_sight(actor,target)

func raw_can_detect() -> bool:
	if not target_alive() or actor.global_position.distance_to(target.global_position) > detection_radius:
		return false
	return (-actor.visual.global_basis.z).dot(direction_to_target()) >= cos(deg_to_rad(vision_angle*0.5)) and has_line_of_sight()

func raw__physics_process(delta: float) -> void:
	actor.set_move_intent(Vector3.ZERO)
	if not enabled or state == State.DEAD: return
	decision_remaining = maxf(decision_remaining-delta,0.0)
	# A dead/removed protagonist cannot be pursued or attacked, even while this
	# soldier is staggered. The checkpoint restores the authored target in place.
	if not is_instance_valid(target): target = null
	if not target_alive():
		_acquired = false
		if actor.attack_controller.is_active(): actor.attack_controller.interrupt_for_parry()
		if state != State.IDLE and state != State.STAGGERED: _change(State.RETURNING)
	if actor.action_states.current_state == Actions.State.STAGGERED:
		_change(State.STAGGERED)
		if _stagger_remaining > 0.0:
			_stagger_remaining = maxf(_stagger_remaining-delta,0.0)
			if _stagger_remaining == 0.0:
				actor.action_states.complete_owned_state(self)
		return
	if state == State.STAGGERED:
		decision_remaining = _next_wait()
		_change(State.RECOVERY if _acquired else State.RETURNING)
	if actor.attack_controller.is_active():
		_change(State.RECOVERY if actor.attack_controller.phase == 3 else State.ATTACK)
		return
	if actor.action_states.current_state != Actions.State.FREE: return
	if state == State.RETURNING:
		_return_home(delta)
		return
	if state == State.IDLE:
		if decision_remaining <= 0.0 and can_detect():
			_acquired = true
			_change(State.ALERT)
		return
	if not _acquired: return
	var distance: float = actor.global_position.distance_to(target.global_position)
	# Acquisition is visual; retention is persistent until lifecycle reset.
	# Travel probes and the attack LOS check below remain mandatory.
	var toward := direction_to_target()
	actor.face_direction(toward,delta)
	if state == State.ALERT:
		_elapsed += delta
		if _elapsed + 0.0000001 >= alert_duration: _change(State.CHASE)
		return
	if state == State.RECOVERY:
		if decision_remaining > 0.0:
			if _reposition != 0.0 and distance < preferred_distance+0.5:
				_try_travel(toward.cross(Vector3.UP)*_reposition*0.45)
			return
		_change(State.CHASE)
	if distance <= attack_range and has_line_of_sight() and decision_remaining <= 0.0 \
		and (-actor.visual.global_basis.z).dot(toward) >= cos(deg_to_rad(attack_half_angle)):
		if actor.attack_controller.request_attack(0):
			_change(State.ATTACK)
		return
	if distance > preferred_distance:
		_try_travel(toward)
	elif distance > attack_range:
		_try_travel(toward*0.4)
	elif distance < 1.2:
		_try_travel(-toward*0.35)

func _return_home(delta: float) -> void:
	var toward: Vector3 = origin-actor.global_position
	toward.y = 0.0
	if toward.length() <= 0.15:
		actor.face_direction(Vector3(-sin(origin_yaw),0,-cos(origin_yaw)),delta)
		decision_remaining = maxf(initial_delay,0.5)
		_change(State.IDLE)
		return
	actor.face_direction(toward,delta)
	_try_travel(toward.normalized()*minf(toward.length(),1.0))

func _try_travel(direction: Vector3) -> void:
	if can_travel(direction): actor.set_move_intent(direction)

func raw_can_travel(direction: Vector3) -> bool:
	return Queries.can_step(actor,direction)

func _next_wait() -> float:
	return maxf(0.1,decision_time+_rng.randf_range(-decision_variation,decision_variation))

func _on_attack_finished(_attack_name: StringName, completed: bool) -> void:
	if not completed or state == State.DEAD: return
	_consecutive += 1
	decision_remaining = _next_wait()
	if _consecutive >= maxi(maximum_consecutive_attacks,1):
		decision_remaining += maxf(extended_pause,0.0)
		_consecutive = 0
	_reposition = (1.0 if _rng.randf() < 0.5 else -1.0) if _rng.randf() < reposition_chance else 0.0
	_change(State.RECOVERY)

func _on_impact(result: Dictionary) -> void:
	if result.damage < interruption_threshold or result.damage <= 0.0 or result.outcome != &"normal" \
		or actor.attributes.current_health <= 0.0 or actor.critical_vulnerability.is_reserved():
		return
	if actor.attack_controller.is_active(): actor.attack_controller.interrupt_for_parry()
	if actor.action_states.claim_state(Actions.State.STAGGERED,self):
		_stagger_remaining = maxf(stagger_duration,0.01)
		_change(State.STAGGERED)

func _on_died() -> void:
	_acquired = false
	actor.set_move_intent(Vector3.ZERO)
	_change(State.DEAD)
	set_physics_process(false)

func _change(next: State) -> void:
	if state == next: return
	var previous := state
	state = next
	_elapsed = 0.0
	state_changed.emit(previous,state)

func _physics_process(delta: float) -> void:
	var begin := Time.get_ticks_usec()
	raw__physics_process(delta)
	perf_add("_physics_process_us",Time.get_ticks_usec()-begin)
	perf_add("_physics_process_calls",1)

func can_detect() -> bool:
	var begin := Time.get_ticks_usec()
	var result: bool = raw_can_detect()
	perf_add("can_detect_us",Time.get_ticks_usec()-begin)
	perf_add("can_detect_calls",1)
	return result

func can_travel(direction: Vector3) -> bool:
	var begin := Time.get_ticks_usec()
	var result: bool = raw_can_travel(direction)
	perf_add("can_travel_us",Time.get_ticks_usec()-begin)
	perf_add("can_travel_calls",1)
	return result
