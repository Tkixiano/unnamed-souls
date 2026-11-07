extends Label
@export var player: CharacterBody3D
@export var test_attacker: CharacterBody3D
@export var enabled: bool = true
var _last_critical: StringName = &""
var _critical_time: float = 0.0

func _ready() -> void:
	player.riposte_controller.riposte_event.connect(func(event: StringName) -> void:
		_last_critical = event
		_critical_time = 0.8)

func _process(delta: float) -> void:
	visible = enabled and player.defense_controller.debug_enabled and player.attack_controller.debug_enabled
	get_parent().get_node("DefenseTestHint").visible = visible
	_critical_time = maxf(_critical_time-delta,0.0)
	var defense: Node = player.defense_controller
	if visible:
		text = "DEFENSA · %s · parry %s%s%s%s" % [["FREE","ESCUDO","PARRY","GUARDIA ROTA"][defense.mode],
			["—","STARTUP","ACTIVE","RECOVERY"][defense.parry_phase],
			" · "+String(defense.last_event) if defense.feedback_remaining > 0.0 else "",
			" · OBJETIVO VULNERABLE" if test_attacker.critical_vulnerability.is_available() else "",
			" · "+String(_last_critical) if _critical_time > 0.0 else ""]
	var label: Label3D = test_attacker.get_node("DefenseLabel")
	label.visible = visible
	label.modulate = Color(1,0.8,0.2) if test_attacker.critical_vulnerability.is_available() else Color.WHITE
