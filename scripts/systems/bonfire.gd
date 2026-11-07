extends Node3D
@export var bonfire_id: StringName = &""
@export var manager: Node
var lit: bool = false
@onready var interaction_area: Area3D = $InteractionArea
@onready var respawn_point: Marker3D = $RespawnPoint
@onready var flame: MeshInstance3D = $Visual/Flame
@onready var prompt: Label3D = $Prompt

func _ready() -> void:
	add_to_group("bonfires")
	set_lit(false)
	if is_instance_valid(manager): manager.register_bonfire(self)

func contains_player(player: CharacterBody3D) -> bool:
	return is_instance_valid(player) and interaction_area.overlaps_body(player)

func get_spawn_transform() -> Transform3D:
	return respawn_point.global_transform

func set_lit(value: bool) -> void:
	lit = value
	if is_instance_valid(flame): flame.visible = value

func _process(_delta: float) -> void:
	prompt.visible = is_instance_valid(manager) and manager.can_interact() and contains_player(manager.player)
	if prompt.visible:
		prompt.text = "F / A / Cruz · %s" % ["DESCANSAR" if lit else "ENCENDER HOGUERA"]

func _exit_tree() -> void:
	if is_instance_valid(manager): manager.unregister_bonfire(self)
