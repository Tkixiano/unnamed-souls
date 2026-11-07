extends Node3D
## Attach to any actor/prop; no mesh, skeleton, health or AI dependency.

@export var target_id: StringName = &""
@export var lock_point: Node3D
@export var collision_body: CollisionObject3D
@export var available: bool = true
@export var alive: bool = true


func _ready() -> void:
	add_to_group("lockable_targets")


func is_available() -> bool:
	return available and alive and not target_id.is_empty() and is_inside_tree() \
		and not is_queued_for_deletion() and is_visible_in_tree() \
		and is_instance_valid(lock_point) and not lock_point.is_queued_for_deletion()


func get_aim_position() -> Vector3:
	return lock_point.global_position if is_instance_valid(lock_point) else global_position


func get_reference_position() -> Vector3:
	return global_position


func get_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if is_instance_valid(collision_body):
		exclusions.append(collision_body.get_rid())
	return exclusions
