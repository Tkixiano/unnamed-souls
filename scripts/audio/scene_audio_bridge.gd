extends Node
## Signal adapter, owned by the scene. No actor/AI/attribute mutation.
const Actions = preload("res://scripts/player/action_state.gd")
@export_range(0.1,1,0.01) var walk_step_seconds: float = 0.5
@export_range(0.1,1,0.01) var run_step_seconds: float = 0.32
var director: Node
var scene: Node
var player: CharacterBody3D
var boss: CharacterBody3D
var step_timer: Timer
var _serial: int = 0
var _grip: int = 0
var _fire_loops: Dictionary = {}
var _lit: Dictionary = {}
var _configured: bool = false

func event(id: StringName, source: Node, token: Variant = null, at: Variant = null) -> void:
	_serial += 1
	director.play_event(id,source,_serial if token == null else token,at)

func configure(root: Node, audio: Node) -> void:
	if _configured: return
	_configured = true
	scene = root
	director = audio
	player = scene.get_node_or_null("Player")
	boss = scene.get_node_or_null("Boss")
	if player == null:
		if scene.scene_file_path in ["res://scenes/ui/main_menu.tscn","res://scenes/ui/arena_selector.tscn"]: director.request_music(&"music_menu")
		else: director.music.stop()
		return
	if boss != null and boss.boss_defeated_this_session: director.request_music(&"music_victory")
	else: director.request_music(&"music_level")
	for actor in scene.find_children("*","CharacterBody3D",true,false):
		if actor.has_node("Attributes") and actor.has_node("AttackController"): _bind_actor(actor)
	player.locomotion_state_changed.connect(_on_locomotion)
	step_timer = Timer.new()
	step_timer.name = "FootstepCadence"
	step_timer.process_callback = Timer.TIMER_PROCESS_PHYSICS
	add_child(step_timer)
	step_timer.timeout.connect(emit_footstep)
	player.dodge_controller.dodge_started.connect(func(_profile, _direction, backstep): event(&"player_backstep" if backstep else &"player_roll",player))
	player.defense_controller.defense_event.connect(_on_defense)
	player.estus_controller.used.connect(func(_healed): event(&"player_estus",player))
	_grip = player.grip_controller.mode
	player.grip_controller.mode_changed.connect(_on_grip)
	player.riposte_controller.riposte_event.connect(_on_critical)
	var checkpoints: Node = scene.get_node_or_null("CheckpointManager")
	if checkpoints != null:
		checkpoints.checkpoint_activated.connect(_on_fire_activated)
		checkpoints.rested.connect(func(id):
			var fire: Node = _find_fire(id)
			if fire != null: event(&"bonfire_rest",fire))
		checkpoints.respawned.connect(func(_id):
			director.stop_effects()
			director.request_music(&"music_level"))
	for fire in get_tree().get_nodes_in_group("bonfires"):
		if not scene.is_ancestor_of(fire): continue
		_lit[fire.get_instance_id()] = fire.lit
		if fire.lit: _start_fire_loop(fire)
	if scene.has_node("Forest"):
		director.start_ambient(&"ambient_forest",self)
		director.start_ambient(&"ambient_wind",self)
		# Selected ruin sector audited in 4A; relative to the retained Forest node.
		director.start_ambient(&"ambient_ruins",self,scene.get_node("Forest").to_global(Vector3(20,1,-20)))
	if scene.has_node("ArenaArt") and boss != null:
		director.start_ambient(&"ambient_ruins",self,boss.brain.arena_center+Vector3.UP)
	if boss != null:
		boss.brain.encounter_started.connect(func():
			event(&"boss_encounter",boss)
			director.request_music(&"music_boss_1"))
		boss.brain.encounter_ended.connect(func(reason):
			if reason != &"defeated" and player.attributes.current_health > 0: director.request_music(&"music_level"))
		boss.brain.phase_changed.connect(func(phase):
			if phase == 2 and boss.brain.encounter_active: director.request_music(&"music_boss_2"))
		boss.brain.state_changed.connect(func(_previous, state):
			if state == boss.brain.State.PHASE_TRANSITION: event(&"boss_phase_transition",boss))
		boss.brain.pattern_started.connect(func(id):
			if id == &"RUIN_BURST": event(&"boss_special_warning",boss))
		boss.brain.victory.connect(func():
			event(&"boss_victory",boss)
			director.request_music(&"music_victory"))

func _bind_actor(actor: CharacterBody3D) -> void:
	var kind: String = "player" if actor == player else "boss" if actor == boss else "enemy"
	actor.attack_controller.phase_changed.connect(func(phase):
		if phase != 2: return
		var cue: StringName = StringName(kind+"_attack")
		if actor == player: cue = &"player_heavy" if "HEAVY" in str(actor.attack_controller.current_attack_name()) else &"player_light"
		elif actor == boss and boss.brain.current_pattern == &"RUIN_BURST": cue = &"boss_special_impact"
		event(cue,actor,"swing:"+str(actor.attack_controller.swing_id)))
	actor.attack_controller.hitbox.hit_confirmed.connect(func(target, _damage, swing):
		event(&"sword_hit",actor,"hit:"+str(swing)+":"+str(target.get_instance_id()),target.global_position))
	actor.get_node("Hurtbox").damage_received.connect(func(_amount, _attacker, _swing):
		if actor.attributes.current_health > 0: event(StringName(kind+"_hurt"),actor))
	actor.attributes.died.connect(func():
		event(StringName(kind+"_death"),actor)
		if actor == player:
			step_timer.stop()
			director.music.stop())
	actor.attributes.fully_restored.connect(func(): director.forget_source(actor))
	if actor != player:
		actor.action_states.state_changed.connect(func(_previous, state):
			if state == Actions.State.STAGGERED: event(StringName(kind+"_stagger"),actor))
		var brain: Node = actor.get_node_or_null("SoldierAI")
		# Boss fixtures can reuse this node name with a different state enum.
		if brain != null and brain.get_script() == preload("res://scripts/enemies/soldier_ai.gd"):
			brain.state_changed.connect(func(_previous, state):
				if state == brain.State.ALERT: event(&"enemy_alert",actor))

func _on_locomotion(state: int) -> void:
	if not director.approximate_footsteps or state == 0:
		step_timer.stop()
		return
	step_timer.start(run_step_seconds if state == 2 else walk_step_seconds)

func emit_footstep() -> void:
	# Temporary cadence/contact hook; future animation events can call this.
	# No polling in _process/_physics_process and no airborne/blocked steps.
	if not player.can_move() or player.attributes.current_health <= 0 or not player.is_on_floor() or player.horizontal_speed < 0.1: return
	event(&"player_run_step" if player.locomotion_state == 2 else &"player_step",player)

func _on_defense(name: StringName) -> void:
	var ids: Dictionary = {&"blocked":&"player_block", &"parry_success":&"player_parry", &"guard_break":&"player_guard_break"}
	if ids.has(name): event(ids[name],player)
func _on_critical(name: StringName) -> void:
	if name == &"riposte_started": event(&"player_riposte",player)
	elif name == &"backstab_started": event(&"player_backstab",player)
	elif name in [&"riposte_hit",&"backstab_hit"]: event(&"sword_hit",player)
func _on_grip(mode: int) -> void:
	if mode != _grip and player.grip_controller.is_switching(): event(&"player_grip",player)
	_grip = mode
func _find_fire(id: StringName) -> Node:
	for fire in get_tree().get_nodes_in_group("bonfires"):
		if scene.is_ancestor_of(fire) and fire.bonfire_id == id: return fire
	return null
func _start_fire_loop(fire: Node3D) -> void:
	var key: int = fire.get_instance_id()
	if _fire_loops.has(key): return
	# Ownership remains within this bridge; unloading it clears every ambient loop.
	var voice: Node = director.start_ambient(&"ambient_bonfire",self,fire.global_position+Vector3.UP*0.3)
	if voice != null: _fire_loops[key] = voice
func _on_fire_activated(id: StringName) -> void:
	var fire: Node3D = _find_fire(id)
	if fire == null: return
	var key: int = fire.get_instance_id()
	if not _lit.get(key,false): event(&"bonfire_light",fire)
	_lit[key] = true
	_start_fire_loop(fire)
