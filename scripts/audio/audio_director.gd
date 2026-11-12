extends Node
## Sole playback service. Scene bridge observes gameplay; no gameplay writes.
const Routing = preload("res://scripts/audio/audio_routing.gd")
const Music = preload("res://scripts/audio/music_controller.gd")
const Bridge = preload("res://scripts/audio/scene_audio_bridge.gd")
@export var catalog: Resource
@export_range(1,12,1) var spatial_voices: int = 8
@export_range(1,6,1) var global_voices: int = 2
@export var approximate_footsteps: bool = true
signal cue_requested(id: StringName, source: Node)
signal cue_played(id: StringName)
var music: Node
var bridge: Node
var requested_counts: Dictionary = {}
var played_counts: Dictionary = {}
var dropped_voices: int = 0
var _spatial: Array[AudioStreamPlayer3D] = []
var _global: Array[AudioStreamPlayer] = []
var _recent: Array[String] = []
var _scene: Node

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Routing.ensure_buses()
	music = Music.new()
	music.name = "MusicController"
	add_child(music)
	for i in range(spatial_voices):
		var voice := AudioStreamPlayer3D.new()
		voice.name = "SFX3D"+str(i)
		voice.bus = &"SFX"
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_spatial.append(voice)
	for i in range(global_voices):
		var voice := AudioStreamPlayer.new()
		voice.name = "SFX2D"+str(i)
		voice.bus = &"SFX"
		voice.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(voice)
		_global.append(voice)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()

func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == null or scene == _scene: return
	_scene = scene
	stop_effects()
	_recent.clear()
	bridge = Bridge.new()
	bridge.name = "SceneAudioBridge"
	bridge.process_mode = Node.PROCESS_MODE_PAUSABLE
	scene.add_child(bridge)
	bridge.configure(scene,self)

func request_music(id: StringName) -> bool:
	return music.request(catalog.find(id) if catalog != null else null)

func play_event(id: StringName, source: Node, token: Variant = null, at: Variant = null) -> bool:
	var cue: Resource = catalog.find(id) if catalog != null else null
	if cue == null or (get_tree().paused and not cue.play_when_paused): return false
	if token != null:
		var key: String = str(source.get_instance_id() if is_instance_valid(source) else 0)+":"+str(id)+":"+str(token)
		if key in _recent: return false
		_recent.append(key)
		if _recent.size() > 128: _recent.pop_front()
	requested_counts[id] = int(requested_counts.get(id,0))+1
	cue_requested.emit(id,source)
	if cue.stream == null: return false
	var voice: Node
	var use_spatial: bool = cue.spatial and source is Node3D
	var pool: Array = _spatial if use_spatial else _global
	for candidate in pool:
		if not candidate.playing:
			voice = candidate
			break
	if voice == null:
		dropped_voices += 1
		return false # Bounded pool, no allocation or uncontrolled sound stealing.
	voice.process_mode = Node.PROCESS_MODE_ALWAYS if cue.play_when_paused else Node.PROCESS_MODE_PAUSABLE
	voice.stream = cue.playback_stream()
	voice.volume_db = cue.gain_db
	voice.pitch_scale = cue.pitch_scale
	if use_spatial:
		voice.global_position = at if at is Vector3 else source.global_position
		voice.max_distance = cue.max_distance
		voice.unit_size = cue.unit_size
	voice.play()
	played_counts[id] = int(played_counts.get(id,0))+1
	cue_played.emit(id)
	return true

func start_ambient(id: StringName, parent: Node, at: Variant = null) -> Node:
	var cue: Resource = catalog.find(id) if catalog != null else null
	if cue == null or cue.stream == null: return null
	var voice: Node = AudioStreamPlayer3D.new() if at is Vector3 else AudioStreamPlayer.new()
	voice.process_mode = Node.PROCESS_MODE_PAUSABLE
	parent.add_child(voice)
	voice.bus = &"Ambient"
	voice.stream = cue.playback_stream()
	voice.volume_db = cue.gain_db
	voice.pitch_scale = cue.pitch_scale
	if at is Vector3:
		voice.global_position = at
		voice.max_distance = cue.max_distance
		voice.unit_size = cue.unit_size
	voice.play()
	return voice

func forget_source(source: Node) -> void:
	var prefix: String = str(source.get_instance_id())+":"
	for i in range(_recent.size()-1,-1,-1):
		if _recent[i].begins_with(prefix): _recent.remove_at(i)

func stop_effects() -> void:
	for voice in _spatial: voice.stop()
	for voice in _global: voice.stop()
