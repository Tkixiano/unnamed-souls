extends Resource
## Null streams are intentionally silent; no deferred replay when files arrive.
@export var id: StringName
@export var stream: AudioStream
@export_range(-60,6,0.5) var gain_db: float = -6.0
@export_range(0.5,2,0.01) var pitch_scale: float = 1.0
@export var loop: bool = false
@export var spatial: bool = true
@export var play_when_paused: bool = false
@export_range(1,128,1) var max_distance: float = 20.0
@export_range(0.1,20,0.1) var unit_size: float = 3.0

func playback_stream() -> AudioStream:
	if stream == null: return null
	# Per-player copies preserve original import resources and their loop settings.
	var copy: AudioStream = stream.duplicate()
	configure_loop(copy)
	return copy

func configure_loop(copy: AudioStream) -> void:
	if copy is AudioStreamWAV:
		copy.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		if loop:
			copy.loop_begin = 0
			copy.loop_end = int(copy.get_length()*copy.mix_rate)
	elif copy is AudioStreamOggVorbis or copy is AudioStreamMP3:
		copy.loop = loop
