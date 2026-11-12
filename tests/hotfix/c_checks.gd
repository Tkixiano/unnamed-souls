extends RefCounted
var tree: SceneTree
var p: CharacterBody3D
var rig: Node3D
var lock: Node
var checks: Dictionary = {}
var measures: Dictionary = {}
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func release() -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint_dodge","block"]: Input.action_release(action)
func reset() -> void:
	release()
	lock.release_lock(&"fixture")
	p.attributes.restore_all()
	p.checkpoint_input_blocked = false
	p.position = Vector3(-1,0.02,1)
	p.velocity = Vector3.ZERO
	p.visual.rotation = Vector3.ZERO
	rig.set_control_mode(0)
	rig.set_orbit_angles(0,-0.2)
	rig.snap_to_target()
	await step(5)
	checks["initial_acquisition"] = lock.try_acquire()
	await step(2)
func move(v: Vector2) -> void:
	for action in ["move_left","move_right","move_forward","move_backward"]: Input.action_release(action)
	if v.x < 0: Input.action_press("move_left",-v.x)
	if v.x > 0: Input.action_press("move_right",v.x)
	if v.y < 0: Input.action_press("move_forward",-v.y)
	if v.y > 0: Input.action_press("move_backward",v.y)
func start(t: SceneTree) -> void:
	tree = t
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	await step(8)
	p = tree.current_scene.get_node("Player")
	rig = tree.current_scene.get_node("CameraRig")
	lock = tree.current_scene.get_node("LockOnController")
	tree.current_scene.get_node("Soldier").process_mode = Node.PROCESS_MODE_DISABLED
	for v in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		await reset()
		var target: Node = lock.current_target
		move(v)
		await step(10)
		checks[str(v)+"_walk"] = lock.is_locked() and not p.is_sprinting
		Input.action_press("sprint_dodge")
		await step(40)
		checks[str(v)+"_run"] = p.is_sprinting and lock.current_target == target and rig.control_mode == 1
		checks[str(v)+"_speed_cost"] = absf(p.horizontal_speed-p.run_speed)<0.04 and p.attributes.current_stamina<100
		release()
		await step(4)
		checks[str(v)+"_stop"] = not p.is_sprinting and lock.current_target == target
	await reset()
	move(Vector2.LEFT)
	Input.action_press("sprint_dodge")
	await step(40)
	var before: float = p.attributes.current_stamina
	var frame: int = Engine.get_physics_frames()
	await step(15)
	var cost: float = before-p.attributes.current_stamina
	checks["continuous_cost_unchanged"] = absf(cost-(Engine.get_physics_frames()-frame)*p.sprint_stamina_cost/60.0)<0.001
	p.attributes.consume_stamina(p.attributes.current_stamina-0.2)
	await step(3)
	checks["exhaustion_keeps_lock"] = not p.is_sprinting and lock.is_locked() and p.locomotion_state == 1
	release()
	await reset()
	move(Vector2.UP)
	Input.action_press("sprint_dodge")
	await step(40)
	release()
	await step(3)
	var target: Node = lock.current_target
	checks["sequence_diagonal_dodge"] = p.dodge_controller.try_dodge(Vector2(1,-1))
	await step(12)
	checks["sequence_mid_dodge_lock"] = lock.current_target == target and rig.control_mode == 1
	# SceneTree pause freezes the in-progress dodge, actor and stamina.
	var position: Vector3 = p.position
	var elapsed: float = p.dodge_controller.elapsed
	var stamina: float = p.attributes.current_stamina
	tree.paused = true
	for i in range(6): await tree.process_frame
	checks["pause_during_locked_dodge"] = p.position == position and p.dodge_controller.elapsed == elapsed and p.attributes.current_stamina == stamina
	tree.paused = false
	await step(28)
	move(Vector2.LEFT)
	Input.action_press("sprint_dodge")
	await step(40)
	checks["sequence_run_again"] = p.is_sprinting and lock.current_target == target
	release()
	await step(3)
	checks["sequence_attack"] = p.attack_controller.request_attack(0) and lock.current_target == target
	await step(52)
	Input.action_press("block")
	await step(3)
	checks["sequence_block"] = p.defense_controller.is_blocking() and lock.current_target == target
	release()
	await step(3)
	lock.release_lock(&"manual")
	checks["manual_cancel_free_camera"] = not lock.is_locked() and rig.control_mode == 0
	await reset()
	lock.current_target.available = false
	await step(2)
	checks["unavailable_still_breaks"] = not lock.is_locked()
	# Restore fixture target, then test range without changing configured limits.
	for node in tree.get_nodes_in_group("lockable_targets"): node.available = true
	await reset()
	p.position.z = 20
	await step(2)
	checks["distance_still_breaks"] = not lock.is_locked() and lock.last_release_reason == &"distance" and rig.control_mode == 0
	release()
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"physical_devices":Input.get_connected_joypads(),"method":"Simulated action input; real locomotion, stamina, dodge, camera, attack, defense and SceneTree pause. Autonomous soldier isolated in this precision fixture; active combat tested separately."}
	FileAccess.open("res://tests/hotfix/c_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOTFIX_C ",result.passed,"/",result.total," failed=",failed)
