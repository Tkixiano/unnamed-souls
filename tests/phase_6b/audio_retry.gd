extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	Engine.max_fps = 60
	await process_frame
	change_scene_to_file("res://scenes/ui/main_menu.tscn")
	await scene_changed
	for frame in range(5): await process_frame
	var folder: String = get_script().resource_path.get_base_dir()
	var output: String = folder+"/pack_qa_audio"
	DirAccess.make_dir_recursive_absolute(output)
	var script := GDScript.new()
	script.source_code = FileAccess.get_file_as_string(folder.get_base_dir()+"/phase_5c_checks.gd").replace("res://tests/",output+"/")
	assert(script.reload() == OK)
	var suite: RefCounted = script.new()
	await suite.start(self)
	for frame in range(5): await process_frame
	quit()
