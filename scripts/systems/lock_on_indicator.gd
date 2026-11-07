extends Control

@export var lock_controller: Node
@export var camera: Camera3D
var _point: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	visible = false
	if not is_instance_valid(lock_controller) or not is_instance_valid(camera) or not lock_controller.is_locked():
		return
	var target: Node3D = lock_controller.current_target
	if not is_instance_valid(target) or not target.is_available():
		return
	var world_point: Vector3 = target.get_aim_position()
	if camera.is_position_behind(world_point):
		return
	_point = camera.unproject_position(world_point)
	visible = get_viewport().get_visible_rect().has_point(_point)
	queue_redraw()


func _draw() -> void:
	draw_arc(_point, 9.0, 0.0, TAU, 24, Color(1.0, 0.87, 0.45), 2.0, true)
	draw_circle(_point, 2.0, Color(1.0, 0.95, 0.78))
