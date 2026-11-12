extends RefCounted
var results: Array = []
func start(tree: SceneTree) -> void:
	await tree.root.get_node("GameMenus").new_game()
	for frame in range(10): await tree.physics_frame
	var actor: CharacterBody3D = tree.current_scene.get_node("Soldier1")
	var player: CharacterBody3D = tree.current_scene.get_node("Player")
	actor.brain.set_physics_process(false) # Isolated query benchmark, not combat.
	actor.visual.rotation.y = PI
	var wall := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,3,0.2)
	collider.shape = shape
	wall.add_child(collider)
	tree.current_scene.add_child(wall)
	wall.global_position = actor.global_position+Vector3(0,1.5,2)
	player.restore_at_checkpoint(Transform3D(Basis.IDENTITY,actor.global_position+Vector3(0,0.1,4)),true)
	var previous: Node = load("res://tests/perf_6a/baseline_ai_raw.gd").new()
	previous.actor = actor
	previous.target = player
	for blocked in [true,false]:
		wall.position.x = actor.position.x if blocked else actor.position.x+8
		for frame in range(2): await tree.physics_frame
		for trial in range(10):
			var times: Dictionary = {}
			var same: bool = true
			for j in range(2):
				var old: bool = (j+trial)%2 == 0
				var begin: int = Time.get_ticks_usec()
				for iteration in range(300):
					var detected: bool = previous.can_detect() if old else actor.brain.can_detect()
					same = same and detected == not blocked
				times["old_us_per_call" if old else "new_us_per_call"] = (Time.get_ticks_usec()-begin)/300.0
			results.append({"blocked":blocked,"trial":trial,"same":same,"times":times})
	previous.free()
	wall.queue_free()
	var checks := {"all_20_detection_batches_agree":results.all(func(x): return x.same),"unaware_query_fixture_does_not_acquire":not actor.brain.has_aggro()}
	var result := {"checks":checks,"passed":checks.values().count(true),"total":checks.size(),"samples":results,"scope":"Paired uninstrumented detection calls in actual main-level world, 300 calls per batch, isolated AI only; includes in-range LOS ray"}
	FileAccess.open("res://tests/perf_6a/detection_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("perf6a_detection",result)
