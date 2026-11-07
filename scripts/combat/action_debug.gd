extends Label
@export var player: CharacterBody3D
@export var enabled: bool = true

func _process(_delta: float) -> void:
	visible = enabled and player.attack_controller.debug_enabled
	if visible:
		text = "%s%s · ESTUS %s · %s" % [
			"UNA MANO + ESCUDO" if player.grip_controller.mode == 0 else "DOS MANOS",
			" (CAMBIANDO)" if player.grip_controller.is_switching() else "",
			["—","PREPARACIÓN","BEBIENDO","RECUPERACIÓN"][player.estus_controller.phase],
			player.riposte_controller.current_critical_name()]
