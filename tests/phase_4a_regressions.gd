extends RefCounted
## Historical suites are called without overwriting their result files.
var result: Dictionary = {"status":"running"}
func start(tree: SceneTree) -> void:
	tree.root.set_meta("phase4a_regressions",result)
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
	var file := FileAccess.open("res://tests/phase_4a_regressions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	tree.change_scene_to_file("res://scenes/ui/arena_selector.tscn")

func recheck_boss(tree: SceneTree) -> void:
	result = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_4a_regressions.json"))
	result["status"] = "running"
	tree.root.set_meta("phase4a_regressions",result)
	tree.change_scene_to_file("res://scenes/levels/boss_arena.tscn")
	await tree.scene_changed
	# The real boss has a 1.5 s initial restart guard; wait before the acquisition fixture.
	for frame in range(100): await tree.physics_frame
	var suite: RefCounted = load("res://tests/phase_3c_checks.gd").new()
	result["previous_3c_fixture"] = {"passed":result["3c"].passed,"failed":result["3c"].failed}
	result["3c"] = await suite.run(tree)
	result["status"] = "complete"
	var file := FileAccess.open("res://tests/phase_4a_regressions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	tree.change_scene_to_file("res://scenes/ui/arena_selector.tscn")
