extends Label

@export var dodge_controller: Node


func _process(_delta: float) -> void:
	visible = is_instance_valid(dodge_controller) and dodge_controller.debug_enabled
	if not visible:
		return
	var active: bool = dodge_controller.is_active()
	var invulnerable: bool = dodge_controller.is_invulnerable()
	var phase := "RECUPERACIÓN" if dodge_controller.is_recovering() else "DODGING"
	text = "DEBUG · %s · %s%s" % [dodge_controller.get_profile_name(), phase if active else "SIN ESQUIVA",
		" · I-FRAMES" if invulnerable else ""]
	modulate = Color(0.4, 0.95, 1.0) if invulnerable else (Color(1.0, 0.8, 0.4) if active else Color(0.65, 0.7, 0.72))
