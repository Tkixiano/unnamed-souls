extends SceneTree
var variant: String
var actors: Array[CharacterBody3D] = []
var player: CharacterBody3D
var samples: Array = []
var failures: Array = []
var serial: int = 0
var phase_path: String
var origins: Array[Vector3] = []
func _initialize() -> void:
	variant = OS.get_cmdline_user_args()[0]
	phase_path = "res://tests/perf_6a/"+variant+"_phase.json"
	_run.call_deferred()
func phase(label: String, detail: Dictionary = {}) -> void:
	FileAccess.open(phase_path,FileAccess.WRITE).store_string(JSON.stringify({"pid":OS.get_process_id(),"label":label,"variant":variant,"detail":detail}))
func ticks(n: int) -> void:
	for i in range(n): await physics_frame
	await process_frame
func setup(profiled: bool, count: int, blocked: bool) -> Resource:
	phase("setup")
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	var scene: Node = load("res://scenes/levels/main_level.tscn").instantiate()
	actors.clear()
	origins.clear()
	player = scene.get_node("Player")
	var ai_script: Script = load("res://tests/perf_6a/"+variant+"_ai_"+("profiled" if profiled else "raw")+".gd")
	for name in ["Soldier1","Soldier2"]:
		var actor: CharacterBody3D = scene.get_node(name)
		if profiled: actor.set_script(load("res://tests/perf_6a/profiled_actor.gd"))
		var brain: Node = actor.get_node("SoldierAI")
		brain.set_script(ai_script)
		brain.actor = actor
		brain.target = player
		actors.append(actor)
	root.add_child(scene)
	current_scene = scene
	scene_changed.emit()
	await ticks(15)
	for actor in actors: origins.append(actor.global_position)
	for i in range(count):
		var actor: CharacterBody3D = actors[i]
		player.restore_at_checkpoint(Transform3D(Basis.IDENTITY,origins[i]+Vector3(0,0.1,5)),true)
		actor.visual.global_rotation.y = PI
		actor.brain.decision_remaining = 0
		await ticks(3)
		if not actor.brain.has_aggro(): failures.append("acquisition:"+str(i))
	player.restore_at_checkpoint(Transform3D(Basis.IDENTITY,Vector3(1,0.1,20)),true)
	if blocked:
		for i in range(count):
			var body := StaticBody3D.new()
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(4,3,0.2)
			collider.shape = shape
			body.add_child(collider)
			scene.add_child(body)
			body.global_position = origins[i]+Vector3(0,1.5,1.0)
	for i in range(actors.size()):
		actors[i].global_position = origins[i]
		actors[i].velocity = Vector3.ZERO
	await ticks(90 if blocked else 30)
	return load("res://tests/perf_6a/"+variant+"_queries_profiled.gd") if profiled else null
func window(profiled: bool, count: int, blocked: bool, trial: int) -> void:
	var queries: Resource = await setup(profiled,count,blocked)
	if profiled:
		queries.stats.clear()
		for actor in actors:
			actor.perf.clear()
			actor.brain.perf.clear()
	serial += 1
	var label: String = ("profile" if profiled else "cpu")+"_"+str(count)+( "_blocked" if blocked else "_chase")+"_"+str(trial)
	phase(label)
	var timeline: Array = []
	var states: Dictionary = {}
	var duration: int = 120 if profiled else 240
	var begin: int = Time.get_ticks_usec()
	for frame in range(duration):
		# Repeated 2 s pursuit episodes: reset fixture placement only, not aggro.
		# The player stays beyond attack range and all combat components stay live.
		if frame > 0 and frame % 120 == 0 and not blocked:
			for i in range(actors.size()):
				actors[i].global_position = origins[i]
				actors[i].velocity = Vector3.ZERO
		await physics_frame
		var active: int = 0
		for actor in actors:
			if actor.brain.has_aggro(): active += 1
			var key: String = actor.brain.state_name()
			states[key] = int(states.get(key,0))+1
		if active != count: failures.append(label+":aggro_count="+str(active))
		if frame % 12 == 0:
			timeline.append({"fps":Performance.get_monitor(Performance.TIME_FPS),"process_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,"physics_ms":Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000,"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"memory_static":Performance.get_monitor(Performance.MEMORY_STATIC),"physics_pairs":Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS)})
	var record := {"label":label,"profiled":profiled,"aggro_count":count,"blocked":blocked,"trial":trial,"ticks":duration,"wall_seconds":(Time.get_ticks_usec()-begin)/1000000.0,"states":states,"monitors":timeline}
	if profiled:
		record["queries"] = queries.stats.duplicate()
		record["actors"] = actors.map(func(actor): return {"actor":actor.perf.duplicate(),"ai":actor.brain.perf.duplicate()})
	samples.append(record)
	phase("between")
func _run() -> void:
	Engine.max_fps = 60
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280,720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	for pair in [["ControllerRegistry","res://scripts/systems/controller_registry.gd"],["GameMenus","res://scenes/ui/game_menus.tscn"],["AudioDirector","res://scenes/audio/audio_director.tscn"]]:
		if root.has_node(pair[0]): continue
		var resource: Resource = load(pair[1])
		var instance: Node = resource.instantiate() if resource is PackedScene else resource.new()
		instance.name = pair[0]
		root.add_child(instance)
	phase("waiting_for_sampler")
	while not FileAccess.file_exists("res://tests/perf_6a/"+variant+"_sampler_ready"):
		await process_frame
	for profiled in [false,true]:
		for trial in range(3):
			# Rotate order to reduce ordering/thermal bias.
			var conditions: Array = [[0,false],[1,false],[2,false],[2,true]]
			for j in range(4):
				var condition: Array = conditions[(j+trial)%4]
				await window(profiled,condition[0],condition[1],trial)
	var result := {"variant":variant,"processor":OS.get_processor_name(),"logical_cpus":OS.get_processor_count(),"system_memory":OS.get_memory_info(),"godot":Engine.get_version_info(),"soldiers":2,"samples":samples,"failures":failures,"resolution":"1280x720","cap":60,"instrumented_cpu_excluded":true}
	FileAccess.open("res://tests/perf_6a/"+variant+"_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	phase("complete")
	await process_frame
	quit(0)
