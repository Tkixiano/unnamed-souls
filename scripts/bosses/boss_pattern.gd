extends Resource
@export var pattern_id: StringName
@export var attacks: Array[Resource] = []
@export var minimum_distance: float = 0.0
@export var maximum_distance: float = 3.0
@export var half_angle: float = 65.0
@export var cooldown: float = 3.0
@export var phase_one_weight: float = 1.0
@export var phase_two_weight: float = 1.0

func is_valid() -> bool:
	if pattern_id.is_empty() or attacks.is_empty(): return false
	for value in [minimum_distance,maximum_distance,half_angle,cooldown,phase_one_weight,phase_two_weight]:
		if not is_finite(value) or value < 0.0: return false
	if maximum_distance < minimum_distance: return false
	for attack in attacks:
		if not is_instance_valid(attack) or not attack.has_method("snapshot") or attack.snapshot().is_empty(): return false
	return true
