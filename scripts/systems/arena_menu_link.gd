extends CanvasLayer
## Optional navigation only: removing this scene leaves the arena functional.
@export_file("*.tscn") var menu_scene: String = "res://scenes/ui/arena_selector.tscn"
var _leaving := false

func _ready() -> void:
	$Menu.pressed.connect(_return_to_menu)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_return_to_menu()

func _return_to_menu() -> void:
	if _leaving: return
	_leaving = true
	_change_scene.call_deferred()

func _change_scene() -> void:
	var error := get_tree().change_scene_to_file(menu_scene)
	if error != OK:
		_leaving = false
		push_error("No se pudo regresar al selector: %d" % error)
