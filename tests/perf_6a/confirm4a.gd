extends RefCounted
func start(tree: SceneTree) -> void:
	var wrapper: RefCounted = load("res://tests/perf_6a/regressions.gd").new()
	wrapper.prepare(tree)
	await wrapper.fresh_level(tree)
	var runner: RefCounted = wrapper.clone_suite("res://tests/phase_4b_regressions.gd",{"phase_4b_4a_regression.json":"perf_6a/confirm4a_results.json"})
	await runner.integrated4a(tree)
	wrapper.restore(tree)
	tree.root.set_meta("perf6a_confirm4a",JSON.parse_string(FileAccess.get_file_as_string("res://tests/perf_6a/confirm4a_results.json")))
