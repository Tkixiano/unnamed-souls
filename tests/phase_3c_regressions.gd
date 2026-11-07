extends RefCounted
## Run original level fixtures separately, then return to the boss test scene.
func start(tree: SceneTree) -> void:
	var report := {"status":"running","scene":"main_regressions"}
	tree.root.set_meta("phase_3c_regressions",report)
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	for frame in range(8): await tree.physics_frame
	var runner: RefCounted = load("res://tests/legacy_regressions.gd").new()
	await runner.start(tree)
	report["historical"] = tree.root.get_meta("legacy_regressions")
	tree.change_scene_to_file("res://scenes/levels/boss_arena.tscn")
	await tree.scene_changed
	report["scene"] = "boss_arena"
	report["status"] = "complete"
	var output := FileAccess.open("res://tests/phase_3c_regressions.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
