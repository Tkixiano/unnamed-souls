extends RefCounted
var tree: SceneTree
var menus: Node
var checks: Dictionary = {}
var measures: Dictionary = {}
var original_values: Dictionary
var original_path: String
var fixture_path: String = "user://phase_5b_options_fixture.cfg"
var fixture_existed: bool = false
var fixture_backup: PackedByteArray

func frames(n: int = 2) -> void:
	for i in range(n): await tree.process_frame
func physics(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func action(name: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = pressed
	event.strength = 1 if pressed else 0
	Input.parse_input_event(event)
func tap(name: String) -> void:
	action(name,true)
	await frames()
	action(name,false)
	await frames()
func current() -> Node:
	return tree.current_scene
func new_session() -> void:
	for name in ["move_left","move_right","move_forward","move_backward","menu_confirm","menu_cancel","pause_game","block","sprint_dodge"]: Input.action_release(name)
	await menus.new_game()
	await physics(15)

func start(t: SceneTree) -> void:
	tree = t
	menus = tree.root.get_node("GameMenus")
	tree.root.set_meta("phase5b_result",{"status":"running","checks":checks})
	original_values = menus.options.values.duplicate()
	original_path = menus.options.preferences_path
	fixture_existed = FileAccess.file_exists(fixture_path)
	if fixture_existed: fixture_backup = FileAccess.get_file_as_bytes(fixture_path)
	menus.options.preferences_path = fixture_path
	await run()
	for key in original_values: menus.options.set_value(key,original_values[key])
	menus.options.preferences_path = original_path
	if fixture_existed: FileAccess.open(fixture_path,FileAccess.WRITE).store_buffer(fixture_backup)
	elif FileAccess.file_exists(fixture_path): DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measures,"physical_devices":Input.get_connected_joypads()}
	FileAccess.open("res://tests/phase_5b_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("phase5b_result",result)

func run() -> void:
	await frames(4)
	checks["f5_main_menu"] = current().scene_file_path == "res://scenes/ui/main_menu.tscn"
	checks["main_has_three_choices"] = current().focusables.size() == 3
	checks["main_focus_new_game"] = tree.root.gui_get_focus_owner().name == "new_game"
	checks["no_tutorial_or_player_on_main"] = not current().has_node("TutorialController") and not current().has_node("Player")
	var key := InputEventKey.new()
	key.keycode = KEY_DOWN
	key.pressed = true
	Input.parse_input_event(key)
	await frames()
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	checks["keyboard_navigation"] = tree.root.gui_get_focus_owner().name == "options"
	await tap("menu_confirm")
	checks["confirm_opens_options_once"] = menus.screen == menus.Screen.OPTIONS and tree.root.gui_get_focus_owner().name == "master"
	var panel: Control = menus.options_panel
	checks["eight_options_and_back"] = panel.focusables.size() == 9
	panel.focusables[0].value = 55
	panel.focusables[1].value = 35
	panel.focusables[2].value = 65
	checks["three_audio_buses"] = AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0
	checks["master_volume_applied"] = is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(0)),0.55)
	checks["music_volume_applied"] = is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.35)
	checks["effects_volume_applied"] = is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))),0.65)
	panel.focusables[0].value = 0
	checks["zero_volume_mutes_bus"] = AudioServer.is_bus_mute(0)
	panel.focusables[0].value = 55
	checks["raising_volume_unmutes_bus"] = not AudioServer.is_bus_mute(0)
	var horizontal_slider: HSlider = panel.focusables.filter(func(control): return control.name == "horizontal")[0]
	horizontal_slider.grab_focus()
	var h: float = horizontal_slider.value
	await tap("ui_right")
	checks["slider_keyboard_adjustment"] = horizontal_slider.value == h+5
	menus.options.set_value("fullscreen",true)
	await frames(3)
	checks["fullscreen_applied"] = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	menus.options.set_value("fullscreen",false)
	await frames(3)
	checks["window_mode_restored"] = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	checks["preferences_saved"] = menus.options.save_preferences() == OK
	var reload_options: RefCounted = load("res://scripts/systems/game_options.gd").new()
	reload_options.preferences_path = fixture_path
	reload_options.load_preferences()
	checks["preferences_survive_fresh_settings_instance"] = reload_options.values == menus.options.values
	var config := ConfigFile.new()
	config.load(fixture_path)
	checks["config_contains_only_preferences"] = config.get_sections() == PackedStringArray(["options"]) and config.get_section_keys("options").size() == 8
	checks["preferences_replace_existing_file"] = menus.options.save_preferences() == OK
	await tap("menu_cancel")
	checks["options_back_restores_main_focus"] = menus.screen == menus.Screen.NONE and tree.root.gui_get_focus_owner().name == "options"
	# Synthetic stick uses the existing semantic actions, never physical indices.
	Input.action_press("move_backward")
	await frames(4)
	checks["simulated_stick_navigation"] = tree.root.gui_get_focus_owner().name == "quit"
	await frames(10)
	checks["held_stick_does_not_repeat"] = tree.root.gui_get_focus_owner().name == "quit"
	Input.action_release("move_backward")
	await frames(3)
	Input.action_press("move_backward")
	await frames(3)
	Input.action_release("move_backward")
	await frames(3)
	checks["neutral_rearms_stick"] = tree.root.gui_get_focus_owner().name == "new_game"
	var dpad: InputEvent
	for candidate in InputMap.action_get_events("ui_down"):
		if candidate is InputEventJoypadButton:
			dpad = candidate.duplicate()
			break
	if dpad != null:
		dpad.device = 0
		dpad.pressed = true
		Input.parse_input_event(dpad)
		await frames()
		checks["simulated_dpad_uses_existing_mapping"] = tree.root.gui_get_focus_owner().name == "options"
		dpad = dpad.duplicate()
		dpad.pressed = false
		Input.parse_input_event(dpad)
	else: checks["simulated_dpad_uses_existing_mapping"] = false
	current().focusables[0].grab_focus()
	# Two simultaneous confirmations may open only one session. Release before play.
	action("menu_confirm",true)
	action("menu_confirm",true)
	await frames(5)
	checks["new_game_waits_for_confirm_release"] = tree.paused and menus._transitioning
	action("menu_confirm",false)
	await physics(15)
	checks["new_game_loads_integrated_level"] = current().scene_file_path == menus.LEVEL
	var p: CharacterBody3D = current().get_node("Player")
	checks["new_game_vitals_estus"] = p.attributes.current_health == 100 and p.attributes.current_stamina == 100 and p.estus_controller.current_charges == 5
	checks["new_game_initial_checkpoint"] = current().get_node("CheckpointManager").active_id == &"forest_start"
	checks["bootstrap_does_not_fake_bonfire_tutorial"] = not current().get_node("TutorialController").is_completed(&"bonfire")
	checks["single_player_after_double_confirm"] = current().find_children("Player","CharacterBody3D",true,false).size() == 1
	checks["fresh_actions_and_critical_reservations"] = p.action_states.current_state == 0 and not p.attack_controller.has_buffered_attack() and not p.critical_vulnerability.is_reserved()
	Input.action_press("move_forward")
	await physics(52)
	Input.action_release("move_forward")
	await physics(10)
	var tutorial: Node = current().get_node("TutorialController")
	checks["tutorial_completes_real_move_before_pause"] = tutorial.is_completed(&"move")
	checks["attack_before_pause_starts"] = p.attack_controller.request_attack(2)
	await physics(8)
	var saved: Dictionary = {"position":p.position,"clock":p.attack_controller.elapsed,"ai":current().get_node("Soldier1").brain.decision_remaining,"stamina":p.attributes.current_stamina,"tutorial":tutorial.completed.duplicate(),"panel_alpha":current().get_node("HUD/TutorialPanel").modulate.a}
	await tap("pause_game")
	checks["esc_pauses_scene_tree"] = tree.paused and menus.screen == menus.Screen.PAUSE
	checks["pause_focus_continue"] = tree.root.gui_get_focus_owner().name == "resume"
	await tree.create_timer(0.3,true).timeout
	checks["pause_freezes_movement"] = p.position == saved.position
	checks["pause_freezes_attack_clock"] = p.attack_controller.elapsed == saved.clock
	checks["pause_freezes_ai"] = current().get_node("Soldier1").brain.decision_remaining == saved.ai
	checks["pause_freezes_attributes"] = p.attributes.current_stamina == saved.stamina
	checks["pause_freezes_tutorial"] = tutorial.completed == saved.tutorial and current().get_node("HUD/TutorialPanel").modulate.a == saved.panel_alpha
	menus.open_options()
	menus.options.set_value("horizontal",205.0)
	menus.options.set_value("vertical",145.0)
	menus.options.set_value("invert_y",true)
	var rig: Node = current().get_node("CameraRig")
	checks["camera_sensitivity_applied"] = rig.horizontal_sensitivity == 205 and rig.vertical_sensitivity == 145
	checks["camera_inversion_applied"] = rig.invert_vertical
	checks["options_during_pause_keep_world_frozen"] = tree.paused and p.attack_controller.elapsed == saved.clock
	menus.close_options()
	checks["options_return_keeps_pause"] = menus.screen == menus.Screen.PAUSE and tree.paused
	await tap("menu_cancel")
	await physics(5)
	checks["continue_restores_simulation"] = not tree.paused and p.attack_controller.elapsed > saved.clock
	checks["continue_preserves_tutorial"] = tutorial.completed == saved.tutorial
	checks["cancel_does_not_roll_after_resume"] = not p.dodge_controller.is_active()
	await physics(100)
	p.attributes.apply_damage(40)
	checks["healing_before_pause_starts"] = p.estus_controller.try_use()
	await physics(12)
	menus.open_pause()
	var healing_clock: float = p.estus_controller.elapsed
	await tree.create_timer(0.25,true).timeout
	checks["pause_freezes_healing_and_charge_use"] = p.estus_controller.elapsed == healing_clock and p.estus_controller.current_charges == 5 and p.attributes.current_health == 60
	menus.request_resume()
	await physics(100)
	checks["healing_finishes_once_after_continue"] = p.estus_controller.current_charges == 4 and p.attributes.current_health == 100
	menus.open_pause()
	menus.show_restart_confirmation()
	checks["restart_requires_confirmation"] = menus.screen == menus.Screen.CONFIRM_RESTART and tree.root.gui_get_focus_owner().name == "restart_no"
	var old_id: int = p.get_instance_id()
	menus.cancel()
	checks["cancel_restart_preserves_session_and_focus"] = current().get_node("Player").get_instance_id() == old_id and tree.root.gui_get_focus_owner().name == "restart"
	menus.show_restart_confirmation()
	menus.menu.focusables[1].pressed.emit()
	await frames(8)
	await physics(15)
	p = current().get_node("Player")
	checks["confirmed_restart_replaces_scene_once"] = p.get_instance_id() != old_id and current().find_children("Player","CharacterBody3D",true,false).size() == 1
	checks["restart_resets_tutorial"] = current().get_node("TutorialController").completed.is_empty()
	checks["restart_keeps_options"] = current().get_node("CameraRig").horizontal_sensitivity == 205 and current().get_node("CameraRig").invert_vertical
	checks["restart_resets_vitals_estus_grip"] = p.attributes.current_health == 100 and p.estus_controller.current_charges == 5 and p.grip_controller.shield_available()
	checks["restart_restores_enemies"] = current().get_node("Soldier1").attributes.current_health == 180 and current().get_node("Soldier2").attributes.current_health == 180
	checks["restart_clean_offense"] = not p.attack_controller.hitbox.is_active() and not p.riposte_controller.is_active() and not current().get_node("Soldier1").critical_vulnerability.is_reserved()
	# Real damage resolution invokes the production death/victory signal chain.
	var boss: Node = current().get_node("Boss")
	boss.hurtbox.receive_hit(p,&"player",10000,9501)
	await frames(5)
	checks["victory_screen_and_pause"] = menus.screen == menus.Screen.VICTORY and tree.paused
	checks["victory_focus_new_game"] = tree.root.gui_get_focus_owner().name == "new_game"
	checks["dead_boss_cannot_attack"] = boss.attributes.current_health == 0 and not boss.attack_controller.hitbox.is_active() and not boss.brain.is_physics_processing()
	menus.menu.focusables[0].pressed.emit()
	await frames(8)
	await physics(15)
	checks["new_after_victory_restores_boss"] = current().get_node("Boss").attributes.current_health == 600 and not current().get_node("Boss").brain.phase_two and not current().get_node("Boss").boss_defeated_this_session
	checks["new_after_victory_clears_metadata"] = not load("res://scripts/systems/session_progress.gd").boss_is_defeated(tree,&"ruins_guardian") and current().get_node("TutorialController").completed.is_empty()
	menus.open_pause()
	await menus.return_to_main()
	await frames(3)
	checks["return_to_main_unpauses_and_focuses"] = not tree.paused and current().scene_file_path == menus.MAIN_MENU and tree.root.gui_get_focus_owner().name == "new_game"
	checks["main_has_no_live_world"] = tree.get_nodes_in_group("checkpoint_enemies").is_empty() and not current().has_node("Player")
	await new_session()
	checks["repeated_new_game_no_duplicates"] = tree.get_nodes_in_group("checkpoint_enemies").size() == 3 and current().find_children("Player","CharacterBody3D",true,false).size() == 1
	# Reserve a normal target, then restart. The new actor must never retain it.
	var soldier: Node = current().get_node("Soldier1")
	checks["critical_fixture_reserves_real_component"] = soldier.critical_vulnerability.reserve_backstab(current().get_node("Player"))
	await new_session()
	checks["new_session_discards_old_critical_reservations"] = not current().get_node("Soldier1").critical_vulnerability.is_reserved() and not current().get_node("Player").critical_vulnerability.is_reserved()
	checks["options_still_independent_of_session_reset"] = menus.options.values.horizontal == 205 and current().get_node("CameraRig").horizontal_sensitivity == 205
	checks["f6_scene_kept"] = ResourceLoader.exists("res://scenes/levels/ruins_boss_arena.tscn")
	await menus.return_to_main()
	await frames(3)
	# Space is Godot's existing ui_accept and also a gameplay dodge binding.
	# It must be owned by the menu, with the same release barrier as Enter/A.
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await frames(5)
	checks["space_confirm_waits_release_before_play"] = tree.paused and menus._transitioning
	space = space.duplicate()
	space.pressed = false
	Input.parse_input_event(space)
	await physics(15)
	checks["space_confirm_does_not_trigger_dodge"] = not current().get_node("Player").dodge_controller.is_active() and current().get_node("Player").action_states.current_state == 0
	measures["main_menu_rect"] = "1280x720 base; layouts verified by screenshots"
	measures["audio_playback"] = "No audio streams; bus values verified numerically only"
	await menus.return_to_main()
