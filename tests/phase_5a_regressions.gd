extends RefCounted
## Execute historical code unchanged, redirecting only result destinations in RAM.
var result: Dictionary = {"status":"running"}
func redirected(path: String, old_output: String, new_output: String) -> RefCounted:
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(path).replace(old_output,new_output)
	if script.reload() != OK: return null
	return script.new()
func step(tree: SceneTree, n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func integration(tree: SceneTree) -> void:
	tree.root.set_meta("phase5a_integration_regressions",result)
	for part in ["checks","spatial","retry"]:
		if part == "retry":
			# Independent retry fixture needs an undefeated boss; session behavior is tested separately.
			tree.root.remove_meta(&"defeated_bosses")
			tree.change_scene_to_file("res://scenes/levels/main_level.tscn")
			await tree.scene_changed
			await step(tree,8)
		result["current"] = "4b_"+part
		var old: String = "phase_4b_results.json" if part == "checks" else "phase_4b_"+part+".json"
		var suite: RefCounted = redirected("res://tests/phase_4b_"+part+".gd",old,"phase_5a_regression_4b_"+part+".json")
		await suite.start(tree)
		result[part] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_5a_regression_4b_"+part+".json"))
	tree.change_scene_to_file("res://scenes/levels/main_level.tscn")
	await tree.scene_changed
	await step(tree,8)
	result["current"] = "4a"
	var runner: RefCounted = redirected("res://tests/phase_4b_regressions.gd","phase_4b_4a_regression.json","phase_5a_regression_4a.json")
	await runner.integrated4a(tree)
	result["4a"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_5a_regression_4a.json"))
	result["status"] = "complete"
	FileAccess.open("res://tests/phase_5a_integration_regressions.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
func historical(tree: SceneTree) -> void:
	var runner: RefCounted = redirected("res://tests/phase_4b_regressions.gd","phase_4b_regressions.json","phase_5a_historical_regressions.json")
	await runner.start(tree)

func final_tutorial(tree: SceneTree) -> void:
	var suite: RefCounted = load("res://tests/phase_5a_checks.gd").new()
	await suite.start(tree)
	var contexts: RefCounted = load("res://tests/phase_5a_context_checks.gd").new()
	await contexts.start(tree)

func retry_grounded(tree: SceneTree) -> void:
	result = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_5a_integration_regressions.json"))
	result["retry_initial"] = result["retry"].duplicate(true)
	tree.root.set_meta("phase5a_integration_regressions",result)
	result["status"] = "retry_grounding_fixture"
	if tree.root.has_meta(&"defeated_bosses"): tree.root.remove_meta(&"defeated_bosses")
	tree.change_scene_to_file("res://scenes/levels/main_level.tscn")
	await tree.scene_changed
	await step(tree,12)
	# Historical retry checks are unchanged. Only the initial placement waits for
	# actual support, bounded to 30 ticks, instead of assuming 8 ticks suffice.
	# Evidence: phase_5a_retry_ground_diagnostic.json (grounded from tick 9).
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string("res://tests/phase_4b_retry.gd").replace("phase_4b_retry.json","phase_5a_retry_grounded.json").replace("\tawait step(8)\n\tchecks[\"gate_rest_at_normal_attributes\"]", "\tfor tick in range(30):\n\t\tif p.is_on_floor() and gate.contains_player(p): break\n\t\tawait tree.physics_frame\n\tawait tree.process_frame\n\tchecks[\"gate_rest_at_normal_attributes\"]")
	if script.reload() != OK: return
	var suite: RefCounted = script.new()
	await suite.start(tree)
	result["retry"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/phase_5a_retry_grounded.json"))
	result["status"] = "complete"
	FileAccess.open("res://tests/phase_5a_integration_regressions.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
