extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	await process_frame
	for pair in [["ControllerRegistry","res://scripts/systems/controller_registry.gd"],["GameMenus","res://scenes/ui/game_menus.tscn"],["AudioDirector","res://scenes/audio/audio_director.tscn"]]:
		if root.has_node(pair[0]): continue
		var resource: Resource = load(pair[1])
		var instance: Node = resource.instantiate() if resource is PackedScene else resource.new()
		instance.name = pair[0]
		root.add_child(instance)
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	for frame in range(4): await process_frame
	var audio_suite: RefCounted = load("res://tests/phase_5c_checks.gd").new()
	await audio_suite.start(self)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/phase_5b_checks.gd").replace("phase_5b_results.json","phase_5c_regression_5b_native.json")
	if script.reload() != OK:
		quit(2)
		return
	var suite: RefCounted = script.new()
	await suite.start(self)
	var result: Dictionary = root.get_meta("phase5b_result")
	result["context"] = "Native 5B regression with AudioDirector enabled; added Ambient preference changes only option-count and name lookup expectations"
	FileAccess.open("res://tests/phase_5c_regression_5b_native.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if result.failed.is_empty() else 1)
