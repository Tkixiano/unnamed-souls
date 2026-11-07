extends Label
@export var attack_controller: Node


func _process(_delta: float) -> void:
	visible = is_instance_valid(attack_controller) and attack_controller.debug_enabled
	if visible:
		text = "COMBATE · %s · %s · impactos %d%s" % [attack_controller.current_attack_name(),
			["FREE","STARTUP","ACTIVE","RECOVERY"][attack_controller.phase],attack_controller.hitbox.hit_count,
			" · LIGHT_2 preparado" if attack_controller.has_buffered_attack() else ""]
