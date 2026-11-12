extends RefCounted
var checks: Dictionary = {}
func start(tree: SceneTree) -> void:
	var audio: Node = tree.root.get_node("AudioDirector")
	await tree.root.get_node("GameMenus").new_game()
	for i in range(15): await tree.physics_frame
	var p: CharacterBody3D = tree.current_scene.get_node("Player")
	p.dodge_controller.equipment_load_percent = 75.0
	checks["heavy_dodge_started"] = p.dodge_controller.try_dodge(Vector2(0,-1))
	for i in range(3): await tree.physics_frame
	checks["heavy_dodge_has_motion"] = p.dodge_controller.is_active() and p.horizontal_speed > 0.1
	var before: int = int(audio.requested_counts.get(&"player_step",0))
	audio.bridge.emit_footstep()
	checks["no_footstep_during_committed_dodge"] = int(audio.requested_counts.get(&"player_step",0)) == before
	for i in range(90): await tree.physics_frame
	checks["dodge_recovers_normally"] = not p.dodge_controller.is_active() and p.can_move()
	tree.change_scene_to_file("res://scenes/levels/test_arena.tscn")
	await tree.scene_changed
	for i in range(8): await tree.physics_frame
	checks["technical_attacker_without_ai_binds_safely"] = tree.current_scene.has_node("DefenseTestAttacker") and audio.bridge.scene == tree.current_scene
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks}
	FileAccess.open("res://tests/phase_5c_followup.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("phase5c_followup",result)
