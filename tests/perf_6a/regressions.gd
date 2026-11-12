extends RefCounted
## Mechanical suites retain their checks. Only the automatic victory pause is
## isolated here; perf6a_checks runs the real victory overlay and pause flow.
const Progress = preload("res://scripts/systems/session_progress.gd")
var result: Dictionary = {"status":"running"}
var saved_options: Dictionary
var saved_victory: bool
func frames(tree: SceneTree,n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func prepare(tree: SceneTree) -> void:
	var menus: Node = tree.root.get_node("GameMenus")
	saved_victory = menus.automatic_victory_screen
	saved_options = menus.options.values.duplicate()
	menus.automatic_victory_screen = false
	for key in menus.options.DEFAULTS: menus.options.set_value(key,menus.options.DEFAULTS[key])
	result["isolation"] = "Automatic victory overlay only, so historical physics clocks can continue after boss death. Core UI tested separately with it enabled. Existing historical actor/short-input/checkpoint fixtures remain documented."
func restore(tree: SceneTree) -> void:
	var menus: Node = tree.root.get_node("GameMenus")
	menus.automatic_victory_screen = saved_victory
	for key in saved_options: menus.options.set_value(key,saved_options[key])
func clone_suite(path: String, replacements: Dictionary) -> RefCounted:
	var script := GDScript.new()
	var code: String = FileAccess.get_file_as_string(path)
	for old in replacements: code = code.replace(old,replacements[old])
	if path.ends_with("phase_4b_retry.gd"):
		# Preserve the supported 5A preparation fix, not a weaker expectation.
		code = code.replace("\tawait step(8)\n\tchecks[\"gate_rest_at_normal_attributes\"]", "\tfor tick in range(30):\n\t\tif p.is_on_floor() and gate.contains_player(p): break\n\t\tawait tree.physics_frame\n\tawait tree.process_frame\n\tchecks[\"gate_rest_at_normal_attributes\"]")
	script.source_code = code
	if script.reload() != OK: return null
	return script.new()
func fresh_level(tree: SceneTree) -> void:
	Progress.reset_session(tree)
	tree.change_scene_to_file("res://scenes/levels/main_level.tscn")
	await tree.scene_changed
	await frames(tree,12)
func integration(tree: SceneTree) -> void:
	prepare(tree)
	tree.root.set_meta("perf6a_integration",result)
	await fresh_level(tree)
	for part in ["checks","spatial","retry"]:
		if part == "retry": await fresh_level(tree)
		result["current"] = "4b_"+part
		var old: String = "phase_4b_results.json" if part == "checks" else "phase_4b_"+part+".json"
		var output: String = "perf_6a/perf6a_regression_4b_"+part+".json"
		var suite: RefCounted = clone_suite("res://tests/phase_4b_"+part+".gd",{old:output})
		await suite.start(tree)
		result["4b_"+part] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/"+output))
	result["current"] = "4a"
	await fresh_level(tree)
	var runner: RefCounted = clone_suite("res://tests/phase_4b_regressions.gd",{"phase_4b_4a_regression.json":"perf_6a/perf6a_regression_4a.json"})
	await runner.integrated4a(tree)
	result["4a"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/perf_6a/perf6a_regression_4a.json"))
	result["current"] = "5a"
	await fresh_level(tree)
	for part in ["checks","context_checks"]:
		var old: String = "phase_5a_results.json" if part == "checks" else "phase_5a_context_results.json"
		var output: String = "perf_6a/perf6a_regression_5a_"+part+".json"
		var suite: RefCounted = clone_suite("res://tests/phase_5a_"+part+".gd",{old:output})
		await suite.start(tree)
		result["5a_"+part] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/"+output))
	restore(tree)
	result["status"] = "complete"
	FileAccess.open("res://tests/perf_6a/perf6a_integration_regressions.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
func historical(tree: SceneTree) -> void:
	prepare(tree)
	tree.root.set_meta("perf6a_historical",result)
	Progress.reset_session(tree)
	var runner: RefCounted = clone_suite("res://tests/phase_4b_regressions.gd",{"phase_4b_regressions.json":"perf_6a/perf6a_historical_regressions.json"})
	await runner.start(tree)
	restore(tree)
	result["status"] = "complete"
