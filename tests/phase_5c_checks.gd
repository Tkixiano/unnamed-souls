extends RefCounted
var tree: SceneTree
var audio: Node
var menus: Node
var checks: Dictionary = {}
var measurements: Dictionary = {}
var streams: Dictionary = {}
var saved_options: Dictionary
var blocks: int = 0
var parries: int = 0
var original_fade: float

func frames(n: int = 2) -> void:
	for i in range(n): await tree.process_frame
func physics(n: int) -> void:
	for i in range(n): await tree.physics_frame
	await tree.process_frame
func count(id: StringName) -> int:
	return int(audio.requested_counts.get(id,0))
func clip() -> AudioStreamWAV:
	# In-memory silent PCM fixture only. No file, artist asset or audible-quality claim.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	var pcm := PackedByteArray()
	pcm.resize(128000)
	pcm.fill(0)
	wav.data = pcm
	return wav
func assign(id: StringName, stream: AudioStream) -> void:
	audio.catalog.find(id).stream = stream
func place(at: Vector3, yaw: float = 0) -> CharacterBody3D:
	var scene: Node = tree.current_scene
	var p: CharacterBody3D = scene.get_node("Player")
	for action in ["move_forward","move_backward","move_left","move_right","block","sprint_dodge"]: Input.action_release(action)
	p.restore_at_checkpoint(Transform3D(Basis.IDENTITY,at),true)
	p.visual.rotation.y = yaw
	scene.get_node("LockOnController").release_lock(&"audio_fixture")
	scene.get_node("CameraRig").set_orbit_angles(yaw,deg_to_rad(-18))
	scene.get_node("CameraRig").snap_to_target()
	return p

func start(t: SceneTree) -> void:
	tree = t
	audio = tree.root.get_node("AudioDirector")
	menus = tree.root.get_node("GameMenus")
	tree.root.set_meta("phase5c_result",{"status":"running","checks":checks})
	saved_options = menus.options.values.duplicate()
	original_fade = audio.music.fade_seconds
	for cue in audio.catalog.cues: streams[cue.id] = cue.stream
	await backend()
	await gameplay()
	for cue in audio.catalog.cues: cue.stream = streams[cue.id]
	audio.music.stop(false)
	audio.music.fade_seconds = original_fade
	audio.stop_effects()
	await menus.return_to_main()
	await frames(3)
	for key in saved_options: menus.options.set_value(key,saved_options[key])
	var failed: Array = []
	for key in checks:
		if not checks[key]: failed.append(key)
	var result := {"status":"complete","passed":checks.size()-failed.size(),"total":checks.size(),"failed":failed,"checks":checks,"measurements":measurements,"physical_devices":Input.get_connected_joypads(),"available_artist_audio":0,"fixture":"Silent in-memory WAV only; no files or quality evaluation"}
	FileAccess.open("res://tests/phase_5c_results.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	tree.root.set_meta("phase5c_result",result)

func backend() -> void:
	await frames(4)
	var names: Array = []
	for i in range(AudioServer.bus_count): names.append(AudioServer.get_bus_name(i))
	checks["four_buses"] = names == ["Master","Music","SFX","Ambient"]
	for bus in ["Music","SFX","Ambient"]:
		checks["routing_"+bus] = AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == &"Master"
	checks["catalog_41_optional_cues"] = audio.catalog.cues.size() == 41 and audio.catalog.missing_ids().size() == 41
	checks["silent_menu_music_context"] = audio.music.current_id == &"music_menu" and not audio.music.voices[0].playing and not audio.music.voices[1].playing
	checks["bounded_initial_players"] = audio._spatial.size() == 8 and audio._global.size() == 2 and audio.music.voices.size() == 2
	checks["no_fake_asset_paths"] = audio.catalog.cues.all(func(c): return c.stream == null)
	for pair in [["master","Master",50.0],["music","Music",35.0],["effects","SFX",65.0],["ambient","Ambient",40.0]]:
		menus.options.set_value(pair[0],pair[2])
		checks["volume_"+pair[1]] = is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(pair[1]))),pair[2]/100.0)
	menus.options.set_value("ambient",0.0)
	checks["ambient_zero_mutes"] = AudioServer.is_bus_mute(AudioServer.get_bus_index("Ambient"))
	menus.options.set_value("ambient",40.0)
	menus.options.set_value("master",0.0)
	checks["master_zero_mutes_all_routing"] = AudioServer.is_bus_mute(0)
	var options: RefCounted = load("res://scripts/systems/game_options.gd").new()
	options.preferences_path = "user://phase_5c_preferences_fixture.cfg"
	var existed: bool = FileAccess.file_exists(options.preferences_path)
	var previous: PackedByteArray = FileAccess.get_file_as_bytes(options.preferences_path) if existed else PackedByteArray()
	options.values.ambient = 45.0
	checks["ambient_preference_saved"] = options.save_preferences() == OK
	var reread: RefCounted = load("res://scripts/systems/game_options.gd").new()
	reread.preferences_path = options.preferences_path
	reread.load_preferences()
	checks["ambient_preference_loaded"] = reread.values.ambient == 45.0
	if existed: FileAccess.open(options.preferences_path,FileAccess.WRITE).store_buffer(previous)
	else: DirAccess.remove_absolute(ProjectSettings.globalize_path(options.preferences_path))
	var a: AudioStreamWAV = clip()
	var b: AudioStreamWAV = clip()
	var c: AudioStreamWAV = clip()
	assign(&"music_menu",a)
	assign(&"music_level",a)
	assign(&"music_boss_1",b)
	assign(&"music_boss_2",c)
	assign(&"music_victory",a)
	audio.music.fade_seconds = 0.1
	checks["menu_music_with_memory_fixture"] = audio.request_music(&"music_menu")
	await physics(15)
	var plays: int = audio.music.play_count
	var active: int = audio.music._active
	var position: float = audio.music.voices[active].get_playback_position()
	checks["duplicate_track_does_not_restart"] = not audio.request_music(&"music_menu") and audio.music.play_count == plays
	await physics(6)
	checks["same_track_position_advances"] = audio.music.voices[active].get_playback_position() >= position
	checks["same_file_new_context_no_restart"] = not audio.request_music(&"music_level") and audio.music.play_count == plays
	checks["loop_copy_preserves_original"] = a.loop_mode == AudioStreamWAV.LOOP_DISABLED and audio.music.voices[active].stream.loop_mode == AudioStreamWAV.LOOP_FORWARD
	audio.request_music(&"music_victory")
	checks["same_file_loop_policy_updates_without_restart"] = audio.music.play_count == plays and audio.music.voices[active].stream.loop_mode == AudioStreamWAV.LOOP_DISABLED
	audio.request_music(&"music_level")
	await physics(6)
	tree.paused = true
	await frames(4)
	position = audio.music.voices[active].get_playback_position()
	await tree.create_timer(0.2,true).timeout
	checks["gameplay_music_pauses"] = audio.music.voices[active].stream_paused and is_equal_approx(audio.music.voices[active].get_playback_position(),position)
	audio.request_music(&"music_victory")
	await tree.create_timer(0.2,true).timeout
	checks["victory_music_allowed_while_paused"] = not audio.music.voices[active].stream_paused and audio.music.voices[active].get_playback_position() > position
	tree.paused = false
	audio.request_music(&"music_boss_1")
	await physics(3)
	audio.request_music(&"music_boss_2")
	await physics(15)
	checks["crossfade_settles_single_voice"] = audio.music.voices.filter(func(v): return v.playing).size() == 1 and audio.music.current_id == &"music_boss_2"
	checks["music_does_not_change_bus_volume"] = is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))),0.35)
	checks["unknown_music_key_is_safe"] = not audio.request_music(&"unknown") and audio.music.current_id == &"music_boss_2"
	assign(&"music_level",null)
	audio.request_music(&"music_level")
	await physics(15)
	checks["missing_next_track_fades_previous_out"] = audio.music.voices.all(func(v): return not v.playing)
	assign(&"music_level",a)
	var marker := Node3D.new()
	tree.current_scene.add_child(marker)
	marker.position = Vector3(1,2,3)
	var requests: int = count(&"player_block")
	audio.play_event(&"player_block",marker,"same_contact")
	audio.play_event(&"player_block",marker,"same_contact")
	checks["dedup_even_missing_resource"] = count(&"player_block") == requests+1
	audio.forget_source(marker)
	audio.play_event(&"player_block",marker,"same_contact")
	checks["actor_reset_can_reuse_event_token"] = count(&"player_block") == requests+2
	assign(&"sword_hit",a)
	for i in range(8): audio.play_event(&"sword_hit",marker,i)
	checks["spatial_pool_capacity"] = audio._spatial.filter(func(v): return v.playing).size() == 8
	checks["spatial_source_position"] = audio._spatial[0].global_position == marker.global_position
	checks["spatial_pool_overflow_drops_without_allocating"] = not audio.play_event(&"sword_hit",marker,99) and audio._spatial.size() == 8
	assign(&"boss_victory",a)
	audio.play_event(&"boss_victory",tree.current_scene,1)
	audio.play_event(&"boss_victory",tree.current_scene,2)
	checks["global_pool_capacity"] = audio._global.filter(func(v): return v.playing).size() == 2 and not audio.play_event(&"boss_victory",tree.current_scene,3)
	checks["effects_bus_assignment"] = audio._spatial.all(func(v): return v.bus == &"SFX") and audio._global.all(func(v): return v.bus == &"SFX")
	audio.stop_effects()
	checks["stop_effects_clears_voices"] = audio._spatial.all(func(v): return not v.playing) and audio._global.all(func(v): return not v.playing)
	assign(&"sword_hit",null)
	assign(&"boss_victory",null)
	marker.queue_free()
	for id in [&"ambient_forest",&"ambient_wind",&"ambient_ruins",&"ambient_bonfire"]: assign(id,a)
	measurements["synthetic_audio"] = "Silent PCM in memory, Master muted. Playback/loop/fade APIs tested; no artistic files or listening evaluation."

func gameplay() -> void:
	await menus.new_game()
	await physics(15)
	var scene: Node = tree.current_scene
	var p: CharacterBody3D = scene.get_node("Player")
	var bridge: Node = audio.bridge
	checks["level_music_context"] = audio.music.current_id == &"music_level"
	checks["scene_has_one_bridge"] = scene.find_children("SceneAudioBridge","Node",true,false).size() == 1
	audio._on_scene_changed()
	checks["rebinding_same_scene_idempotent"] = audio.bridge == bridge
	var ambience: Array = bridge.get_children().filter(func(v): return v is AudioStreamPlayer or v is AudioStreamPlayer3D)
	checks["forest_wind_two_ruin_sources"] = ambience.size() == 4
	checks["ambient_bus_and_loops"] = ambience.all(func(v): return v.bus == &"Ambient" and v.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD)
	Input.action_press("move_forward")
	await physics(20)
	assign(&"player_light",clip())
	checks["sfx_memory_pause_probe_started"] = audio.play_event(&"player_light",p,"pause_probe")
	var sfx: Node = audio._spatial.filter(func(v): return v.playing)[0]
	var before_steps: int = count(&"player_step")
	var left: float = bridge.step_timer.time_left
	menus.open_pause()
	await frames(4)
	var ambient_position: float = ambience[0].get_playback_position()
	var music_active: int = audio.music._active
	var music_position: float = audio.music.voices[music_active].get_playback_position()
	var sfx_position: float = sfx.get_playback_position()
	await tree.create_timer(0.25,true).timeout
	checks["pause_stops_cadence_and_ambient"] = bridge.step_timer.time_left == left and count(&"player_step") == before_steps and ambience[0].stream_paused and ambience[0].get_playback_position() == ambient_position
	checks["real_pause_stops_level_music"] = audio.music.voices[music_active].stream_paused and audio.music.voices[music_active].get_playback_position() == music_position
	# A 3D play requested just before pause may still await its first physics
	# update: stream_paused then remains false, but no playback has started.
	checks["real_pause_stops_sfx"] = not sfx.can_process() and sfx.get_playback_position() == sfx_position and (sfx.stream_paused or sfx_position == 0.0)
	measurements["sfx_pause"] = {"position_before":sfx_position,"position_after":sfx.get_playback_position(),"stream_paused":sfx.stream_paused,"can_process":sfx.can_process()}
	checks["paused_gameplay_sound_rejected"] = not audio.play_event(&"player_light",p,"paused_contact")
	menus.request_resume()
	await physics(60)
	checks["sfx_resumes_without_restart"] = not sfx.stream_paused and sfx.get_playback_position() > sfx_position
	audio.stop_effects()
	assign(&"player_light",null)
	Input.action_release("move_forward")
	await physics(15)
	checks["walking_steps_from_cadence"] = count(&"player_step") > before_steps
	before_steps = count(&"player_step")
	await physics(40)
	checks["idle_no_repeated_footsteps"] = bridge.step_timer.is_stopped() and count(&"player_step") == before_steps
	place(Vector3(0,0.1,18))
	await physics(12)
	Input.action_press("move_forward")
	Input.action_press("sprint_dodge")
	await physics(75)
	Input.action_release("sprint_dodge")
	Input.action_release("move_forward")
	await physics(15)
	checks["running_uses_own_steps"] = count(&"player_run_step") > 0
	place(Vector3(2.5,0.1,14))
	await physics(12)
	var light: int = count(&"player_light")
	var impact: int = count(&"sword_hit")
	checks["light_attack_accepted"] = p.attack_controller.request_attack(0)
	await physics(8)
	checks["no_swing_sound_in_startup"] = count(&"player_light") == light
	checks["second_simultaneous_attack_rejected"] = not p.attack_controller.request_attack(2)
	await physics(50)
	checks["one_light_sound_per_active_swing"] = count(&"player_light") == light+1
	checks["real_sword_contact_event"] = count(&"sword_hit") == impact+1
	var heavy: int = count(&"player_heavy")
	checks["heavy_attack_accepted"] = p.attack_controller.request_attack(2)
	await physics(95)
	checks["one_heavy_sound"] = count(&"player_heavy") == heavy+1
	var roll: int = count(&"player_roll")
	checks["real_roll_accepted"] = p.dodge_controller.try_dodge(Vector2.LEFT)
	await physics(45)
	checks["roll_event_once"] = count(&"player_roll") == roll+1
	var grip: int = count(&"player_grip")
	checks["real_grip_switch"] = p.grip_controller.try_toggle()
	await physics(30)
	checks["grip_event_once_on_commit"] = count(&"player_grip") == grip+1
	place(Vector3(1,0.1,20))
	await physics(12)
	checks["restore_does_not_fake_grip_sound"] = count(&"player_grip") == grip+1
	var fire: Node = scene.get_node("Bonfire")
	var light_fire: int = count(&"bonfire_light")
	var rests: int = count(&"bonfire_rest")
	checks["bonfire_real_rest"] = scene.get_node("CheckpointManager").rest_at(fire)
	await physics(4)
	checks["bonfire_light_once_and_loop"] = count(&"bonfire_light") == light_fire+1 and bridge._fire_loops.size() == 1
	checks["bonfire_repeat_rest"] = scene.get_node("CheckpointManager").rest_at(fire)
	await physics(4)
	checks["rest_no_duplicate_fire_loop"] = count(&"bonfire_rest") == rests+2 and count(&"bonfire_light") == light_fire+1 and bridge._fire_loops.size() == 1
	p.attributes.apply_damage(40)
	var estus: int = count(&"player_estus")
	checks["real_estus_use"] = p.estus_controller.try_use()
	await physics(40)
	checks["estus_sound_waits_for_use_instant"] = count(&"player_estus") == estus
	await physics(60)
	checks["estus_consumption_sound_once"] = count(&"player_estus") == estus+1
	var soldier: Node = scene.get_node("Soldier1")
	soldier.restore_at_checkpoint()
	place(soldier.position+Vector3(0,0,1.4))
	await physics(12)
	p.defense_controller.defense_event.connect(func(id):
		if id == &"blocked": blocks += 1
		if id == &"parry_success": parries += 1)
	var block: int = count(&"player_block")
	Input.action_press("block")
	await physics(180)
	Input.action_release("block")
	await physics(5)
	checks["real_block_audio_matches_contact_signals"] = blocks > 0 and count(&"player_block")-block == blocks
	checks["enemy_detection_attack_events"] = count(&"enemy_alert") > 0 and count(&"enemy_attack") > 0
	soldier.restore_at_checkpoint()
	place(soldier.position+Vector3(0,0,1.4))
	await physics(12)
	var parry: int = count(&"player_parry")
	checks["enemy_manual_attack_fixture"] = soldier.attack_controller.request_attack(0)
	await physics(24)
	checks["real_parry_starts"] = p.defense_controller.try_parry()
	await physics(15)
	checks["parry_audio_once_on_success"] = parries == 1 and count(&"player_parry") == parry+1
	await physics(45)
	var riposte: int = count(&"player_riposte")
	checks["real_riposte_starts"] = p.attack_controller.request_attack(0) and p.riposte_controller.is_active()
	await physics(75)
	checks["riposte_audio_once"] = count(&"player_riposte") == riposte+1
	checks["enemy_hurt_and_stagger_events"] = count(&"enemy_hurt") > 0 and count(&"enemy_stagger") > 0
	soldier.restore_at_checkpoint()
	place(soldier.position+Vector3(0,0,-1.2),PI)
	await physics(12)
	var backstab: int = count(&"player_backstab")
	checks["real_backstab_starts"] = p.attack_controller.request_attack(0) and p.riposte_controller.is_active()
	await physics(75)
	checks["backstab_audio_once"] = count(&"player_backstab") == backstab+1
	var hurt: int = count(&"player_hurt")
	p.get_node("Hurtbox").receive_hit(soldier,&"hostile",10,9101)
	checks["real_player_damage_sound"] = count(&"player_hurt") == hurt+1
	var death: int = count(&"player_death")
	p.get_node("Hurtbox").receive_hit(soldier,&"hostile",1000,9102)
	await physics(5)
	checks["death_sound_once_no_double_hurt"] = count(&"player_death") == death+1 and count(&"player_hurt") == hurt+1
	checks["death_stops_music_context"] = audio.music.current_id.is_empty()
	await physics(170)
	checks["respawn_returns_level_music"] = p.attributes.current_health == 100 and audio.music.current_id == &"music_level"
	var enemy_death: int = count(&"enemy_death")
	soldier.get_node("Hurtbox").receive_hit(p,&"player",1000,9103)
	checks["enemy_death_once"] = count(&"enemy_death") == enemy_death+1
	var boss: Node = scene.get_node("Boss")
	place(boss.position+Vector3(0,0,2.3))
	await physics(100)
	checks["real_encounter_starts"] = boss.brain.start_encounter()
	checks["boss_music_phase_one_and_event"] = audio.music.current_id == &"music_boss_1" and count(&"boss_encounter") == 1
	# Deterministic pattern request, keeping actor execution and audio live.
	boss.brain.enabled = false
	boss.brain.state = boss.brain.State.REPOSITION
	boss.brain.decision_remaining = 0
	var boss_swing: int = count(&"boss_attack")
	checks["normal_boss_pattern_requested"] = boss.brain.start_pattern(&"HORIZONTAL_SLASH")
	await physics(105)
	checks["normal_boss_attack_audio_once"] = count(&"boss_attack") == boss_swing+1
	boss.brain.enabled = true
	boss.attributes.apply_damage(300)
	for i in range(220):
		if boss.brain.phase_two: break
		await tree.physics_frame
	checks["real_phase_two_music"] = boss.brain.phase_two and audio.music.current_id == &"music_boss_2"
	checks["phase_transition_audio_once"] = count(&"boss_phase_transition") == 1
	# Pattern fixture isolates decisions only; actor timing, hitbox and bridge run.
	boss.brain.enabled = false
	boss.brain.state = boss.brain.State.REPOSITION
	boss.brain.decision_remaining = 0
	boss.brain._restart_delay = 0
	place(boss.position+Vector3(0,0,2.3))
	await physics(12)
	checks["special_pattern_request"] = boss.brain.start_pattern(&"RUIN_BURST")
	checks["special_warning_event"] = count(&"boss_special_warning") == 1
	await physics(115)
	checks["special_active_impact_event"] = count(&"boss_special_impact") == 1
	var previous_victory_requests: int = count(&"boss_victory")
	boss.get_node("Hurtbox").receive_hit(p,&"player",1000,9104)
	await frames(5)
	checks["boss_death_and_victory_events_once"] = count(&"boss_death") == 1 and count(&"boss_victory") == previous_victory_requests+1
	checks["real_victory_music_while_ui_paused"] = tree.paused and menus.screen == menus.Screen.VICTORY and audio.music.current_id == &"music_victory" and audio.music.process_mode == Node.PROCESS_MODE_ALWAYS
	measurements["requested_events"] = audio.requested_counts.duplicate()
	measurements["pool_nodes"] = audio._spatial.size()+audio._global.size()
	measurements["special_fixture"] = "Brain decisions suspended only for deterministic special request; real attack timing/hitbox and audio observer remain active."
