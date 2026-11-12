extends SceneTree
## Run only by the MCP editor launcher. Same menu suite, real native main window.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	# --script SceneTree launches may omit project autoloads on some Godot builds.
	for pair in [["ControllerRegistry","res://scripts/systems/controller_registry.gd"],["GameMenus","res://scenes/ui/game_menus.tscn"]]:
		if root.has_node(pair[0]): continue
		var resource: Resource = load(pair[1])
		var instance: Node = resource.instantiate() if resource is PackedScene else resource.new()
		instance.name = pair[0]
		root.add_child(instance)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	for frame in range(4): await process_frame
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/phase_5b_checks.gd").replace("phase_5b_results.json","phase_5b_native_results.json")
	if script.reload() != OK:
		quit(2)
		return
	var suite: RefCounted = script.new()
	await suite.start(self)
	var result: Dictionary = root.get_meta("phase5b_result")
	result["context"] = "Same checks in native Godot game window launched via Godot AI MCP test_run; no embedding/editor-setting changes"
	result["engine"] = Engine.get_version_info()
	FileAccess.open("res://tests/phase_5b_native_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	DirAccess.make_dir_recursive_absolute("res://tests/phase_5b_evidence")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/phase_5b_evidence/native_main_menu.png")
	quit(0 if result.failed.is_empty() else 1)
