extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	var data := {"executable":OS.get_executable_path(),"resource_root":ProjectSettings.globalize_path("res://"),"arguments":OS.get_cmdline_args(),"mcp_helper":root.has_node("_mcp_game_helper"),"source_tests":FileAccess.file_exists("res://tests/aggro_checks.gd"),"main":ProjectSettings.get_setting("application/run/main_scene"),"release_template":false}
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	for frame in range(4): await process_frame
	data["scene"] = current_scene.scene_file_path
	data["autoloads"] = root.get_children().map(func(n): return n.name)
	FileAccess.open("C:/JUEGOs 3D/soul-game/tests/phase_6b/pack_probe.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	quit()
