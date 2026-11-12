extends RefCounted
func start(tree: SceneTree) -> void:
	var samples: Array = []
	var names: Array[String] = ["TIME_FPS","MEMORY_STATIC","RENDER_TOTAL_PRIMITIVES_IN_FRAME","RENDER_TOTAL_DRAW_CALLS_IN_FRAME","RENDER_VIDEO_MEM_USED","RENDER_TEXTURE_MEM_USED"]
	var available: PackedStringArray = ClassDB.class_get_integer_constant_list("Performance")
	var begin: int = Time.get_ticks_msec()
	for i in range(10):
		for frame in range(30): await tree.process_frame
		var sample: Dictionary = {}
		for name in names:
			if name in available: sample[name] = Performance.get_monitor(ClassDB.class_get_integer_constant("Performance",name))
		samples.append(sample)
	var report: Dictionary = {"scene":tree.current_scene.scene_file_path,"elapsed_seconds":(Time.get_ticks_msec()-begin)/1000.0,"samples":samples,"processor":OS.get_processor_name(),"adapter":RenderingServer.call("get_video_adapter_name") if RenderingServer.has_method("get_video_adapter_name") else "unknown","memory":OS.call("get_memory_info") if OS.has_method("get_memory_info") else {},"scope":"Stationary development-editor observation; not a school-hardware benchmark"}
	var f := FileAccess.open("res://tests/phase_4a_performance.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	tree.root.set_meta("phase4a_performance",report)
	DirAccess.make_dir_recursive_absolute("res://tests/phase_4a_evidence")
	var ignore := FileAccess.open("res://tests/phase_4a_evidence/.gdignore",FileAccess.WRITE)
	ignore.store_string("")
	await RenderingServer.frame_post_draw
	tree.root.get_texture().get_image().save_png("res://tests/phase_4a_evidence/forest.png")
