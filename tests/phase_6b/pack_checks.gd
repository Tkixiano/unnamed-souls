extends SceneTree
## External QA driver. All gameplay resources resolve from the exported pack.
## This driver and historical test sources are not shipped with the game.
var out: String
var source_tests: String
var result: Dictionary = {"status":"running","suites":{}}
var menus: Node
func _initialize() -> void:
	source_tests = get_script().resource_path.get_base_dir().get_base_dir()
	out = get_script().resource_path.get_base_dir()+"/pack_qa"
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()
func frames(n: int) -> void:
	for i in range(n): await process_frame
func physics(n: int) -> void:
	for i in range(n): await physics_frame
	await process_frame
func save() -> void:
	FileAccess.open(out+"/results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
func suite(name: String) -> RefCounted:
	var script := GDScript.new()
	var code := FileAccess.get_file_as_string(source_tests+"/"+name+".gd")
	code = code.replace("res://tests/",out+"/")
	if name == "phase_4b_retry":
		code = code.replace("\tawait step(8)\n\tchecks[\"gate_rest_at_normal_attributes\"]", "\tfor tick in range(30):\n\t\tif p.is_on_floor() and gate.contains_player(p): break\n\t\tawait tree.physics_frame\n\tawait tree.process_frame\n\tchecks[\"gate_rest_at_normal_attributes\"]")
	script.source_code = code
	assert(script.reload() == OK)
	return script.new()
func fresh(scene: String) -> void:
	load("res://scripts/systems/session_progress.gd").reset_session(self)
	change_scene_to_file(scene)
	await scene_changed
	await physics(12)
func _run() -> void:
	Engine.max_fps = 60
	await frames(2)
	menus = root.get_node("GameMenus")
	result["context"] = "Editor-capable engine in game mode loading the actual embedded Release PCK via --main-pack; NOT the Release executable or editor UI. External driver and test sources only."
	result["environment"] = {"engine_exe":OS.get_executable_path(),"mcp_helper":root.has_node("_mcp_game_helper"),"source_tests_available_in_pack":FileAccess.file_exists("res://tests/aggro_checks.gd"),"project_title":ProjectSettings.get_setting("application/config/name"),"main":ProjectSettings.get_setting("application/run/main_scene"),"joypads":Input.get_connected_joypads()}
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	await frames(5)
	for name in ["phase_5c_checks","phase_5b_checks","aggro_checks"]:
		result["current"] = name
		save()
		var test: RefCounted = suite(name)
		await test.start(self)
		var filename: String = "aggro_results.json" if name == "aggro_checks" else name.replace("checks","results")+".json"
		result.suites[name] = JSON.parse_string(FileAccess.get_file_as_string(out+"/"+filename))
		await frames(5)
	var saved_victory: bool = menus.automatic_victory_screen
	menus.automatic_victory_screen = false
	for name in ["phase_4b_checks","phase_4b_retry","phase_5a_checks","phase_5a_context_checks"]:
		await fresh("res://scenes/levels/main_level.tscn")
		result["current"] = name
		save()
		var test: RefCounted = suite(name)
		await test.start(self)
		var filename: String = "phase_4b_retry.json" if name == "phase_4b_retry" else "phase_5a_context_results.json" if name == "phase_5a_context_checks" else name.replace("checks","results")+".json"
		result.suites[name] = JSON.parse_string(FileAccess.get_file_as_string(out+"/"+filename))
	result["current"] = "phase_3c_checks"
	save()
	await fresh("res://scenes/levels/boss_arena.tscn")
	await physics(100)
	var boss_test: RefCounted = suite("phase_3c_checks")
	result.suites["phase_3c_checks"] = await boss_test.run(self)
	menus.automatic_victory_screen = saved_victory
	result["status"] = "complete"
	var passed: int = 0
	var total: int = 0
	var failed: Array = []
	for key in result.suites:
		var data: Dictionary = result.suites[key]
		passed += data.passed
		total += data.total
		for item in data.failed: failed.append(key+":"+item)
	result.merge({"passed":passed,"total":total,"failed":failed})
	save()
	quit(0 if failed.is_empty() else 1)
