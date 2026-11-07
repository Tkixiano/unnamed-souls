extends "res://scripts/systems/lockable_target.gd"

@onready var attributes: Node = $Attributes
@onready var hurtbox: Area3D = $Hurtbox
@onready var health_label: Label3D = $HealthLabel
@onready var visual: Node3D = $Visual
@onready var action_states: Node = $ActionState
@onready var critical_vulnerability: Node = $CriticalVulnerability
@export var combat_faction: StringName = &"training"
var hit_count: int = 0
var last_damage: float = 0.0


func _ready() -> void:
	super._ready()
	critical_vulnerability.initialize()
	attributes.health_changed.connect(_on_health_changed)
	attributes.died.connect(_on_died)
	attributes.fully_restored.connect(_on_restored)
	hurtbox.damage_received.connect(_on_hit)
	_update_label()


func _on_health_changed(_current: float, _maximum: float) -> void:
	_update_label()


func _on_hit(amount: float, _attacker: Node, _swing_id: int) -> void:
	hit_count += 1
	last_damage = amount
	_update_label()


func _on_died() -> void:
	action_states.transition_to(7)
	alive = false
	available = false
	hurtbox.enabled = false
	hurtbox.set_debug_enabled(hurtbox.debug_enabled)
	collision_body.collision_layer = 0
	$Body/CollisionShape3D.set_deferred("disabled",true)
	_update_label()


func _on_restored() -> void:
	action_states.reset_to_free()
	alive = true
	available = true
	hit_count = 0
	last_damage = 0.0
	hurtbox.enabled = true
	hurtbox.set_debug_enabled(hurtbox.debug_enabled)
	collision_body.collision_layer = 1
	$Body/CollisionShape3D.set_deferred("disabled",false)
	_update_label()


func _update_label() -> void:
	health_label.text = "%s %.0f / %.0f%s" % ["VIDA" if alive else "INACTIVO",attributes.current_health,
		attributes.max_health," · -%.0f" % last_damage if last_damage > 0.0 else ""]


func set_combat_debug(value: bool) -> void:
	health_label.visible = value

func get_critical_vulnerability() -> Node:
	return critical_vulnerability

func is_critical_committed() -> bool:
	return critical_vulnerability.is_reserved()

func can_receive_attack() -> bool:
	return attributes.current_health > 0.0 and action_states.current_state != 7

func interrupt_attack_for_critical() -> bool:
	return false # Static training props have no outgoing attacks to parry.
