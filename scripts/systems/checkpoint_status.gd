extends Label
@export var player: CharacterBody3D
@export var manager: Node

func _process(_delta: float) -> void:
	if player.checkpoint_input_blocked and player.attributes.current_health > 0.0:
		text = "Soltá los botones de acción para retomar el control"
	else:
		text = "F: encender / descansar en la hoguera · Checkpoint: %s" % [String(manager.active_id) if not manager.active_id.is_empty() else "inicio del nivel"]
