extends Resource
## Provisional seconds/metres, not frame-exact Dark Souls animation data.

@export var profile_name: StringName = &"FAST"
@export_range(0.1, 3.0, 0.01) var total_duration: float = 0.60
@export_range(0.05, 2.0, 0.01) var movement_duration: float = 0.30
@export_range(0.0, 6.0, 0.05) var distance: float = 3.0
@export_range(0.0, 2.0, 0.01) var invulnerability_start: float = 0.04
@export_range(0.0, 2.0, 0.01) var invulnerability_end: float = 0.30
@export_range(0.0, 2.0, 0.01) var recovery: float = 0.20


func snapshot() -> Dictionary:
	for value in [total_duration, movement_duration, distance, invulnerability_start, invulnerability_end, recovery]:
		if not is_finite(value):
			return {}
	if total_duration <= 0.0 or movement_duration <= 0.0 or distance < 0.0 or recovery < 0.0 \
		or movement_duration + recovery > total_duration + 0.00001 \
		or invulnerability_start < 0.0 or invulnerability_end < invulnerability_start \
		or invulnerability_end > total_duration - recovery + 0.00001:
		return {}
	return {"name": profile_name, "total": total_duration, "movement": movement_duration,
		"distance": distance, "iframes_start": invulnerability_start,
		"iframes_end": invulnerability_end, "recovery": recovery}
