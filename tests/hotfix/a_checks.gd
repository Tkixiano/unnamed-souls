extends RefCounted
var tree: SceneTree
var checks: Dictionary = {}
var measurements: Dictionary = {}
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func start(t: SceneTree) -> void:
	tree = t
	var menus: Node = tree.root.get_node("GameMenus")
	var old: bool = menus.automatic_victory_screen
	menus.automatic_victory_screen = false
	for path in ["ruins_boss_arena", "main_level"]:
		load("res://scripts/systems/session_progress.gd").reset_session(tree)
		tree.change_scene_to_file("res://scenes/levels/"+path+".tscn")
		await tree.scene_changed
		await step(100)
		var scene: Node = tree.current_scene
		var p: CharacterBody3D = scene.get_node("Player")
		var b: CharacterBody3D = scene.get_node("Boss")
		var ai: Node = b.brain
		var center: Vector3 = ai.arena_center
		p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,center+Vector3(0,0.1,7)),true)
		await step(8)
		checks[path+"_fog_activation"] = ai.encounter_active
		b.attributes.apply_damage(50.0)
		for phase in [1,2]:
			if phase == 2:
				b.attributes.apply_damage(251.0)
				# Wait safely out of attack range for the real transition.
				p.global_position = center+Vector3(0,0.1,-10.5)
				await step(150)
				checks[path+"_phase_two"] = ai.phase_two and ai.transition_count == 1
			var hp: float = b.attributes.current_health
			for point in [Vector3(0,0.1,-11),Vector3(-11,0.1,0),Vector3(11,0.1,0),Vector3(0,0.1,0)]:
				p.global_position = center+point
				p.velocity = Vector3.ZERO
				await step(6)
				var tag: String = path+"_phase"+str(phase)+"_"+str(point)
				checks[tag+"_active_target"] = ai.encounter_active and ai.target == p
				checks[tag+"_health_phase"] = is_equal_approx(b.attributes.current_health,hp) and ai.phase_two == (phase==2)
				checks[tag+"_physical_ground"] = p.is_on_floor() and ai.inside_arena(p.global_position)
			# Pursue with the real actor, no speed or attack changes.
			p.global_position = center+Vector3(0,0.1,-10.5)
			var before: Vector3 = b.global_position
			await step(75)
			checks[path+"_pursuit_phase"+str(phase)] = ai.encounter_active and b.global_position.distance_to(before)>0.05
			measurements[path+"_phase"+str(phase)] = {"boss_position":str(b.global_position),"health":b.attributes.current_health,"state":ai.state_name()}
		# A spatial escape remains non-destructive even beyond the movement envelope.
		p.global_position = center+Vector3(0,0.1,-14.1)
		await step(2)
		checks[path+"_no_spatial_reset"] = ai.encounter_active and b.attributes.current_health < 600
		b.restore_at_checkpoint()
		checks[path+"_explicit_reset"] = not ai.encounter_active and not ai.phase_two and b.attributes.current_health == 600 and not b.attack_controller.hitbox.is_active()
	menus.automatic_victory_screen = old
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result: Dictionary = {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measurements,"physical_devices":Input.get_connected_joypads(),"method":"Physics integration; controlled player placements. Not visual reproduction or physical joystick input."}
	FileAccess.open("res://tests/hotfix/a_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("HOTFIX_A ",result.passed,"/",result.total," failed=",failed)

