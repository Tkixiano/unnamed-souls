extends RefCounted
func step(tree: SceneTree,n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func start(tree: SceneTree) -> void:
	var s: Node3D = tree.current_scene
	var p: CharacterBody3D = s.get_node("Player")
	var tutorial: Node = s.get_node("TutorialController")
	var checks: Dictionary = {}
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,Vector3(2.5,0.1,14)),true)
	s.get_node("CameraRig").set_orbit_angles(0,deg_to_rad(-18))
	s.get_node("CameraRig").snap_to_target()
	await step(tree,12)
	checks["visible_target_context_available"] = tutorial._context_valid("target")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,3,0.15)
	shape.shape = box
	wall.add_child(shape)
	s.add_child(wall)
	wall.position = Vector3(2.5,1,13)
	await step(tree,3)
	checks["wall_hides_lock_lesson_context"] = not tutorial._context_valid("target")
	checks["wall_hides_combat_lesson_context"] = not tutorial._context_valid("combat")
	wall.queue_free()
	await step(tree,3)
	checks["context_recovers_after_occlusion"] = tutorial._context_valid("target")
	for lesson in tutorial.catalog.lessons: tutorial.completed[lesson.id] = true
	tutorial.completed.erase(&"block")
	tutorial.skipped.erase(&"block")
	checks["grip_switch_real_request"] = p.grip_controller.try_toggle()
	await step(tree,30)
	tutorial.refresh()
	checks["two_hand_shield_instruction_actionable"] = tutorial.current_id == &"block" and s.get_node("HUD/TutorialPanel/Margin/Rows/Text").text.contains("Volvé a una mano")
	var panel: Control = s.get_node("HUD/TutorialPanel")
	await step(tree,3)
	checks["two_hand_panel_fits"] = panel.get_global_rect().end.y <= 535
	# Actual UI signal wiring, not a direct call to the controller's skip method.
	panel.get_node("Margin/Rows/Footer/Skip").pressed.emit()
	checks["skip_button_wiring"] = tutorial.is_skipped(&"block")
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,Vector3(0.8,0.1,-32)),true)
	await step(tree,12)
	checks["live_boss_gate_context"] = tutorial._context_valid("gate")
	s.get_node("Boss").attributes.apply_damage(10000)
	await step(tree,3)
	checks["defeated_boss_not_advertised_as_new_encounter"] = not tutorial._context_valid("gate")
	var failed: Array = []
	for k in checks:
		if not checks[k]: failed.append(k)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks}
	FileAccess.open("res://tests/phase_5a_context_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("phase5a_context_result",result)
