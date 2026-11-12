extends RefCounted
var result: Dictionary = {"status":"running"}
func start(tree: SceneTree) -> void:
	tree.root.set_meta("perf6a_final_focus",result)
	var wrapper: RefCounted = load("res://tests/perf_6a/regressions.gd").new()
	await load("res://tests/perf_6a/query_checks.gd").new().start(tree)
	result["queries"] = tree.root.get_meta("perf6a_queries")
	await load("res://tests/perf_6a/detection_probe.gd").new().start(tree)
	result["detection"] = tree.root.get_meta("perf6a_detection")
	var aggro: RefCounted = wrapper.clone_suite("res://tests/aggro_checks.gd",{"aggro_results.json":"perf_6a/final_aggro_results.json"})
	await aggro.start(tree)
	result["aggro"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/perf_6a/final_aggro_results.json"))
	wrapper.prepare(tree)
	load("res://scripts/systems/session_progress.gd").reset_session(tree)
	tree.change_scene_to_file("res://scenes/levels/boss_arena.tscn")
	await tree.scene_changed
	await wrapper.frames(tree,100)
	result["3c"] = await load("res://tests/phase_3c_checks.gd").new().run(tree)
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	await wrapper.frames(tree,8)
	var code: String = FileAccess.get_file_as_string("res://tests/legacy_regressions.gd")
	code = code.replace('["1a","1b","1c","1d","2a","2b","2c","2d","2e","3a","3b"]','["3a","3b"]')
	var script := GDScript.new()
	script.source_code = code
	assert(script.reload() == OK)
	var runner: RefCounted = script.new()
	await runner.start(tree)
	result["3a_3b"] = tree.root.get_meta("legacy_regressions")
	wrapper.restore(tree)
	result["status"] = "complete"
	FileAccess.open("res://tests/perf_6a/final_focus_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
