extends Node3D
## Free orbit only. External mode is an interface, not a lock-on implementation.

enum ControlMode { FREE, EXTERNAL }

@export_group("Seguimiento")
@export var follow_target: Node3D
@export_range(0.0, 3.0, 0.05, "suffix:m") var follow_height: float = 1.25
@export_range(0.0, 40.0, 0.5, "suffix:1/s") var follow_smoothing: float = 14.0

@export_group("Órbita")
@export_range(10.0, 360.0, 1.0, "suffix:°/s") var horizontal_sensitivity: float = 150.0
@export_range(10.0, 360.0, 1.0, "suffix:°/s") var vertical_sensitivity: float = 110.0
@export_range(0.0, 0.9, 0.01) var input_deadzone: float = 0.22
@export var invert_vertical: bool = false
@export_range(-85.0, 0.0, 1.0, "suffix:°") var minimum_pitch: float = -65.0
@export_range(0.0, 80.0, 1.0, "suffix:°") var maximum_pitch: float = 35.0
@export_range(-180.0, 180.0, 1.0, "suffix:°") var initial_yaw: float = 0.0
@export_range(-85.0, 80.0, 1.0, "suffix:°") var initial_pitch: float = -18.0

@export_group("Distancia y colisión")
@export_range(1.0, 10.0, 0.1, "suffix:m") var normal_distance: float = 4.5
@export_range(0.1, 1.5, 0.05, "suffix:m") var minimum_distance: float = 0.55
@export_range(0.0, 30.0, 0.5, "suffix:1/s") var distance_recovery: float = 8.0

@export_group("Mouse técnico")
@export var mouse_enabled: bool = true
@export_range(0.01, 1.0, 0.01, "suffix:°/px") var mouse_sensitivity: float = 0.16

var control_mode: ControlMode = ControlMode.FREE
var _yaw: float = 0.0
var _pitch: float = 0.0
var _mouse_motion: Vector2 = Vector2.ZERO

@onready var yaw_pivot: Node3D = $YawPivot
@onready var pitch_pivot: Node3D = $YawPivot/PitchPivot
@onready var spring_arm: SpringArm3D = $YawPivot/PitchPivot/SpringArm3D
@onready var camera: Camera3D = $YawPivot/PitchPivot/SpringArm3D/Camera3D


func _ready() -> void:
	set_orbit_angles(deg_to_rad(initial_yaw), deg_to_rad(initial_pitch))
	set_follow_target(follow_target)
	_sync_distance_settings()


func _unhandled_input(event: InputEvent) -> void:
	if control_mode != ControlMode.FREE or not mouse_enabled:
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_mouse_motion += event.relative
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_mouse_motion = Vector2.ZERO


func _physics_process(delta: float) -> void:
	# Player runs at priority 0, rig at 10, collision arm at 20.
	if is_instance_valid(follow_target):
		var target_position := follow_target.global_position + Vector3.UP * follow_height
		var weight := 1.0 if follow_smoothing <= 0.0 else 1.0 - exp(-follow_smoothing * delta)
		global_position = global_position.lerp(target_position, weight)
	if control_mode == ControlMode.FREE:
		var stick := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down", input_deadzone)
		var vertical_sign := -1.0 if invert_vertical else 1.0
		set_orbit_angles(
			_yaw - deg_to_rad(stick.x * horizontal_sensitivity * delta + _mouse_motion.x * mouse_sensitivity),
			_pitch - deg_to_rad(stick.y * vertical_sensitivity * delta + _mouse_motion.y * mouse_sensitivity) * vertical_sign)
	_mouse_motion = Vector2.ZERO
	_sync_distance_settings()


func _sync_distance_settings() -> void:
	spring_arm.spring_length = maxf(normal_distance, minimum_distance)
	spring_arm.minimum_distance = minimum_distance
	spring_arm.recovery_speed = distance_recovery


func get_follow_target() -> Node3D:
	return follow_target


func set_follow_target(target: Node3D, snap: bool = true) -> void:
	follow_target = target
	if not is_node_ready():
		return
	spring_arm.clear_excluded_objects()
	if target is CollisionObject3D:
		spring_arm.add_excluded_object(target.get_rid())
	if snap:
		snap_to_target()


func snap_to_target() -> void:
	if is_instance_valid(follow_target):
		global_position = follow_target.global_position + Vector3.UP * follow_height
		reset_physics_interpolation()


func get_orbit_angles() -> Vector2:
	# Radians; yaw wraps at ±PI, pitch is clamped.
	return Vector2(_yaw, _pitch)


func set_orbit_angles(yaw_radians: float, pitch_radians: float) -> void:
	_yaw = wrapf(yaw_radians, -PI, PI)
	_pitch = clampf(pitch_radians, deg_to_rad(minimum_pitch), deg_to_rad(maximum_pitch))
	if is_node_ready():
		yaw_pivot.rotation.y = _yaw
		pitch_pivot.rotation.x = _pitch


func set_control_mode(mode: ControlMode) -> void:
	control_mode = mode
	_mouse_motion = Vector2.ZERO
