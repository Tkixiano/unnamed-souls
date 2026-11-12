extends RefCounted
## Preferences only. No player, checkpoint or victory data is serialized.
const Routing = preload("res://scripts/audio/audio_routing.gd")
signal changed
const DEFAULTS = {"master":100.0,"music":100.0,"effects":100.0,"ambient":100.0,"horizontal":150.0,"vertical":110.0,"invert_y":false,"fullscreen":false}
var values: Dictionary = DEFAULTS.duplicate()
var preferences_path: String = "user://preferences.cfg"
var last_save_error: int = OK

func initialize() -> void:
	Routing.ensure_buses()
	load_preferences()
	apply()

func set_value(key: String, value: Variant) -> void:
	if not DEFAULTS.has(key): return
	if key in ["invert_y","fullscreen"]:
		if not value is bool: return
	else:
		if not (value is float or value is int) or not is_finite(float(value)): return
		value = clampf(float(value),10.0 if key in ["horizontal","vertical"] else 0.0,360.0 if key in ["horizontal","vertical"] else 100.0)
	if values[key] == value: return
	values[key] = value
	apply()
	changed.emit()

func apply() -> void:
	for pair in [["Master","master"],["Music","music"],["SFX","effects"],["Ambient","ambient"]]:
		var index: int = AudioServer.get_bus_index(pair[0])
		if index < 0: continue
		var amount: float = values[pair[1]]/100.0
		AudioServer.set_bus_mute(index,amount <= 0.0)
		AudioServer.set_bus_volume_db(index,linear_to_db(amount) if amount > 0 else -80.0)
	var wanted: int = DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != wanted: DisplayServer.window_set_mode(wanted)

func apply_camera(rig: Node) -> void:
	if not is_instance_valid(rig): return
	rig.horizontal_sensitivity = values.horizontal
	rig.vertical_sensitivity = values.vertical
	rig.invert_vertical = values.invert_y

func load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(preferences_path) != OK: return
	for key in DEFAULTS:
		var value: Variant = config.get_value("options",key,DEFAULTS[key])
		if DEFAULTS[key] is bool:
			if value is bool: values[key] = value
		elif (value is float or value is int) and is_finite(float(value)):
			values[key] = clampf(float(value),10.0 if key in ["horizontal","vertical"] else 0.0,360.0 if key in ["horizontal","vertical"] else 100.0)

func save_preferences() -> int:
	var config := ConfigFile.new()
	for key in DEFAULTS: config.set_value("options",key,values[key])
	last_save_error = config.save(preferences_path+".tmp")
	if last_save_error == OK:
		last_save_error = DirAccess.rename_absolute(ProjectSettings.globalize_path(preferences_path+".tmp"),ProjectSettings.globalize_path(preferences_path))
	return last_save_error
