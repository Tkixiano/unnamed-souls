extends "res://scripts/enemies/soldier_actor.gd"
const SessionProgress = preload("res://scripts/systems/session_progress.gd")
@export var boss_id: StringName = &"ruins_guardian"
@onready var spawn_point: Marker3D = $SpawnPoint

func _ready() -> void:
	entity_kind = EntityKind.BOSS
	super._ready()
	lock_target.target_id = boss_id
	brain.phase_changed.connect(_on_phase_changed)
	_on_phase_changed(1)
	brain.victory.connect(_remember_defeat)
	if SessionProgress.boss_is_defeated(get_tree(), boss_id):
		boss_defeated_this_session = true
		attributes.apply_damage(attributes.max_health)

func _remember_defeat() -> void:
	SessionProgress.mark_boss_defeated(get_tree(), boss_id)

func get_attack_variant(_kind: int) -> Resource:
	return brain.attack_resource

func _on_phase_changed(phase: int) -> void:
	_alive_material.albedo_color = Color(0.72,0.35,0.16) if phase == 2 else Color(0.37,0.42,0.5)
