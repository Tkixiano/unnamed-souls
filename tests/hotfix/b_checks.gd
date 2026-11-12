extends RefCounted
var tree: SceneTree
var p: CharacterBody3D
var d: Node
var rig: Node3D
var lock: Node
var checks: Dictionary = {}
var measurements: Array = []
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func reset(yaw: float = 0.0, pitch: float = -0.2) -> void:
	for action in ["move_left","move_right","move_forward","move_backward","sprint_dodge"]: Input.action_release(action)
	lock.release_lock(&"fixture")
	p.attributes.restore_all()
	p.checkpoint_input_blocked = false
	p.position = Vector3(-1,0.02,1)
	p.velocity = Vector3.ZERO
	p.visual.rotation = Vector3.ZERO
	rig.set_control_mode(0)
	rig.set_orbit_angles(yaw,pitch)
	rig.snap_to_target()
	p.reset_physics_interpolation()
	await step(5)
func roll(v: Vector2, tag: String, locked: bool = false) -> void:
	if locked: lock.try_acquire()
	var expected: Vector3 = p.camera_relative_direction(v).normalized()
	var start: Vector3 = p.position
	var profile: Dictionary = [d.fast_profile,d.medium_profile,d.heavy_profile][d.get_weight_class()].snapshot()
	var stamina: float = p.attributes.current_stamina
	var finished: Dictionary = {"frame":0}
	var start_frame: int = Engine.get_physics_frames()
	d.dodge_finished.connect(func(): finished.frame = Engine.get_physics_frames(), CONNECT_ONE_SHOT)
	var started: bool = d.try_dodge(v)
	var fixed_direction: Vector3 = d.direction
	var timing: bool = true
	var fixed: bool = true
	var ticks: int = 0
	while d.is_active() and ticks < 90:
		if ticks == 3: Input.action_press("move_left")
		if ticks == 8: Input.action_release("move_left")
		await step(1)
		ticks += 1
		var iframe: bool = d.is_active() and d.elapsed+0.0000001 >= profile.iframes_start and d.elapsed < profile.iframes_end-0.0000001
		timing = timing and p.is_invulnerable() == iframe
		fixed = fixed and d.direction.is_equal_approx(fixed_direction)
	var offset: Vector3 = p.position-start
	var horizontal := Vector3(offset.x,0,offset.z)
	checks[tag+"_world_direction"] = started and fixed_direction.dot(expected)>0.9999
	checks[tag+"_physical_distance"] = absf(horizontal.length()-profile.distance)<0.035 and horizontal.normalized().dot(expected)>0.999
	checks[tag+"_duration_iframes"] = abs(finished.frame-start_frame-int(ceil(profile.total*60.0-0.00001))) <= 1 and timing
	checks[tag+"_fixed_no_vertical"] = fixed and absf(offset.y)<0.04 and p.is_on_floor()
	checks[tag+"_cost_free"] = absf(stamina-p.attributes.current_stamina-d.roll_cost)<0.001 and p.action_states.current_state == 0
	if locked: checks[tag+"_lock_kept"] = lock.is_locked()
	measurements.append({"case":tag,"offset":str(offset),"ticks":ticks,"direction":str(fixed_direction)})
func start(t: SceneTree) -> void:
	tree = t
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	await step(8)
	p = tree.current_scene.get_node("Player")
	d = p.dodge_controller
	rig = tree.current_scene.get_node("CameraRig")
	lock = tree.current_scene.get_node("LockOnController")
	# Isolate the autonomous soldier only for exact-distance probes; later integration runs retain it.
	tree.current_scene.get_node("Soldier").process_mode = Node.PROCESS_MODE_DISABLED
	var vectors: Array = [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]
	for angle in [15,30,45,60,120,225,315]: vectors.append(Vector2(sin(deg_to_rad(angle)),-cos(deg_to_rad(angle)))*0.65)
	for locked in [false,true]:
		for i in range(vectors.size()):
			await reset()
			d.equipment_load_percent = 25
			await roll(vectors[i],("locked_" if locked else "free_")+str(i),locked)
	for weight in [50,100]:
		await reset(0.7,-0.65)
		d.equipment_load_percent = weight
		await roll(Vector2(1,-1),"profile_"+str(weight))
	await reset(PI*0.5,-0.8)
	d.equipment_load_percent = 25
	await roll(Vector2(-1,1),"rotated_tilted_camera")
	await reset()
	d.equipment_load_percent = 101
	checks["overloaded_rejected"] = not d.try_dodge(Vector2.UP) and p.attributes.current_stamina == 100
	d.equipment_load_percent = 25
	p.attributes.consume_stamina(90)
	checks["insufficient_stamina_rejected"] = not d.try_dodge(Vector2.UP) and p.attributes.current_stamina == 10
	await reset()
	checks["backstep_zero"] = d.try_dodge(Vector2.ZERO) and d.is_backstep and d.direction.dot(p.visual.global_basis.z)>0.999
	await step(28)
	checks["backstep_unchanged"] = not d.is_active() and absf(p.position.z-2.0)<0.035 and is_equal_approx(d.elapsed,d.backstep_profile.total_duration)
	await reset()
	Input.action_press("move_right",p.input_deadzone*0.5)
	var neutral: Vector2 = Input.get_vector("move_left","move_right","move_forward","move_backward",p.input_deadzone)
	checks["deadzone_backstep"] = neutral.is_zero_approx() and d.try_dodge(neutral) and d.is_backstep
	Input.action_release("move_right")
	await step(28)
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measurements,"physical_devices":Input.get_connected_joypads(),"method":"Simulated action strengths/API; real CharacterBody3D displacement and physics time. Soldier isolated in precision fixture only."}
	FileAccess.open("res://tests/hotfix/b_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOTFIX_B ",result.passed,"/",result.total," failed=",failed)
