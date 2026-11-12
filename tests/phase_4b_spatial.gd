extends RefCounted
## Fixed spatial probes complement the continuous combat route.
var tree: SceneTree
var scene: Node3D
var p: CharacterBody3D
var checks: Dictionary = {}
var samples: Array = []
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func place(at: Vector3) -> void:
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,at),true)
	scene.get_node("CameraRig").set_orbit_angles(0,deg_to_rad(-18))
	scene.get_node("CameraRig").snap_to_target()
func start(t: SceneTree) -> void:
	tree = t
	scene = tree.current_scene
	p = scene.get_node("Player")
	tree.root.set_meta("phase4b_spatial",{"status":"running"})
	# All level brains remain active; these probes are away from combat spawns.
	var cases: Array = [
		[Vector3(-23,0.1,12),"move_left",Vector3.RIGHT,"west"],
		[Vector3(26,0.1,10),"move_right",Vector3.LEFT,"east"],
		[Vector3(0,0.1,23),"move_backward",Vector3.FORWARD,"south"],
		[Vector3(2,0.1,-29),"move_right",Vector3.LEFT,"approach_east"],
		[Vector3(-2,0.1,-29),"move_left",Vector3.RIGHT,"approach_west"]]
	for c in cases:
		place(c[0])
		await step(6)
		Input.action_press(c[1])
		var minimum_y: float = p.position.y
		for i in range(75):
			minimum_y = minf(minimum_y,p.position.y)
			await tree.physics_frame
		Input.action_release(c[1])
		await step(10)
		checks[c[3]+"_retains_ground"] = minimum_y > -0.2 and p.is_on_floor()
		var before: Vector3 = p.position
		var away: Vector3 = c[2]
		var action: String = "move_right" if away.x > 0 else "move_left" if away.x < 0 else "move_forward"
		Input.action_press(action)
		await step(30)
		Input.action_release(action)
		await step(10)
		checks[c[3]+"_can_retreat"] = p.position.distance_to(before) > 0.6
		samples.append({"case":c[3],"min_y":minimum_y,"final":str(p.position)})
	# Ground beneath cardinal arena limits is sampled via actual falling capsule.
	for point in [Vector3(-8,0.5,-48),Vector3(8,0.5,-48),Vector3(0,0.5,-56),Vector3(-6,0.5,-42)]:
		place(point)
		await step(40)
		checks["arena_landing_"+str(point)] = p.is_on_floor() and p.position.y > -0.3
	var rig: Node3D = scene.get_node("CameraRig")
	for i in range(12):
		var trunk: Node3D = scene.get_node("Forest/Trunk"+str(i))
		var at: Vector3 = trunk.global_position+Vector3(0,-trunk.position.y+0.1,1.3)
		place(at)
		rig.set_orbit_angles(PI,0)
		rig.snap_to_target()
		await step(18)
		checks["camera_tree_"+str(i)] = rig.spring_arm.get_hit_length() < rig.normal_distance-0.3
	var failed: Array = []
	for k in checks:
		if not checks[k]: failed.append(k)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"samples":samples,"scope":"Fixed edge, retreat, landing and camera probes. Not exhaustive continuous-space QA."}
	tree.root.set_meta("phase4b_spatial",result)
	FileAccess.open("res://tests/phase_4b_spatial.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
