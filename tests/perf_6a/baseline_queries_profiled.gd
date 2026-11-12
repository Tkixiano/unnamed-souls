extends RefCounted
static var stats: Dictionary = {}
static func bump(key: String, value: int = 1) -> void:
	stats[key] = int(stats.get(key,0))+value
## Shared perception and direct-step probes; no navigation/FSM ownership.
static func has_sight(actor: CharacterBody3D, target: CharacterBody3D, eye_height: float = 1.35) -> bool:
	var excluded: Array[RID] = [actor.get_rid(),target.get_rid()]
	var ray := new_ray(actor.global_position+Vector3.UP*eye_height,target.global_position+Vector3.UP,1,excluded)
	return timed_ray(actor.get_world_3d().direct_space_state,ray,"los").is_empty()

static func can_step(actor: CharacterBody3D, direction: Vector3, radius: float = 0.35, height: float = 1.6, offset: float = 0.95) -> bool:
	if direction.is_zero_approx(): return false
	var excluded: Array[RID] = [actor.get_rid()]
	var shape := new_capsule()
	shape.radius = radius
	shape.height = height
	var query := new_shape_query()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*offset)
	query.motion = direction.normalized()*maxf(actor.speed*0.3,0.25)
	query.collision_mask = 1
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	if not timed_shape(space,query).is_empty() or timed_cast(space,query)[0] < 0.999: return false
	var ahead: Vector3 = actor.global_position+query.motion
	var ground := new_ray(ahead+Vector3.UP*0.6,ahead-Vector3.UP*0.4,1,excluded)
	var hit: Dictionary = timed_ray(space,ground,"ground")
	return not hit.is_empty() and hit.normal.dot(Vector3.UP) > 0.7 and absf(hit.position.y-actor.global_position.y) < 0.35

static func timed_shape(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D) -> Array[Dictionary]:
	var begin := Time.get_ticks_usec()
	var result := space.intersect_shape(query,1)
	bump("shape_us",Time.get_ticks_usec()-begin)
	bump("shape_calls")
	return result
static func timed_cast(space: PhysicsDirectSpaceState3D, query: PhysicsShapeQueryParameters3D) -> PackedFloat32Array:
	var begin := Time.get_ticks_usec()
	var result := space.cast_motion(query)
	bump("cast_us",Time.get_ticks_usec()-begin)
	bump("cast_calls")
	return result
static func timed_ray(space: PhysicsDirectSpaceState3D, query: PhysicsRayQueryParameters3D, kind: String) -> Dictionary:
	var begin := Time.get_ticks_usec()
	var result := space.intersect_ray(query)
	bump(kind+"_us",Time.get_ticks_usec()-begin)
	bump(kind+"_calls")
	return result
static func new_capsule() -> CapsuleShape3D:
	bump("capsule_allocations")
	return CapsuleShape3D.new()
static func new_shape_query() -> PhysicsShapeQueryParameters3D:
	bump("shape_query_allocations")
	return PhysicsShapeQueryParameters3D.new()
static func new_ray(a: Vector3,b: Vector3,mask: int,excluded: Array[RID]) -> PhysicsRayQueryParameters3D:
	bump("ray_query_allocations")
	return PhysicsRayQueryParameters3D.create(a,b,mask,excluded)
static func new_empty_ray() -> PhysicsRayQueryParameters3D:
	bump("ray_query_allocations")
	return PhysicsRayQueryParameters3D.new()
