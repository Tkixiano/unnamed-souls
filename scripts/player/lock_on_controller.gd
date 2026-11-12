extends Node
## Owns target selection and contextual movement; does not own physics or camera collision.

const LockableTarget = preload("res://scripts/systems/lockable_target.gd")
const PlayerController = preload("res://scripts/player/player_controller.gd")
const OrbitCamera = preload("res://scripts/systems/orbit_camera.gd")

signal target_changed(target: LockableTarget)
signal lock_released(reason: StringName)

@export_group("Referencias")
@export var player: PlayerController
@export var camera_rig: OrbitCamera

@export_group("Adquisición y pérdida")
@export_range(1.0, 30.0, 0.5, "suffix:m") var acquisition_distance: float = 14.0
@export_range(1.0, 40.0, 0.5, "suffix:m") var break_distance: float = 18.0
@export_range(5.0, 85.0, 1.0, "suffix:°") var acquisition_half_angle: float = 50.0
@export_range(0.05, 2.0, 0.05, "suffix:s") var occlusion_grace: float = 0.45
@export_flags_3d_physics var visibility_mask: int = 1

@export_group("Cambio lateral")
@export_range(0.3, 1.0, 0.05) var switch_threshold: float = 0.65
@export_range(0.05, 0.4, 0.05) var switch_neutral: float = 0.25

@export_group("Encuadre")
@export_range(0.5, 15.0, 0.5, "suffix:1/s") var camera_smoothing: float = 6.0
@export_range(30.0, 360.0, 5.0, "suffix:°/s") var maximum_camera_turn: float = 150.0
@export_range(0.1, 0.8, 0.05) var framing_weight: float = 0.5
@export_range(0.5, 4.0, 0.1, "suffix:m") var framing_height_bias: float = 2.0

var current_target: LockableTarget
var last_release_reason: StringName = &""
var _occluded_seconds: float = 0.0
var _switch_armed: bool = false
var _toggle_requests: int = 0
var _saved_orientation: bool = true
var _owns_lock: bool = false


func _ready() -> void:
	player.action_states.state_changed.connect(_on_player_action_state_changed)


func _on_player_action_state_changed(_previous: int, _current: int) -> void:
	if not player.can_lock_on():
		_toggle_requests = 0
		release_lock(&"dead")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("lock_on") and not event.is_echo():
		_toggle_requests += 1


func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(camera_rig):
		return
	if not player.can_lock_on():
		_toggle_requests = 0
		release_lock(&"dead")
		return
	for request in range(_toggle_requests):
		if is_locked():
			release_lock(&"manual")
		else:
			try_acquire()
	_toggle_requests = 0
	# A freed reference is distinct from a normal unlocked state.
	if not is_instance_valid(current_target):
		if _owns_lock:
			release_lock(&"invalid")
		return
	if not current_target.is_available():
		release_lock(&"unavailable")
		return
	if player.global_position.distance_to(current_target.get_reference_position()) > maxf(break_distance, acquisition_distance):
		release_lock(&"distance")
		return
	if not has_line_of_sight(current_target):
		_occluded_seconds += delta
		if _occluded_seconds >= occlusion_grace:
			release_lock(&"occlusion")
			return
	else:
		_occluded_seconds = 0.0
	# Locomotion changes do not release an otherwise valid target.
	_update_switch()
	var toward := current_target.get_reference_position() - player.global_position
	toward.y = 0.0
	if toward.length_squared() > 0.0001:
		player.set_movement_reference(toward)
		player.face_direction(toward, delta)
	_update_camera(delta)


func _exit_tree() -> void:
	if is_instance_valid(player) and is_instance_valid(camera_rig):
		release_lock(&"controller_removed")


func is_locked() -> bool:
	return _owns_lock and is_instance_valid(current_target)


func try_acquire() -> bool:
	if not player.can_lock_on():
		return false
	var best: LockableTarget
	var best_score := INF
	for node in get_tree().get_nodes_in_group("lockable_targets"):
		if not node is LockableTarget or not can_acquire(node):
			continue
		var screen := _screen_position(node)
		var score := screen.length_squared() + 0.03 * player.global_position.distance_to(node.get_reference_position()) / acquisition_distance
		if score < best_score or (is_equal_approx(score, best_score) and (best == null or String(node.target_id) < String(best.target_id))):
			best = node
			best_score = score
	if best == null:
		return false
	_set_target(best)
	return true


func can_acquire(target: LockableTarget) -> bool:
	if not is_instance_valid(target) or not target.is_available():
		return false
	if player.global_position.distance_to(target.get_reference_position()) > acquisition_distance:
		return false
	var camera := camera_rig.camera
	var offset := target.get_aim_position() - camera.global_position
	if offset.length_squared() < 0.0001 or camera.is_position_behind(target.get_aim_position()):
		return false
	if (-camera.global_basis.z).dot(offset.normalized()) < cos(deg_to_rad(acquisition_half_angle)):
		return false
	if not camera.get_viewport().get_visible_rect().has_point(camera.unproject_position(target.get_aim_position())):
		return false
	return has_line_of_sight(target)


func has_line_of_sight(target: LockableTarget) -> bool:
	if not is_instance_valid(target):
		return false
	var exclusions := target.get_collision_exclusions()
	exclusions.append(player.get_rid())
	var aim := target.get_aim_position()
	# Both view and protagonist must see the point: no acquisition around a wall.
	for origin in [camera_rig.camera.global_position, player.global_position + Vector3.UP * camera_rig.follow_height]:
		var query := PhysicsRayQueryParameters3D.create(origin, aim, visibility_mask, exclusions)
		if not player.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true


func switch_target(direction: int) -> bool:
	if not is_locked():
		return false
	var anchor := _screen_position(current_target)
	var best: LockableTarget
	var best_score := INF
	for node in get_tree().get_nodes_in_group("lockable_targets"):
		if not node is LockableTarget or node == current_target or not can_acquire(node):
			continue
		var screen_delta := _screen_position(node) - anchor
		if screen_delta.x * direction <= 0.015:
			continue
		var score := absf(screen_delta.x) + 0.25 * absf(screen_delta.y)
		if score < best_score or (is_equal_approx(score, best_score) and (best == null or String(node.target_id) < String(best.target_id))):
			best = node
			best_score = score
	if best == null:
		return false
	_set_target(best)
	return true


func _update_switch() -> void:
	var axis := Input.get_axis("camera_left", "camera_right")
	if absf(axis) <= switch_neutral:
		_switch_armed = true
	elif _switch_armed and absf(axis) >= switch_threshold:
		_switch_armed = false
		switch_target(1 if axis > 0.0 else -1)


func _set_target(target: LockableTarget) -> void:
	if not _owns_lock:
		_saved_orientation = player.orient_to_movement
	current_target = target
	_owns_lock = true
	_occluded_seconds = 0.0
	_switch_armed = false
	player.orient_to_movement = false
	camera_rig.set_control_mode(OrbitCamera.ControlMode.EXTERNAL)
	target_changed.emit(target)


func release_lock(reason: StringName = &"manual") -> void:
	if not _owns_lock:
		return
	current_target = null
	_owns_lock = false
	_occluded_seconds = 0.0
	player.clear_movement_reference()
	player.orient_to_movement = _saved_orientation
	# Keep current angles; switching mode alone does not recenter or snap.
	camera_rig.set_control_mode(OrbitCamera.ControlMode.FREE)
	last_release_reason = reason
	target_changed.emit(null)
	lock_released.emit(reason)


func _screen_position(target: LockableTarget) -> Vector2:
	var size := camera_rig.camera.get_viewport().get_visible_rect().size
	return camera_rig.camera.unproject_position(target.get_aim_position()) / size - Vector2(0.5, 0.5)


func _update_camera(delta: float) -> void:
	var player_anchor := player.global_position + Vector3.UP * camera_rig.follow_height
	var aim := current_target.get_aim_position()
	var forward := aim - player_anchor
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return
	var wanted_yaw := atan2(-forward.x, -forward.z)
	# Aim at a point between the actors; the orbit still follows the player.
	var focus := player_anchor.lerp(aim, framing_weight)
	var angles := camera_rig.get_orbit_angles()
	var distance := maxf(camera_rig.spring_arm.current_distance, camera_rig.minimum_distance)
	var horizontal_distance := player_anchor.distance_to(focus) + distance * cos(angles.y)
	# A framing bias keeps the target above the player's silhouette instead of
	# converging to a flat view where the player's capsule hides the enemy.
	var vertical_distance := focus.y - player_anchor.y - framing_height_bias
	var wanted_pitch := atan2(vertical_distance, maxf(horizontal_distance, 0.1))
	var weight := 1.0 - exp(-camera_smoothing * delta)
	var maximum_step := deg_to_rad(maximum_camera_turn) * delta
	var yaw_step := clampf(angle_difference(angles.x, wanted_yaw) * weight, -maximum_step, maximum_step)
	var pitch_step := clampf((wanted_pitch - angles.y) * weight, -maximum_step, maximum_step)
	camera_rig.set_orbit_angles(angles.x + yaw_step, angles.y + pitch_step)
