extends Resource
## Derives a fresh snapshot; never mutates the one-handed source resource.
@export var source: Resource
@export var attack_name: StringName = &"TWO_HAND_LIGHT_1"
@export_range(0.1,4.0,0.05) var damage_multiplier: float = 1.35
@export_range(0.1,4.0,0.05) var stamina_multiplier: float = 1.2
@export_range(0.5,2.0,0.05) var startup_multiplier: float = 1.0
@export_range(0.5,2.0,0.05) var recovery_multiplier: float = 1.0

func snapshot() -> Dictionary:
	if not is_instance_valid(source) or not source.has_method("snapshot"):
		return {}
	for value in [damage_multiplier,stamina_multiplier,startup_multiplier,recovery_multiplier]:
		if not is_finite(value) or value <= 0.0:
			return {}
	var data: Dictionary = source.snapshot().duplicate()
	if data.is_empty():
		return {}
	data.name = attack_name
	data.damage *= damage_multiplier
	data.cost *= stamina_multiplier
	data.stamina_damage *= damage_multiplier
	data.startup *= startup_multiplier
	data.recovery *= recovery_multiplier
	data.total = data.startup+data.active+data.recovery
	if data.combo_close > data.total:
		return {}
	return data
