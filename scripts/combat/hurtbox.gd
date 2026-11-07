extends Area3D

const Attributes = preload("res://scripts/systems/actor_attributes.gd")
const DebugGeometry = preload("res://scripts/combat/combat_debug_geometry.gd")

signal damage_received(amount: float, attacker: Node, swing_id: int)
signal impact_resolved(result: Dictionary)

@export var actor: Node
@export var attributes: Attributes
@export var physical_body: CollisionObject3D
@export var faction: StringName = &""
@export var enabled: bool = true
@export var debug_enabled: bool = true
@onready var collider: CollisionShape3D = $CollisionShape3D
var _debug: MeshInstance3D


func _ready() -> void:
	add_to_group("combat_hurtboxes")
	_debug = MeshInstance3D.new()
	_debug.mesh = DebugGeometry.wire_box(Vector3(0.85,1.8,0.85),Color(0.3,0.85,0.45))
	add_child(_debug)
	set_debug_enabled(debug_enabled)


func set_debug_enabled(value: bool) -> void:
	debug_enabled = value
	if is_instance_valid(_debug):
		_debug.visible = value and enabled


func can_target(attacker: Node, attacker_faction: StringName) -> bool:
	if not enabled or not is_instance_valid(actor) or not is_instance_valid(attacker) \
		or actor == attacker or not is_instance_valid(attributes) or attributes.current_health <= 0.0:
		return false
	# Fail closed if factions have not been configured.
	if faction.is_empty() or attacker_faction.is_empty() or faction == attacker_faction:
		return false
	return true


func can_receive(attacker: Node, attacker_faction: StringName) -> bool:
	return can_target(attacker,attacker_faction) and (not actor.has_method("can_receive_attack") or actor.can_receive_attack())


func receive_hit(attacker: Node, attacker_faction: StringName, damage: float, swing_id: int, context: Dictionary = {}) -> float:
	return float(resolve_hit(attacker,attacker_faction,damage,swing_id,context).get("damage",0.0))


func resolve_hit(attacker: Node, attacker_faction: StringName, damage: float, swing_id: int, context: Dictionary = {}) -> Dictionary:
	var result := {"outcome":&"invalid","damage":0.0,"consumed":false,"parryable":context.get("parryable",false)}
	if not can_target(attacker,attacker_faction) or not is_finite(damage) or damage < 0.0:
		return result
	var critical_owner: Node = context.get("critical_owner")
	if actor.has_method("is_critical_committed") and actor.is_critical_committed() and not is_instance_valid(critical_owner):
		result.outcome = &"critical_committed"
		return result
	if not can_receive(attacker,attacker_faction):
		result.outcome = &"evaded"
		return result
	var resolution := {"outcome":&"normal","health_damage":damage,"consumed":true}
	if is_instance_valid(critical_owner):
		if not actor.has_method("get_critical_vulnerability") or not actor.get_critical_vulnerability().authorize_damage(critical_owner):
			return result
		resolution.outcome = StringName(String(critical_owner.current_critical_name()).to_lower())
	elif actor.has_method("get_defense_controller") and attacker is Node3D:
		var packet := context.duplicate()
		packet["damage"] = damage
		resolution = actor.get_defense_controller().resolve_contact(attacker,packet)
	# Only this point applies health damage, for normal, residual and critical hits.
	var applied := attributes.apply_damage(float(resolution.health_damage))
	result.outcome = resolution.outcome
	result.damage = applied
	result.consumed = resolution.consumed
	result["stamina_cost"] = resolution.get("stamina_cost",0.0)
	if applied > 0.0:
		damage_received.emit(applied,attacker,swing_id)
	impact_resolved.emit(result)
	return result
