extends CharacterBody3D
## Physical actor and combat protocol. Decisions live in SoldierAI.
const Actions = preload("res://scripts/player/action_state.gd")
enum EntityKind { NORMAL_ENEMY, BOSS }
@export var entity_kind: EntityKind = EntityKind.NORMAL_ENEMY
var boss_defeated_this_session: bool = false
@export var combat_faction: StringName = &"hostile"
@export var speed: float = 2.0
@export var acceleration: float = 8.0
@export var turn_speed: float = 150.0
@export var debug_enabled: bool = true
@export var display_name: String = "SOLDADO"
@onready var attributes: Node = $Attributes
@onready var action_states: Node = $ActionState
@onready var visual: Node3D = $Visual
@onready var attack_controller: Node = $AttackController
@onready var critical_vulnerability: Node = $CriticalVulnerability
@onready var hurtbox: Area3D = $Hurtbox
@onready var lock_target: Node3D = $LockableTarget
@onready var brain: Node = $SoldierAI
@onready var status_label: Label3D = $StatusLabel
@onready var body_mesh: MeshInstance3D = $Visual/Body
var _move_intent: Vector3 = Vector3.ZERO
var _alive_material: StandardMaterial3D
var _dead_material: StandardMaterial3D
var _flash_remaining: float = 0.0
var _spawn_transform: Transform3D
var _spawn_visual_yaw: float = 0.0
var _hurtbox_debug_before_death: bool = true

func _ready() -> void:
	add_to_group("checkpoint_enemies")
	_spawn_transform = global_transform
	_spawn_visual_yaw = visual.global_rotation.y
	attributes.died.connect(_on_died)
	attributes.fully_restored.connect(_on_restored)
	action_states.state_changed.connect(_on_action_changed)
	hurtbox.damage_received.connect(_on_damage)
	attack_controller.faction = combat_faction
	hurtbox.faction = combat_faction
	attack_controller.initialize()
	critical_vulnerability.initialize()
	_alive_material = StandardMaterial3D.new()
	_alive_material.albedo_color = Color(0.42,0.5,0.6)
	_alive_material.roughness = 1.0
	_dead_material = StandardMaterial3D.new()
	_dead_material.albedo_color = Color(0.17,0.18,0.19)
	body_mesh.material_override = _alive_material
	brain.initialize()

func _physics_process(delta: float) -> void:
	attack_controller.advance_clock(delta)
	var desired: Vector3 = _move_intent.limit_length()*speed if can_move() else Vector3.ZERO
	var horizontal := Vector3(velocity.x,0,velocity.z).move_toward(desired,acceleration*delta)
	# Committed actions stop horizontal locomotion; gravity never stops.
	if not can_move(): horizontal = Vector3.ZERO
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor(): velocity += get_gravity()*delta
	elif velocity.y < 0.0: velocity.y = 0.0
	move_and_slide()
	attack_controller.after_physics_step()
	attack_controller.sync_idle_pose()
	_flash_remaining = maxf(_flash_remaining-delta,0.0)
	status_label.visible = debug_enabled
	status_label.text = "%s · %s · %.0f / %.0f" % [display_name,brain.state_name(),attributes.current_health,attributes.max_health]
	status_label.modulate = Color(1,0.7,0.2) if critical_vulnerability.is_available() else Color(1,0.45,0.35) if _flash_remaining > 0.0 else Color.WHITE

func set_move_intent(direction: Vector3) -> void:
	_move_intent = Vector3(direction.x,0,direction.z).limit_length()

func face_direction(direction: Vector3, delta: float) -> void:
	if not can_move() or direction.is_zero_approx(): return
	var yaw: float = atan2(-direction.x,-direction.z)
	visual.global_rotation = Vector3(0,rotate_toward(visual.global_rotation.y,yaw,deg_to_rad(turn_speed)*delta),0)

func face_attack_direction(direction: Vector3) -> void:
	if action_states.current_state == Actions.State.ATTACKING:
		visual.global_rotation = Vector3(0,atan2(-direction.x,-direction.z),0)

func get_attack_aim_direction() -> Vector3:
	return brain.direction_to_target() if brain.target_alive() else Vector3.ZERO

func can_move() -> bool:
	return attributes.current_health > 0.0 and action_states.current_state == Actions.State.FREE

func can_receive_attack() -> bool:
	return attributes.current_health > 0.0 and action_states.current_state != Actions.State.DEAD

func get_critical_vulnerability() -> Node:
	return critical_vulnerability

func is_critical_committed() -> bool:
	return critical_vulnerability.is_reserved()

func interrupt_attack_for_critical() -> bool:
	return attack_controller.interrupt_for_parry()

func can_interrupt_for_backstab() -> bool:
	return attack_controller.is_active() and action_states.current_state == Actions.State.ATTACKING

func _on_action_changed(_previous: int, _current: int) -> void:
	attributes.set_regeneration_blocked(&"action_state",action_states.blocks_regeneration())
	if not can_move():
		set_move_intent(Vector3.ZERO)
		velocity.x = 0.0
		velocity.z = 0.0

func _on_damage(_amount: float, _attacker: Node, _swing: int) -> void:
	_flash_remaining = 0.35

func _on_died() -> void:
	if entity_kind == EntityKind.BOSS: boss_defeated_this_session = true
	action_states.transition_to(Actions.State.DEAD)
	lock_target.alive = false
	lock_target.available = false
	hurtbox.enabled = false
	_hurtbox_debug_before_death = hurtbox.debug_enabled
	hurtbox.set_debug_enabled(false)
	attack_controller.hitbox.set_active(false)
	body_mesh.material_override = _dead_material
	set_move_intent(Vector3.ZERO)

func _on_restored() -> void:
	# Attribute reset remains reusable; checkpoint reset also restores placement below.
	action_states.reset_to_free()
	lock_target.alive = true
	lock_target.available = true
	hurtbox.enabled = true
	hurtbox.set_debug_enabled(_hurtbox_debug_before_death)
	body_mesh.material_override = _alive_material

func should_restore_at_checkpoint() -> bool:
	return entity_kind == EntityKind.NORMAL_ENEMY or (not boss_defeated_this_session and attributes.current_health > 0.0)

func restore_at_checkpoint() -> bool:
	if not should_restore_at_checkpoint():
		return false
	attributes.restore_all()
	global_transform = _spawn_transform
	visual.global_rotation = Vector3(0,_spawn_visual_yaw,0)
	velocity = Vector3.ZERO
	set_move_intent(Vector3.ZERO)
	_flash_remaining = 0.0
	brain.origin = _spawn_transform.origin
	brain.origin_yaw = _spawn_visual_yaw
	brain.reset_brain()
	attack_controller.hitbox.set_active(false)
	attack_controller.sync_idle_pose()
	reset_physics_interpolation()
	return true

func set_combat_debug(value: bool) -> void:
	debug_enabled = value
