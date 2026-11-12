extends RefCounted
const Old = preload("res://tests/perf_6a/baseline_enemy_world_queries.gd")
const Queries = preload("res://scripts/enemies/enemy_world_queries.gd")
var checks: Dictionary = {}
var micro: Array = []
func microbench(actor: CharacterBody3D, probe: RefCounted, blocked: bool) -> void:
	# Paired calls in an unchanged physics world; no instrumentation in either path.
	for trial in range(10):
		var times: Dictionary = {}
		for j in range(2):
			var old: bool = (j+trial)%2 == 0
			var begin: int = Time.get_ticks_usec()
			for iteration in range(300):
				if old: Old.can_step(actor,Vector3.BACK)
				else: Queries.can_step(actor,Vector3.BACK,0.35,1.6,0.95,probe)
			times["old_us_per_call" if old else "new_us_per_call"] = (Time.get_ticks_usec()-begin)/300.0
		micro.append({"blocked":blocked,"trial":trial,"times":times})
func step(tree: SceneTree,n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func start(tree: SceneTree) -> void:
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	await step(tree,8)
	var actor: CharacterBody3D = tree.current_scene.get_node("Soldier")
	actor.brain.enabled = false # Query fixture only; full aggro suite runs separately.
	var probe = actor.brain._step_probe
	var ids := [probe.shape.get_instance_id(),probe.volume.get_instance_id(),probe.ground.get_instance_id()]
	var matched: bool = true
	var count: int = 0
	var dirs: Array = [Vector3.ZERO,Vector3.FORWARD,Vector3.BACK,Vector3.LEFT,Vector3.RIGHT,Vector3(1,0,1),Vector3(-1,0,1),Vector3(1,0,-1),Vector3(-1,0,-1)]
	for x in [-9.5,-4.0,0.0,4.0,9.5]:
		for z in [-9.5,-4.0,0.0,4.0,9.5]:
			actor.global_position = Vector3(x,0,z)
			for direction in dirs:
				matched = matched and Old.can_step(actor,direction) == Queries.can_step(actor,direction,0.35,1.6,0.95,probe)
				matched = matched and Old.can_step(actor,direction,0.55,2.4,1.4) == Queries.can_step(actor,direction,0.55,2.4,1.4)
				count += 2
	checks["450_fresh_vs_reused_and_default_query_comparisons"] = matched and count == 450
	actor.global_position = Vector3(0,0,-1.6)
	actor.velocity = Vector3.ZERO
	await step(tree,2)
	var wall := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(4,3,0.2)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	wall.add_child(collider)
	tree.current_scene.add_child(wall)
	wall.position = Vector3(0,1.5,-0.8)
	await step(tree,2)
	checks["blocked_probe_agrees_with_original"] = not Queries.can_step(actor,Vector3.BACK,0.35,1.6,0.95,probe) and not Old.can_step(actor,Vector3.BACK)
	wall.position.x = 6
	await step(tree,1)
	checks["moving_obstacle_clearance_seen_next_physics_tick"] = Queries.can_step(actor,Vector3.BACK,0.35,1.6,0.95,probe) and Old.can_step(actor,Vector3.BACK)
	wall.position.x = 0
	await step(tree,1)
	checks["new_obstruction_seen_next_physics_tick"] = not Queries.can_step(actor,Vector3.BACK,0.35,1.6,0.95,probe) and not Old.can_step(actor,Vector3.BACK)
	microbench(actor,probe,true)
	checks["resources_reused_not_results"] = ids == [probe.shape.get_instance_id(),probe.volume.get_instance_id(),probe.ground.get_instance_id()]
	checks["query_mask_preserved"] = probe.volume.collision_mask == 1
	checks["actor_rid_excluded"] = probe.volume.exclude == [actor.get_rid()]
	wall.queue_free()
	await step(tree,2)
	microbench(actor,probe,false)
	actor.restore_at_checkpoint()
	checks["restoration_keeps_safe_parameter_objects"] = actor.brain._step_probe == probe and ids == [probe.shape.get_instance_id(),probe.volume.get_instance_id(),probe.ground.get_instance_id()]
	actor.brain.enabled = false
	actor.brain.set_physics_process(false) # Otherwise its early return clears move intent.
	actor.global_position = Vector3(0,0,-4)
	var position: Vector3 = actor.global_position
	for frame in range(30):
		actor.set_move_intent(Vector3.BACK)
		await tree.physics_frame
	checks["physical_movement_still_advances"] = actor.global_position.z > position.z+0.5
	checks["speed_acceleration_and_attack_data_unchanged"] = actor.speed == 2.0 and actor.acceleration == 8.0 and actor.attack_controller.light_1.startup == 0.55 and actor.attack_controller.light_1.damage == 20.0
	tree.reload_current_scene()
	await tree.scene_changed
	await step(tree,8)
	actor = tree.current_scene.get_node("Soldier")
	actor.brain.enabled = false
	checks["old_parameters_safe_in_new_world"] = Old.can_step(actor,Vector3.BACK) == Queries.can_step(actor,Vector3.BACK,0.35,1.6,0.95,probe) and probe.volume.exclude == [actor.get_rid()]
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"comparisons":count,"microbenchmark":micro,"scope":"Only query fixture disables decisions. Aggro/lifecycle regression separately runs real active soldiers."}
	FileAccess.open("res://tests/perf_6a/query_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("perf6a_queries",result)
