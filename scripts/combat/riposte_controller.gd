extends Node
const Actions = preload("res://scripts/player/action_state.gd")
enum Request { NO_TARGET, STARTED, REJECTED }
enum CriticalKind { RIPOSTE, BACKSTAB }
signal riposte_event(event: StringName)
@export var player: CharacterBody3D
@export var distance: float = 2.1
@export var facing_angle: float = 45.0
@export var target_facing_angle: float = 60.0
@export var stamina_cost: float = 30.0
@export var damage: float = 120.0
@export var duration: float = 1.05
@export var damage_time: float = 0.35
@export_group("Backstab")
@export var backstab_enabled: bool = true
@export var backstab_distance: float = 1.6
@export_range(1,80,1) var backstab_rear_half_angle: float = 40.0
@export_range(1,80,1) var backstab_facing_half_angle: float = 45.0
@export var backstab_cost: float = 30.0
@export var backstab_damage: float = 140.0
@export var backstab_duration: float = 1.2
@export var backstab_damage_time: float = 0.45
var elapsed: float = 0.0
var damage_applied: float = 0.0
var _active: bool = false
var _target: Node
var _struck: bool = false
var _kind: CriticalKind = CriticalKind.RIPOSTE
var _execution_duration: float = 0.0
var _execution_damage_time: float = 0.0
var _execution_damage: float = 0.0

func initialize() -> void:
	player.action_states.state_changed.connect(_on_state_changed)
	player.attributes.fully_restored.connect(_cancel)

func is_active() -> bool:
	return _active

func try_contextual() -> int:
	if not player.can_accept_action_input():
		return Request.REJECTED
	if _active:
		return Request.REJECTED
	if player.action_states.current_state != Actions.State.FREE:
		return Request.NO_TARGET
	var best: Node
	var kind: CriticalKind = CriticalKind.RIPOSTE
	var closest: float = INF
	for candidate in get_tree().get_nodes_in_group("critical_vulnerables"):
		if not candidate.is_available() or candidate.actor == player:
			continue
		var actor: Node3D = candidate.actor
		if actor.combat_faction == player.combat_faction or not _within_reach(candidate,CriticalKind.RIPOSTE):
			continue
		var d: float = player.global_position.distance_squared_to(actor.global_position)
		if d < closest:
			best = candidate
			closest = d
	if not is_instance_valid(best) and backstab_enabled:
		kind = CriticalKind.BACKSTAB
		for candidate in get_tree().get_nodes_in_group("critical_vulnerables"):
			if candidate.actor == player or not candidate.can_backstab() or candidate.actor.combat_faction == player.combat_faction \
				or not _within_reach(candidate,CriticalKind.BACKSTAB):
				continue
			var d: float = player.global_position.distance_squared_to(candidate.actor.global_position)
			if d < closest:
				best = candidate
				closest = d
	if not is_instance_valid(best):
		return Request.NO_TARGET
	var cost: float = stamina_cost if kind == CriticalKind.RIPOSTE else backstab_cost
	var execution_duration: float = duration if kind == CriticalKind.RIPOSTE else backstab_duration
	var hit_time: float = damage_time if kind == CriticalKind.RIPOSTE else backstab_damage_time
	var hit_damage: float = damage if kind == CriticalKind.RIPOSTE else backstab_damage
	for value in [cost,execution_duration,hit_time,hit_damage]:
		if not is_finite(value) or value < 0.0:
			return Request.REJECTED
	if hit_time >= execution_duration or not player.is_on_floor() or not player.attributes.has_stamina(cost):
		return Request.REJECTED
	var reserved: bool = best.reserve(self) if kind == CriticalKind.RIPOSTE else best.reserve_backstab(self)
	if not reserved:
		return Request.REJECTED
	if not player.action_states.claim_state(Actions.State.ATTACKING,self):
		best.finish_reservation(self)
		return Request.REJECTED
	_target = best
	_kind = kind
	_execution_duration = execution_duration
	_execution_damage_time = hit_time
	_execution_damage = hit_damage * player.grip_controller.get_critical_multiplier()
	player.attributes.consume_stamina(cost)
	_active = true
	elapsed = 0.0
	damage_applied = 0.0
	_struck = false
	riposte_event.emit(&"riposte_started" if kind == CriticalKind.RIPOSTE else &"backstab_started")
	return Request.STARTED

func advance_clock(delta: float) -> void:
	if not _active:
		return
	if not is_instance_valid(_target) or not _target.is_reserved():
		_finish()
		return
	elapsed += delta

func after_physics_step() -> void:
	if not _active:
		return
	if not _struck and elapsed + 0.0000001 >= _execution_damage_time:
		_struck = true
		var actor: Node3D = _target.actor
		if is_instance_valid(actor) and _within_reach(_target,_kind):
			var hurtbox: Node = _target.hurtbox
			if hurtbox:
				var result: Dictionary = hurtbox.resolve_hit(player,player.combat_faction,_execution_damage,0,{"critical_owner":self})
				damage_applied = result.damage
				riposte_event.emit(&"riposte_hit" if _kind == CriticalKind.RIPOSTE else &"backstab_hit")
	if elapsed + 0.0000001 >= _execution_duration:
		_finish()

func current_critical_name() -> StringName:
	return (&"RIPOSTE" if _kind == CriticalKind.RIPOSTE else &"BACKSTAB") if _active else &"NONE"

func _within_reach(candidate: Node, kind: CriticalKind) -> bool:
	var actor: Node3D = candidate.actor
	var toward: Vector3 = actor.global_position-player.global_position
	var reach: float = distance if kind == CriticalKind.RIPOSTE else backstab_distance
	if toward.length() > reach or absf(toward.y) > 1.0:
		return false
	toward.y = 0.0
	if toward.is_zero_approx():
		return false
	toward = toward.normalized()
	var actor_forward: Vector3 = -actor.visual.global_basis.z
	actor_forward.y = 0.0
	actor_forward = actor_forward.normalized()
	if kind == CriticalKind.RIPOSTE:
		if (-player.visual.global_basis.z).dot(toward) < cos(deg_to_rad(facing_angle)) \
			or actor_forward.dot(-toward) < cos(deg_to_rad(target_facing_angle)):
			return false
	elif actor_forward.dot(toward) < cos(deg_to_rad(backstab_rear_half_angle)) \
		or (-player.visual.global_basis.z).dot(toward) < cos(deg_to_rad(backstab_facing_half_angle)):
		return false
	var excluded: Array[RID] = [player.get_rid()]
	if is_instance_valid(candidate.hurtbox.physical_body):
		excluded.append(candidate.hurtbox.physical_body.get_rid())
	var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,actor.global_position+Vector3.UP,1,excluded)
	var space: PhysicsDirectSpaceState3D = player.get_world_3d().direct_space_state
	if not space.intersect_ray(ray).is_empty():
		return false
	# Clearance for a small body-width corridor, including obstacles below the ray.
	var shape := CapsuleShape3D.new()
	shape.radius = 0.2
	shape.height = 1.4
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,player.global_position+Vector3(0,0.9,0))
	query.motion = actor.global_position-player.global_position
	query.collision_mask = 1
	query.exclude = excluded
	return space.intersect_shape(query,1).is_empty() and space.cast_motion(query)[0] >= 0.999

func _finish() -> void:
	_cancel()
	player.attributes.restart_stamina_regeneration_delay()
	player.action_states.complete_owned_state(self)

func _cancel() -> void:
	_active = false
	if is_instance_valid(_target):
		_target.finish_reservation(self)
	_target = null
	_struck = true

func _on_state_changed(_previous: int, current: int) -> void:
	if current != Actions.State.ATTACKING:
		_cancel()
