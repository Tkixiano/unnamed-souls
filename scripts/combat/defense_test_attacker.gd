extends Node
## Technical single-shot control only. No perception, pursuit, decisions or AI.
const AttackData = preload("res://scripts/combat/attack_data.gd")
@export var player: CharacterBody3D
@export var attacker: CharacterBody3D
@export var target: Node3D
@export var label: Label3D
@export var technical_input_enabled: bool = true
var _pending: int = -1
var _initial_transform: Transform3D

func _ready() -> void:
	add_to_group("checkpoint_auxiliary_resets")
	_initial_transform = attacker.global_transform
	attacker.attributes.max_health = 250.0
	attacker.attributes.restore_all()
	attacker.attributes.health_changed.connect(_update_health)
	attacker.attributes.fully_restored.connect(_restore_target)
	attacker.attributes.died.connect(_disable_target)
	_update_health(attacker.attributes.current_health,attacker.attributes.max_health)

func reset_after_checkpoint() -> void:
	_pending = -1
	attacker.attributes.restore_all()
	attacker.global_transform = _initial_transform
	attacker.velocity = Vector3.ZERO
	attacker.attack_controller.hitbox.set_active(false)
	attacker.reset_physics_interpolation()

func _unhandled_input(event: InputEvent) -> void:
	if technical_input_enabled and event is InputEventKey and event.pressed and not event.echo:
		var keys := [KEY_F1,KEY_F2,KEY_F3,KEY_F4]
		var index: int = keys.find(event.keycode)
		if index >= 0:
			_pending = index

func _physics_process(_delta: float) -> void:
	if _pending >= 0:
		var kind := _pending
		_pending = -1
		execute_test(kind)

func execute_test(kind: int) -> bool:
	if kind < 0 or kind > 3 or attacker.action_states.current_state != 0 or attacker.attributes.current_health <= 0.0:
		return false
	# Reposition only the test actor before its strike, never during a riposte.
	var toward: Vector3 = -player.visual.global_basis.z
	var position: Vector3 = player.global_position + toward*( -1.6 if kind == 2 else 1.6)
	var excluded: Array[RID] = [player.get_rid(),attacker.get_rid()]
	var ray := PhysicsRayQueryParameters3D.create(player.global_position+Vector3.UP,position+Vector3.UP,1,excluded)
	if not attacker.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return false
	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = attacker.get_node("CollisionShape3D").shape
	shape_query.transform = Transform3D(Basis.IDENTITY,position+Vector3(0,0.95,0))
	shape_query.collision_mask = 1
	shape_query.exclude = excluded
	if not attacker.get_world_3d().direct_space_state.intersect_shape(shape_query,1).is_empty():
		return false
	attacker.global_position = position
	attacker.velocity = Vector3.ZERO
	attacker.reset_physics_interpolation()
	var direction: Vector3 = (player.global_position-position).normalized()
	attacker.visual.global_rotation = Vector3(0,atan2(-direction.x,-direction.z),0)
	var data := AttackData.new()
	data.attack_name = [&"TEST_FRONT",&"TEST_NO_PARRY",&"TEST_REAR",&"TEST_GUARD_BREAK"][kind]
	data.startup = 0.30
	data.active = 0.12
	data.recovery = 0.45
	data.combo_close = 0.72
	data.damage = 40.0 if kind == 3 else 30.0
	data.stamina_damage = 300.0 if kind == 3 else 40.0
	data.blockable = true
	data.parryable = kind in [0,2]
	data.stamina_cost = 0.0
	data.turn_speed = 0.0
	data.correction_limit = 0.0
	attacker.attack_controller.heavy_1 = data
	return attacker.attack_controller.request_attack(2)

func _update_health(current: float, maximum: float) -> void:
	label.text = "DEFENSA · %d / %d" % [current,maximum]
	if attacker.critical_vulnerability.is_available():
		label.text += " · VULNERABLE"

func _disable_target() -> void:
	target.alive = false
	target.available = false

func _restore_target() -> void:
	target.alive = true
	target.available = true
