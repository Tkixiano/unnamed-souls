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
	for i in range(4): await process_frame
	var results: Dictionary = {}
	for spec in [["phase_5c_checks.gd","phase_5c_results.json","aggro_audio_results.json"],["phase_5b_checks.gd","phase_5b_results.json","aggro_menu_results.json"],["phase_5c_followup.gd","phase_5c_followup.json","aggro_audio_followup.json"]]:
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://tests/"+spec[0]).replace(spec[1],spec[2])
		if script.reload() != OK:
			quit(2)
			return
		var suite: RefCounted = script.new()
		await suite.start(self)
		# Historical menu suite returns at scene_changed, before its deferred focus.
		# Settle that real transition before starting the next independent fixture.
		for frame in range(4): await process_frame
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/"+spec[2]))
		results[spec[0]] = {"passed":data.passed,"total":data.total,"failed":data.failed}
	FileAccess.open("res://tests/aggro_native_results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	quit(0)
