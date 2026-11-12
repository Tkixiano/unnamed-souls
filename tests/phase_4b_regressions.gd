extends RefCounted
## Historical suites are called without overwriting their result files.
var result: Dictionary = {"status":"running"}
func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase4b_regressions",result)
	tree.change_scene_to_file("res://scenes/levels/boss_arena.tscn")
	await tree.scene_changed
	for frame in range(100): await tree.physics_frame
	var boss_suite: RefCounted = load("res://tests/phase_3c_checks.gd").new()
	result["3c"] = await boss_suite.run(tree)
	result["current"] = "1A-3B"
	# The existing runner restores historical fixtures, including documented isolations.
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	for frame in range(8): await tree.physics_frame
	var runner: RefCounted = load("res://tests/legacy_regressions.gd").new()
	await runner.start(tree)
	result["historical"] = tree.root.get_meta("legacy_regressions")
	result["status"] = "complete"
	var file := FileAccess.open("res://tests/phase_4b_regressions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	tree.change_scene_to_file("res://scenes/ui/arena_selector.tscn")

func integrated4a(tree: SceneTree) -> void:
	var suite: RefCounted = load("res://tests/phase_4a_checks.gd").new()
	suite.tree = tree
	tree.root.set_meta("phase4b_4a_suite",suite)
	await suite.run()
	var failed: Array = []
	for key in suite.checks:
		if not suite.checks[key]: failed.append(key)
	var report: Dictionary = {"status":"complete","total":suite.checks.size(),"passed":suite.checks.size()-failed.size(),"failed":failed,"checks":suite.checks,"measurements":suite.measures}
	FileAccess.open("res://tests/phase_4b_4a_regression.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	tree.root.set_meta("phase4b_4a_result",report)
