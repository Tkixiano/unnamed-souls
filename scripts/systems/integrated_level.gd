extends "res://scripts/systems/test_arena.gd"
## Presentation only; combat and checkpoints stay in their existing components.
@export var direct_boss_test: bool = false
@onready var player: CharacterBody3D = $Player
@onready var route_hint: Label = $HUD/RouteHint
func _ready() -> void:
	super._ready()
	# The interactive panel replaces duplicated sector instructions only in the main level.
	if has_node("TutorialController"): route_hint.hide()

func _process(_delta: float) -> void:
	var z: float = player.global_position.z
	if direct_boss_test:
		route_hint.text = "JEFE · Cruzá el arco · F: descansar · Esc: pausa"
	elif z > 17:
		route_hint.text = "INICIO · F / A / Cruz: encender y descansar. Avanzá hacia el tutorial."
	elif z > 8:
		route_hint.text = "TUTORIAL · WASD / stick: mover · Q / R3: fijar muñeco · J / RB: atacar."
	elif z > -4:
		route_hint.text = "COMBATE · Ctrl / LB: bloquear · C / LT: parry · toque Espacio / B: esquivar."
	elif z > -24:
		route_hint.text = "CAMINO · E / X: Estus · R / Y: empuñadura · Esperá la recuperación rival."
	elif z > -38:
		route_hint.text = "ACCESO · Hoguera antes del arco. El checkpoint permanece en este nivel."
	else:
		route_hint.text = "GUARDIÁN · Conservá stamina. El área advertida no admite bloqueo."
