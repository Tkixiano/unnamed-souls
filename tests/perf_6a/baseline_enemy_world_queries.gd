extends RefCounted
## Shared perception and direct-step probes; no navigation/FSM ownership.
static func has_sight(actor: CharacterBody3D, target: CharacterBody3D, eye_height: float = 1.35) -> bool:
	var excluded: Array[RID] = [actor.get_rid(),target.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*eye_height,target.global_position+Vector3.UP,1,excluded)
	return actor.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func can_step(actor: CharacterBody3D, direction: Vector3, radius: float = 0.35, height: float = 1.6, offset: float = 0.95) -> bool:
	if direction.is_zero_approx(): return false
	var excluded: Array[RID] = [actor.get_rid()]
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*offset)
	query.motion = direction.normalized()*maxf(actor.speed*0.3,0.25)
	query.collision_mask = 1
	query.exclude = excluded
	var space: PhysicsDirectSpaceState3D = actor.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty() or space.cast_motion(query)[0] < 0.999: return false
	var ahead: Vector3 = actor.global_position+query.motion
	var ground := PhysicsRayQueryParameters3D.create(ahead+Vector3.UP*0.6,ahead-Vector3.UP*0.4,1,excluded)
	var hit: Dictionary = space.intersect_ray(ground)
	return not hit.is_empty() and hit.normal.dot(Vector3.UP) > 0.7 and absf(hit.position.y-actor.global_position.y) < 0.35
