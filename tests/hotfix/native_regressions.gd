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
	FileAccess.open("res://tests/hotfix/native_progress.json",FileAccess.WRITE).store_string(JSON.stringify({"current":"audio_menu_aggro"}))
	for spec in [["phase_5c_checks.gd","phase_5c_results.json","hotfix/audio_results.json"],["phase_5b_checks.gd","phase_5b_results.json","hotfix/menu_results.json"],["phase_5c_followup.gd","phase_5c_followup.json","hotfix/audio_followup.json"],["aggro_checks.gd","aggro_results.json","hotfix/aggro_results.json"]]:
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
	FileAccess.open("res://tests/hotfix/native_results.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))

	for method in ["historical","integration"]:
		FileAccess.open("res://tests/hotfix/native_progress.json",FileAccess.WRITE).store_string(JSON.stringify({"current":method}))
		var runner: RefCounted = load("res://tests/hotfix/regressions.gd").new()
		await runner.call(method,self)
	for source in ["query_checks.gd","detection_probe.gd"]:
		FileAccess.open("res://tests/hotfix/native_progress.json",FileAccess.WRITE).store_string(JSON.stringify({"current":source}))
		var script := GDScript.new()
		script.source_code = FileAccess.get_file_as_string("res://tests/perf_6a/"+source).replace("res://tests/perf_6a/query_results.json","res://tests/hotfix/query_results.json").replace("res://tests/perf_6a/detection_results.json","res://tests/hotfix/detection_results.json")
		if script.reload() != OK:
			quit(2)
			return
		var suite: RefCounted = script.new()
		await suite.start(self)
	FileAccess.open("res://tests/hotfix/native_progress.json",FileAccess.WRITE).store_string(JSON.stringify({"current":"complete"}))
	quit(0)
