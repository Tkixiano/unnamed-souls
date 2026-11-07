extends RefCounted
## Run through Godot AI game_eval; does not require physical controller input.

func run(tree: SceneTree) -> Dictionary:
	var checks: Dictionary = {}
	var arena := tree.current_scene
	var registry := tree.root.get_node("ControllerRegistry")
	checks["main_scene"] = arena.scene_file_path == "res://scenes/levels/test_arena.tscn"
	checks["player_nodes"] = arena.get_node("Player") is CharacterBody3D \
		and arena.has_node("Player/CollisionShape3D") \
		and arena.has_node("Player/Visual/Placeholder")
	checks["world_nodes"] = arena.has_node("Ground/CollisionShape3D") \
		and arena.has_node("DirectionalLight3D") and tree.root.get_camera_3d().current
	checks["physics_60"] = Engine.physics_ticks_per_second == 60
	checks["resolution"] = tree.root.get_visible_rect().size == Vector2(1280, 720)
	checks["renderer"] = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	checks["mouse_visible"] = Input.mouse_mode == Input.MOUSE_MODE_VISIBLE
	var actions := ["move_left", "move_right", "move_forward", "move_backward",
		"sprint_dodge", "camera_left", "camera_right", "camera_up", "camera_down",
		"lock_on", "light_attack", "heavy_attack", "block", "parry", "two_hand_toggle",
		"use_item", "interact", "pause_game", "menu_confirm", "menu_cancel"]
	var bindings_valid := true
	var accepts_all_devices := true
	for action in actions:
		if not InputMap.has_action(action):
			bindings_valid = false
			continue
		var has_key := false
		var has_pad := false
		for event in InputMap.action_get_events(action):
			has_key = has_key or event is InputEventKey
			has_pad = has_pad or event is InputEventJoypadButton or event is InputEventJoypadMotion
			if event is InputEventJoypadButton or event is InputEventJoypadMotion:
				accepts_all_devices = accepts_all_devices and event.device == -1
		bindings_valid = bindings_valid and has_key and has_pad
	checks["all_20_actions_keyboard_and_pad"] = bindings_valid
	checks["bindings_accept_any_device_id"] = accepts_all_devices
	var synthetic_button := InputEventJoypadButton.new()
	synthetic_button.device = 7
	synthetic_button.button_index = JOY_BUTTON_RIGHT_SHOULDER
	synthetic_button.pressed = true
	Input.parse_input_event(synthetic_button)
	Input.flush_buffered_events()
	await tree.process_frame
	checks["synthetic_rb_device_7"] = Input.is_action_pressed("light_attack")
	var synthetic_release: InputEventJoypadButton = synthetic_button.duplicate()
	synthetic_release.pressed = false
	Input.parse_input_event(synthetic_release)
	Input.flush_buffered_events()
	checks["startup_inventory"] = registry.get_devices().size() == Input.get_connected_joypads().size()
	checks["availability"] = registry.has_controller() == not Input.get_connected_joypads().is_empty()
	var reports: Array = []
	var updates: Array = []
	var on_report := func(id: int, connected: bool) -> void: reports.append([id, connected])
	var on_update := func() -> void: updates.append(true)
	registry.connection_reported.connect(on_report)
	registry.devices_changed.connect(on_update)
	# Synthetic signals exercise wiring and refresh, not OS/hardware discovery.
	Input.joy_connection_changed.emit(9999, true)
	Input.joy_connection_changed.emit(9999, false)
	checks["synthetic_hotplug_signals"] = reports == [[9999, true], [9999, false]] and updates.size() == 2
	checks["synthetic_events_do_not_invent_hardware"] = registry.get_devices().size() == Input.get_connected_joypads().size()
	registry.connection_reported.disconnect(on_report)
	registry.devices_changed.disconnect(on_update)
	checks["status_label"] = not arena.get_node("HUD/Margin/Info/ControllerStatus").text.is_empty()
	var start_position: Vector3 = arena.get_node("Player").position
	for frame in range(5):
		await tree.physics_frame
	# Phase 1B adds movement; only the at-rest invariant remains applicable.
	checks["player_stable_at_rest"] = arena.get_node("Player").position.distance_to(start_position) < 0.02
	var failed: Array = []
	for check in checks:
		if not checks[check]:
			failed.append(check)
	return {"passed": checks.size() - failed.size(), "total": checks.size(),
		"failed": failed, "checks": checks, "physical_devices": registry.get_devices(),
		"hotplug_test": "synthetic signals only"}
