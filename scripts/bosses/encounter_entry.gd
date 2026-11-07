extends Area3D
@export var boss: CharacterBody3D
@export var player: CharacterBody3D
@export var enabled: bool = true

func _physics_process(_delta: float) -> void:
	if enabled and is_instance_valid(boss) and overlaps_body(player):
		boss.brain.start_encounter()
