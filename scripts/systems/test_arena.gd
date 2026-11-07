extends Node3D

const ControllerInventory = preload("res://scripts/systems/controller_registry.gd")

@onready var controller_registry: ControllerInventory = get_node("/root/ControllerRegistry")
@onready var controller_status: Label = $HUD/Margin/Info/ControllerStatus


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	controller_registry.devices_changed.connect(_update_controller_status)
	_update_controller_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func _update_controller_status() -> void:
	var devices := controller_registry.get_devices()
	if devices.is_empty():
		controller_status.text = "Mando: no conectado · Podés conectarlo durante la prueba"
		return
	var descriptions := PackedStringArray()
	for device in devices:
		var mapping := "mapeado" if device.mapped else "sin mapeo reconocido; requiere configuración"
		descriptions.append("%s [ID %d] · %s" % [device.name, device.id, mapping])
	controller_status.text = "Mando: " + " / ".join(descriptions)
