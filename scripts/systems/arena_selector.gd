extends Control
## Temporary launcher; arenas have no dependency on this controller.
@export var test_arena: PackedScene
@export var boss_arena: PackedScene
@onready var buttons: Array[Button] = [$Margin/Layout/Content/Choices/Test, $Margin/Layout/Content/Choices/Boss, $Margin/Layout/Content/Choices/Quit]
@onready var guide: GridContainer = $Margin/Layout/Content/Guide/Bindings
@onready var status: Label = $Margin/Layout/Status
var _opening := false
var _stick_latched := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	buttons[0].pressed.connect(_launch.bind(test_arena))
	buttons[1].pressed.connect(_launch.bind(boss_arena))
	buttons[2].pressed.connect(func() -> void: get_tree().quit())
	for index in range(buttons.size()):
		buttons[index].focus_neighbor_top = buttons[index].get_path_to(buttons[posmod(index-1,buttons.size())])
		buttons[index].focus_neighbor_bottom = buttons[index].get_path_to(buttons[(index+1)%buttons.size()])
	buttons[0].grab_focus()
	for row in [
		["ACCIÓN", "TECLADO / MOUSE", "XBOX / PLAYSTATION"],
		["Movimiento", "WASD", "Stick izquierdo"],
		["Cámara", "Flechas / arrastrar clic derecho", "Stick derecho"],
		["Rodada / backstep", "Toque y soltar Espacio", "Toque B / Círculo"],
		["Carrera", "Mantener Espacio + dirección", "Mantener B / Círculo + dirección"],
		["Fijar / liberar", "Q / clic de rueda", "R3"],
		["Cambiar objetivo", "Flecha izquierda / derecha", "Stick derecho lateral; volver a neutral"],
		["Ligero / crítico", "Clic izquierdo / J", "RB / R1 (riposte y backstab contextuales)"],
		["Ataque fuerte", "Shift / K", "RT / R2"],
		["Escudo (mantener)", "Ctrl / L / U", "LB / L1"],
		["Parry", "C / I", "LT / L2"],
		["Estus", "E", "X / Cuadrado"],
		["Una / dos manos", "R", "Y / Triángulo"],
		["Hoguera / interacción", "F", "A / Cruz"],
		["Volver a este menú", "Escape / botón Menú", "Menu / Options"],
		["Pantalla completa", "F11", "—"]
	]:
		for column in range(3):
			var label := Label.new()
			label.text = row[column]
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.add_theme_font_size_override("font_size", 14)
			if row[0] == "ACCIÓN": label.modulate = Color(0.92,0.7,0.36)
			guide.add_child(label)
	var registry := get_node("/root/ControllerRegistry")
	registry.devices_changed.connect(_update_devices)
	_update_devices()

func _input(event: InputEvent) -> void:
	# The same stick also maps to Godot's built-in ui_down/up. Own it once.
	if event is InputEventJoypadMotion and (event.is_action("move_forward") or event.is_action("move_backward")):
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	var axis := Input.get_axis("move_forward", "move_backward")
	if absf(axis) < 0.25: _stick_latched = false
	if _opening or _stick_latched or absf(axis) < 0.6: return
	_stick_latched = true
	var index := buttons.find(get_viewport().gui_get_focus_owner())
	buttons[posmod(index + (1 if axis > 0.0 else -1), buttons.size())].grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_confirm") and not event.is_echo():
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button: focused.pressed.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()

func _launch(arena: PackedScene) -> void:
	if _opening or arena == null: return
	_opening = true
	_change_scene.call_deferred(arena)

func _change_scene(arena: PackedScene) -> void:
	var error := get_tree().change_scene_to_packed(arena)
	if error != OK:
		_opening = false
		status.text = "No se pudo abrir la arena (error %d)." % error

func _update_devices() -> void:
	var devices: Array = get_node("/root/ControllerRegistry").get_devices()
	status.text = "Mando: %s · Conexión en caliente disponible" % (devices[0].name if not devices.is_empty() else "no conectado")
