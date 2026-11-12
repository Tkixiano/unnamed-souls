extends Resource
const Cue = preload("res://scripts/audio/audio_cue.gd")
@export var cues: Array[Cue] = []
func find(id: StringName) -> Resource:
	for cue in cues:
		if cue != null and cue.id == id: return cue
	return null
func missing_ids() -> Array[StringName]:
	var missing: Array[StringName] = []
	for cue in cues:
		if cue != null and cue.stream == null: missing.append(cue.id)
	return missing
