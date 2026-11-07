extends Resource
## Seconds and provisional values, not verified DS1 animation/frame data.

@export var attack_name: StringName = &"LIGHT_1"
@export_range(0.01, 3.0, 0.01) var startup: float = 0.25
@export_range(0.01, 2.0, 0.01) var active: float = 0.15
@export_range(0.01, 3.0, 0.01) var recovery: float = 0.40
@export_range(0.0, 1000.0, 1.0) var damage: float = 20.0
@export_range(0.0, 100.0, 1.0) var stamina_cost: float = 18.0
@export_group("Propiedades defensivas explícitas")
@export var blockable: bool = false
@export var parryable: bool = false
@export var damage_type: StringName = &"physical"
@export_range(0.0, 1000.0, 1.0) var stamina_damage: float = 0.0
@export_group("Combo LIGHT_1")
@export_range(0.0, 3.0, 0.01) var combo_open: float = 0.40
@export_range(0.0, 3.0, 0.01) var combo_close: float = 0.72
@export_range(0.01, 2.0, 0.01) var buffer_lifetime: float = 0.50
@export_group("Orientación durante startup")
@export_range(0.0, 360.0, 1.0) var turn_speed: float = 100.0
@export_range(0.0, 90.0, 1.0) var correction_limit: float = 30.0
@export_group("Volumen opcional del golpe")
@export var hitbox_shape: Shape3D
@export var hitbox_offset: Vector3 = Vector3(0,1,-1.2)


func snapshot() -> Dictionary:
	for value in [startup,active,recovery,damage,stamina_cost,stamina_damage,combo_open,combo_close,buffer_lifetime,turn_speed,correction_limit]:
		if not is_finite(value) or value < 0.0:
			return {}
	if startup <= 0.0 or active <= 0.0 or recovery <= 0.0 or buffer_lifetime <= 0.0 \
		or combo_close < combo_open or combo_close > startup + active + recovery:
		return {}
	return {"name":attack_name,"startup":startup,"active":active,"recovery":recovery,
		"total":startup+active+recovery,"damage":damage,"cost":stamina_cost,
		"combo_open":combo_open,"combo_close":combo_close,"buffer_lifetime":buffer_lifetime,
		"turn_speed":turn_speed,"correction_limit":correction_limit,
		"blockable":blockable,"parryable":parryable,"damage_type":damage_type,"stamina_damage":stamina_damage,
		"hitbox_shape":hitbox_shape,"hitbox_offset":hitbox_offset}
