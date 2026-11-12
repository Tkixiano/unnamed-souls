extends Node
## Two-voice crossfade; bus volume belongs exclusively to GameOptions.
signal track_changed(id: StringName, has_stream: bool)
@export_range(0,3,0.05) var fade_seconds: float = 0.6
var current_id: StringName = &""
var current_source: AudioStream
var voices: Array[AudioStreamPlayer] = []
var play_count: int = 0
var _active: int = -1
var _fade: Tween
var _current_cue: Resource

func _ready() -> void:
	for i in range(2):
		var voice := AudioStreamPlayer.new()
		voice.name = "MusicVoice"+str(i)
		voice.bus = &"Music"
		voice.volume_db = -80
		add_child(voice)
		voices.append(voice)

func request(cue: Resource) -> bool:
	if cue == null: return false
	if cue.id == current_id and cue.stream == current_source: return false
	process_mode = Node.PROCESS_MODE_ALWAYS if cue.play_when_paused else Node.PROCESS_MODE_PAUSABLE
	current_id = cue.id
	_current_cue = cue
	# Same assigned file under another context: preserve playback and ongoing fade.
	if cue.stream != null and cue.stream == current_source and _active >= 0 and voices[_active].playing:
		cue.configure_loop(voices[_active].stream)
		voices[_active].pitch_scale = cue.pitch_scale
		if not is_instance_valid(_fade) or not _fade.is_running(): _settle_gain()
		track_changed.emit(current_id,true)
		return false
	current_source = cue.stream
	if is_instance_valid(_fade): _fade.kill()
	_fade = create_tween().set_parallel(true)
	_fade.finished.connect(_settle_gain)
	if cue.stream == null:
		_active = -1
		for voice in voices:
			_fade.tween_property(voice,"volume_db",-80.0,fade_seconds)
		_fade.chain().tween_callback(_stop_all_voices)
		track_changed.emit(current_id,false)
		return true
	var old: int = _active
	var next: int = 0 if old != 0 else 1
	var voice: AudioStreamPlayer = voices[next]
	voice.stop()
	voice.stream = cue.playback_stream()
	voice.pitch_scale = cue.pitch_scale
	voice.volume_db = -80
	voice.play()
	play_count += 1
	_active = next
	_fade.tween_property(voice,"volume_db",cue.gain_db,fade_seconds)
	if old >= 0:
		_fade.tween_property(voices[old],"volume_db",-80.0,fade_seconds)
		_fade.chain().tween_callback(voices[old].stop)
	track_changed.emit(current_id,true)
	return true

func stop(fade: bool = true) -> void:
	current_id = &""
	current_source = null
	_active = -1
	if is_instance_valid(_fade): _fade.kill()
	if not fade:
		_stop_all_voices()
		return
	_fade = create_tween().set_parallel(true)
	for voice in voices: _fade.tween_property(voice,"volume_db",-80.0,fade_seconds)
	_fade.chain().tween_callback(_stop_all_voices)

func _stop_all_voices() -> void:
	for voice in voices: voice.stop()

func _settle_gain() -> void:
	if _active >= 0 and _current_cue != null: voices[_active].volume_db = _current_cue.gain_db
