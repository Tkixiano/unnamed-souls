extends RefCounted
var tree: SceneTree
var scene: Node3D
var p: CharacterBody3D
var tutorial: Node
var checks: Dictionary = {}
var measures: Dictionary = {}
var shown: Array = []
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func place(at: Vector3) -> void:
	for action in ["move_forward","move_backward","move_left","move_right","camera_right","block","sprint_dodge"]: Input.action_release(action)
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,at),true)
	scene.get_node("LockOnController").release_lock(&"fixture")
	scene.get_node("CameraRig").set_orbit_angles(0,deg_to_rad(-18))
	scene.get_node("CameraRig").snap_to_target()
func start(t: SceneTree) -> void:
	tree = t
	tree.root.set_meta("phase5a_result",{"status":"running","checks":checks})
	await run()
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measures,"physical_devices":Input.get_connected_joypads()}
	tree.root.set_meta("phase5a_result",result)
	FileAccess.open("res://tests/phase_5a_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
func run() -> void:
	scene = tree.current_scene
	p = scene.get_node("Player")
	tutorial = scene.get_node("TutorialController")
	tutorial.instruction_changed.connect(func(id, _title, _text, _profile): shown.append(str(id)))
	await step(8)
	checks["ten_editable_lessons"] = tutorial.catalog.lessons.size() == 10
	var ids: Array = []
	for lesson in tutorial.catalog.lessons: ids.append(str(lesson.id))
	checks["requested_order"] = ids == ["move","camera","bonfire","lock","light","heavy","block","dodge","estus","entry"]
	checks["initial_movement_context"] = tutorial.current_id == &"move"
	await step(65)
	checks["idle_does_not_complete_by_time"] = tutorial.completed.is_empty()
	checks["early_light_request_accepted"] = p.attack_controller.request_attack(0)
	await step(52)
	checks["early_action_recorded_before_explanation"] = tutorial.is_completed(&"light") and tutorial.current_id == &"move"
	Input.action_press("move_forward")
	await step(52)
	Input.action_release("move_forward")
	await step(8)
	checks["actual_movement_completes"] = tutorial.is_completed(&"move")
	checks["camera_follows_movement_in_order"] = tutorial.current_id == &"camera"
	Input.action_press("camera_right")
	await step(16)
	Input.action_release("camera_right")
	await step(4)
	checks["actual_camera_rotation_completes"] = tutorial.is_completed(&"camera")
	checks["absent_bonfire_context_not_forced"] = tutorial.current_id != &"bonfire"
	place(Vector3(1,0.1,20))
	await step(8)
	checks["bonfire_prompt_when_near"] = tutorial.current_id == &"bonfire"
	checks["rest_real_checkpoint"] = scene.get_node("CheckpointManager").rest_at(scene.get_node("Bonfire"))
	await step(8)
	checks["checkpoint_event_completes_lesson"] = tutorial.is_completed(&"bonfire")
	place(Vector3(2.5,0.1,14))
	await step(8)
	checks["lock_context_before_attacks"] = tutorial.current_id == &"lock"
	checks["real_lock_acquisition"] = scene.get_node("LockOnController").try_acquire()
	await step(3)
	checks["lock_event_completes"] = tutorial.is_completed(&"lock")
	checks["early_light_not_repeated"] = tutorial.current_id == &"heavy"
	checks["heavy_request_accepted"] = p.attack_controller.request_attack(2)
	await step(90)
	checks["heavy_event_completes"] = tutorial.is_completed(&"heavy")
	checks["block_instruction_follows"] = tutorial.current_id == &"block"
	Input.action_press("block")
	await step(5)
	checks["real_shield_raised_completes"] = p.defense_controller.is_blocking() and tutorial.is_completed(&"block")
	Input.action_release("block")
	await step(5)
	checks["backstep_starts"] = p.dodge_controller.try_dodge(Vector2.ZERO)
	await step(45)
	checks["backstep_not_misreported_as_roll"] = not tutorial.is_completed(&"dodge")
	checks["directional_roll_starts"] = p.dodge_controller.try_dodge(Vector2.LEFT)
	await step(45)
	checks["roll_signal_completes"] = tutorial.is_completed(&"dodge")
	place(Vector3(0,0.1,18))
	await step(8)
	checks["full_health_hides_estus_instruction"] = tutorial.current_id != &"estus" and not p.estus_controller.try_use()
	checks["rejected_estus_not_completed"] = not tutorial.is_completed(&"estus")
	p.attributes.apply_damage(40)
	await step(3)
	checks["wounded_estus_context"] = tutorial.current_id == &"estus"
	checks["real_estus_starts"] = p.estus_controller.try_use()
	await step(40)
	checks["preparation_does_not_complete_estus"] = not tutorial.is_completed(&"estus")
	await step(20)
	checks["actual_delayed_healing_completes_estus"] = tutorial.is_completed(&"estus") and p.attributes.current_health == 100 and p.estus_controller.current_charges == 4
	await step(35)
	checks["gate_instruction_not_shown_far_away"] = tutorial.current_id != &"entry"
	var snapshot: Dictionary = tutorial.completed.duplicate()
	p.attributes.apply_damage(10000)
	await step(5)
	checks["tutorial_hidden_during_death"] = tutorial.current_id.is_empty()
	await step(165)
	checks["real_respawn_keeps_completions"] = tutorial.completed == snapshot and p.attributes.current_health == 100
	checks["no_pending_lesson_forces_combat_state"] = p.action_states.current_state == 0 and p.can_move()
	# UI/layout and mapping tests use synthetic metadata; no physical pad claim.
	var Hints = load("res://scripts/systems/tutorial_input_hints.gd")
	checks["xbox_mapping_metadata"] = Hints.profile_for_device("Xbox Controller",true,0x045e) == "xbox"
	checks["playstation_mapping_metadata"] = Hints.profile_for_device("DualSense",true,0x054c) == "playstation"
	checks["unknown_mapped_is_neutral"] = Hints.profile_for_device("Generic USB",true,0) == "generic"
	checks["unmapped_even_named_xbox_is_neutral"] = Hints.profile_for_device("Xbox",false,0) == "generic"
	checks["physical_equivalent_labels"] = Hints.labels("xbox").dodge.contains("B") and Hints.labels("playstation").dodge.contains("Círculo") and Hints.labels("keyboard").dodge.contains("Espacio")
	var event := InputEventJoypadMotion.new()
	event.device = 999
	event.axis_value = 0.1
	tutorial._input(event)
	checks["small_stick_drift_does_not_change_profile"] = tutorial.profile == "keyboard"
	event.axis_value = 0.8
	tutorial._input(event)
	checks["unknown_simulated_pad_uses_neutral"] = tutorial.profile == "generic"
	tutorial._on_devices_changed()
	checks["disconnect_falls_back_keyboard"] = tutorial.profile == "keyboard"
	var key := InputEventKey.new()
	key.keycode = KEY_W
	key.pressed = true
	tutorial._input(key)
	checks["keyboard_event_selects_keyboard_hints"] = tutorial.profile == "keyboard"
	var panel: Control = scene.get_node("HUD/TutorialPanel")
	var layout: Array = []
	var layouts_valid: bool = true
	for profile in ["keyboard","xbox","playstation","generic"]:
		for lesson in tutorial.catalog.lessons:
			panel._on_instruction(lesson.id,lesson.title,lesson.text.format(Hints.labels(profile)),profile)
			await tree.process_frame
			await tree.process_frame
			var rect: Rect2 = panel.get_global_rect()
			layouts_valid = layouts_valid and Rect2(0,0,1280,720).encloses(rect) and rect.position.y >= 280 and rect.end.y <= 535
			layout.append({"id":lesson.id,"profile":profile,"rect":str(rect)})
	checks["all_40_panel_layouts_fit_and_avoid_bars"] = layouts_valid
	measures["layouts"] = layout
	tutorial._view_key = ""
	tutorial.refresh()
	# Leave earlier lessons intentionally pending: entry remains optional and ungated.
	tutorial.completed.erase(&"block")
	tutorial._save()
	place(Vector3(0.8,0.1,-32))
	await step(8)
	checks["gate_context_without_nearby_targets"] = tutorial.current_id == &"entry"
	var skipped: StringName = tutorial.current_id
	checks["skip_current_supported"] = tutorial.skip_current()
	checks["skip_is_not_claimed_as_action_completion"] = tutorial.is_skipped(skipped) and not tutorial.is_completed(skipped)
	scene.get_node("CheckpointManager").rest_at(scene.get_node("GateBonfire"))
	await step(8)
	Input.action_press("move_forward")
	await step(215)
	Input.action_release("move_forward")
	await step(8)
	checks["walk_to_boss_with_pending_lessons"] = scene.get_node("Boss").brain.encounter_active and not tutorial.is_completed(&"block")
	checks["entry_real_encounter_event_completes"] = tutorial.is_completed(&"entry")
	checks["panel_hides_for_boss_hud"] = tutorial.current_id.is_empty()
	var saved_completed: Dictionary = tutorial.completed.duplicate()
	var saved_skipped: Dictionary = tutorial.skipped.duplicate()
	tree.change_scene_to_file("res://scenes/ui/arena_selector.tscn")
	await tree.scene_changed
	await step(3)
	tree.current_scene.buttons[0].pressed.emit()
	await tree.scene_changed
	await step(8)
	tutorial = tree.current_scene.get_node("TutorialController")
	checks["menu_reload_preserves_session_progress"] = tutorial.completed == saved_completed and tutorial.skipped == saved_skipped
	checks["no_tutorial_autoload_or_disk_save"] = not ProjectSettings.has_setting("autoload/Tutorial")
	measures["shown_instruction_ids"] = shown
