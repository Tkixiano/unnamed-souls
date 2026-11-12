extends RefCounted
## Full-health production actors, autonomous boss and checkpoint sequence.
var tree: SceneTree
func step(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func start(t: SceneTree) -> void:
	tree = t
	var scene: Node3D = tree.current_scene
	var p: CharacterBody3D = scene.get_node("Player")
	var boss: CharacterBody3D = scene.get_node("Boss")
	var manager: Node = scene.get_node("CheckpointManager")
	var gate: Node3D = scene.get_node("GateBonfire")
	var checks: Dictionary = {}
	tree.root.set_meta("phase4b_retry",{"status":"running","checks":checks})
	# One initial placement isolates the gate/retry section, not the death/return.
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,Vector3(0.8,0.1,-32)),true)
	await step(8)
	checks["gate_rest_at_normal_attributes"] = manager.rest_at(gate) and p.attributes.max_health == 100
	Input.action_press("move_forward")
	await step(260)
	Input.action_release("move_forward")
	await step(8)
	checks["first_attempt_walks_into_encounter"] = boss.brain.encounter_active
	for frame in range(1800):
		if p.attributes.current_health <= 0: break
		await tree.physics_frame
	checks["autonomous_boss_kills_normal_health_player"] = p.attributes.current_health == 0 and p.action_states.current_state == 7
	await step(170)
	checks["respawn_retains_gate_id"] = manager.active_id == &"forest_gate" and p.position.distance_to(gate.get_spawn_transform().origin) < 0.2
	checks["respawn_restores_normal_vitals"] = p.attributes.current_health == 100 and p.estus_controller.current_charges == 5 and p.action_states.current_state == 0
	checks["boss_reset_clean"] = boss.attributes.current_health == 600 and not boss.brain.phase_two and not boss.attack_controller.hitbox.is_active() and boss.brain.enabled
	var player_id: int = p.get_instance_id()
	var boss_id: int = boss.get_instance_id()
	Input.action_press("move_forward")
	await step(210)
	Input.action_release("move_forward")
	await step(8)
	checks["second_attempt_walks_into_encounter"] = boss.brain.encounter_active and scene.get_node("HUD/BossHUD").panel.visible
	checks["retry_same_actor_instances"] = p.get_instance_id() == player_id and boss.get_instance_id() == boss_id
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"player_position":str(p.position),"scope":"One initial gate placement; real walks, autonomous death and automatic respawn. No expanded health or disabled components."}
	FileAccess.open("res://tests/phase_4b_retry.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("phase4b_retry",result)
