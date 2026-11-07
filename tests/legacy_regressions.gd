extends RefCounted
## Preserve historical no-action/no-cost short-release contracts explicitly.

func start(tree: SceneTree) -> void:
	var report := {"status":"running","results":{}}
	tree.root.set_meta("legacy_regressions",report)
	var p := tree.current_scene.get_node("Player")
	var rig := tree.current_scene.get_node("CameraRig")
	var checkpoints: Node = tree.current_scene.get_node("CheckpointManager")
	var auto_respawn: bool = checkpoints.automatic_respawn_enabled
	var interactions: bool = checkpoints.interaction_enabled
	var player_position: Vector3 = p.position
	checkpoints.cancel_pending_respawn()
	checkpoints.automatic_respawn_enabled = false
	checkpoints.interaction_enabled = false
	var soldier: Node3D = tree.current_scene.get_node("Soldier")
	var soldier_position: Vector3 = soldier.position
	# Historical fixtures predate an autonomous hostile. Isolate the complete actor,
	# including physics/target queries; 3A separately tests active integrated combat.
	soldier.process_mode = Node.PROCESS_MODE_DISABLED
	soldier.hide()
	soldier.position = Vector3(40,0,40)
	for phase in ["1a","1b","1c","1d","2a","2b","2c","2d","2e","3a","3b"]:
		if phase in ["3a","3b"]:
			soldier.position = soldier_position
			soldier.attributes.restore_all()
			soldier.show()
			soldier.process_mode = Node.PROCESS_MODE_INHERIT
		for action in ["move_left","move_right","move_forward","move_backward","sprint_dodge","camera_right"]:
			Input.action_release(action)
		tree.current_scene.get_node("LockOnController").release_lock(&"test_reset")
		p.attributes.restore_all()
		p.position = Vector3.ZERO
		p.velocity = Vector3.ZERO
		p.visual.rotation = Vector3.ZERO
		p.reset_physics_interpolation()
		rig.set_control_mode(0)
		rig.set_orbit_angles(0.0,deg_to_rad(rig.initial_pitch))
		rig.snap_to_target()
		if phase == "3b":
			# Restore the authored initial checkpoint fixture; historical checks stay intact.
			var spawn: Transform3D = checkpoints.get_respawn_transform()
			var forward: Vector3 = -spawn.basis.z
			var yaw: float = atan2(-forward.x,-forward.z)
			p.position = spawn.origin
			p.visual.global_rotation = Vector3(0,yaw,0)
			rig.set_orbit_angles(yaw,deg_to_rad(rig.initial_pitch))
			rig.snap_to_target()
			checkpoints.automatic_respawn_enabled = true
			checkpoints.interaction_enabled = true
		var isolated: bool = phase in ["1b","1d","2a"]
		p.dodge_controller.input_enabled = not isolated
		p.riposte_controller.backstab_enabled = phase != "2c"
		report["current"] = phase
		for frame in range(8):
			await tree.physics_frame
		var suite: RefCounted = load("res://tests/phase_%s_checks.gd" % phase).new()
		var result: Dictionary = await suite.run(tree)
		result["short_release_listener_isolated"] = isolated
		result["attack_input_enabled"] = p.attack_controller.input_enabled
		result["defense_input_enabled"] = p.defense_controller.input_enabled
		result["backstab_acquisition_isolated"] = phase == "2c"
		result["estus_input_enabled"] = p.estus_controller.input_enabled
		result["grip_input_enabled"] = p.grip_controller.input_enabled
		result["autonomous_soldier_isolated"] = phase not in ["3a","3b"]
		result["automatic_checkpoint_lifecycle_isolated"] = phase != "3b"
		report.results[phase] = result
	p.dodge_controller.input_enabled = true
	p.riposte_controller.backstab_enabled = true
	p.attributes.restore_all()
	p.position = player_position
	soldier.position = soldier_position
	soldier.velocity = Vector3.ZERO
	soldier.attributes.restore_all()
	soldier.show()
	soldier.process_mode = Node.PROCESS_MODE_INHERIT
	checkpoints.automatic_respawn_enabled = auto_respawn
	checkpoints.interaction_enabled = interactions
	report["status"] = "complete"
