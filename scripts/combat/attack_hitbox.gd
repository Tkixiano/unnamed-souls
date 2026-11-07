extends Area3D
## Logical activation gates immediate shape queries; Area overlap caches are not damage authority.

const Hurtbox = preload("res://scripts/combat/hurtbox.gd")
const DebugGeometry = preload("res://scripts/combat/combat_debug_geometry.gd")
signal hit_confirmed(actor: Node, damage: float, swing_id: int)
signal impact_resolved(actor: Node, result: Dictionary)

@export var debug_enabled: bool = true
var hit_count: int = 0
var _enabled: bool = false
var _attacker: Node
var _faction: StringName
var _damage: float = 0.0
var _context: Dictionary = {}
var _swing_id: int = 0
var _hit_actors: Dictionary = {}
var _debug: MeshInstance3D
var _default_shape: Shape3D
var _default_position: Vector3
@onready var collider: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_default_shape = collider.shape
	_default_position = position
	_debug = MeshInstance3D.new()
	_debug.mesh = DebugGeometry.wire_box((collider.shape as BoxShape3D).size,Color(1.0,0.5,0.2))
	add_child(_debug)
	set_active(false)

func configure_volume(data: Dictionary = {}) -> void:
	# Shapes are copied per swing; authored resources remain immutable.
	var shape: Shape3D = data.get("hitbox_shape")
	collider.shape = shape.duplicate() if shape != null else _default_shape
	position = data.get("hitbox_offset",_default_position) if shape != null else _default_position
	if collider.shape is BoxShape3D:
		_debug.mesh = DebugGeometry.wire_box(collider.shape.size,Color(1,0.5,0.2))


func begin_swing(attacker: Node, faction: StringName, damage: float, swing_id: int, context: Dictionary = {}) -> void:
	_attacker = attacker
	_faction = faction
	_damage = damage
	_context = context.duplicate()
	_swing_id = swing_id
	_hit_actors.clear()
	hit_count = 0
	set_active(false)


func is_active() -> bool:
	return _enabled

func set_attack_direction(direction: Vector3) -> void:
	_context["direction"] = direction


func set_active(value: bool) -> void:
	_enabled = value
	collision_layer = 4 if value else 0
	if is_instance_valid(collider):
		collider.set_deferred("disabled",not value)
	if is_instance_valid(_debug):
		_debug.visible = debug_enabled and value


func sample_hits() -> void:
	if not _enabled or not is_instance_valid(_attacker):
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = collider.shape
	query.transform = collider.global_transform
	query.collision_mask = 8
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var results := get_world_3d().direct_space_state.intersect_shape(query,32)
	var sampled_swing := _swing_id
	for result in results:
		if not _enabled or _swing_id != sampled_swing or not is_instance_valid(_attacker):
			break
		var hurtbox = result.collider
		if not is_instance_valid(hurtbox) or not hurtbox is Hurtbox or not hurtbox.can_target(_attacker,_faction):
			continue
		var actor: Node = hurtbox.actor
		var actor_id: int = actor.get_instance_id()
		if _hit_actors.has(actor_id) or not _unobstructed(hurtbox):
			continue
		# Reserve before emitting callbacks to prevent re-entrant duplicate damage.
		_hit_actors[actor_id] = true
		var resolution: Dictionary = hurtbox.resolve_hit(_attacker,_faction,_damage,_swing_id,_context)
		var applied: float = resolution.damage
		if is_instance_valid(actor):
			impact_resolved.emit(actor,resolution)
		if applied > 0.0:
			hit_count += 1
			if is_instance_valid(actor):
				hit_confirmed.emit(actor,applied,sampled_swing)
		if not resolution.consumed:
			_hit_actors.erase(actor_id)


func _unobstructed(hurtbox: Hurtbox) -> bool:
	var excluded: Array[RID] = []
	if _attacker is CollisionObject3D:
		excluded.append(_attacker.get_rid())
	if is_instance_valid(hurtbox.physical_body):
		excluded.append(hurtbox.physical_body.get_rid())
	var origin: Vector3 = _attacker.global_position + Vector3.UP
	var ray := PhysicsRayQueryParameters3D.create(origin,hurtbox.global_position,1,excluded)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
