extends Node
## Device inventory only. Gameplay reads semantic InputMap actions.
## Unknown generic devices require a GUID mapping or future user remapping.

signal devices_changed
signal connection_reported(device_id: int, connected: bool)

var _devices: Array[Dictionary] = []


func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh()


func has_controller() -> bool:
	return not _devices.is_empty()


func get_devices() -> Array[Dictionary]:
	return _devices.duplicate(true)


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	_refresh()
	print("Joystick event: id=%d connected=%s" % [device_id, connected])
	connection_reported.emit(device_id, connected)


func _refresh() -> void:
	_devices.clear()
	for device_id in Input.get_connected_joypads():
		var device := {
			"id": device_id,
			"name": Input.get_joy_name(device_id),
			"guid": Input.get_joy_guid(device_id),
			"mapped": Input.is_joy_known(device_id),
		}
		_devices.append(device)
		print("Joystick: %s | id=%d | GUID=%s | mapped=%s" % [
			device.name, device.id, device.guid, device.mapped])
	devices_changed.emit()
