extends Node
## Resource bookkeeping only. No attacks, enemy damage sources or inventory.

signal health_changed(current: float, maximum: float)
signal stamina_changed(current: float, maximum: float)
signal died
signal fully_restored

@export_group("Máximos")
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0:
	set(value):
		if not is_finite(value):
			return
		max_health = maxf(value, 1.0)
		if is_node_ready():
			_health = minf(_health, max_health)
			health_changed.emit(_health, max_health)
@export_range(1.0, 10000.0, 1.0) var max_stamina: float = 100.0:
	set(value):
		if not is_finite(value):
			return
		max_stamina = maxf(value, 1.0)
		if is_node_ready():
			_stamina = minf(_stamina, max_stamina)
			stamina_changed.emit(_stamina, max_stamina)

@export_group("Regeneración")
@export_range(0.0, 100.0, 0.5) var stamina_regeneration: float = 25.0
@export_range(0.0, 5.0, 0.05, "suffix:s") var regeneration_delay: float = 0.75

var current_health: float:
	get:
		return _health
var current_stamina: float:
	get:
		return _stamina

var _health: float = 100.0
var _stamina: float = 100.0
var _delay_remaining: float = 0.0
var _consumed_since_tick: bool = false
var _regeneration_blocks: Dictionary = {}
var _regeneration_multipliers: Dictionary = {}


func _ready() -> void:
	restore_all()


func _physics_process(delta: float) -> void:
	advance_regeneration(delta)


func has_stamina(amount: float) -> bool:
	return _valid_amount(amount) and _health > 0.0 and _stamina >= amount


func consume_stamina(amount: float) -> bool:
	if not has_stamina(amount):
		return false
	if amount == 0.0:
		return true
	_set_stamina(_stamina - amount)
	_delay_remaining = maxf(regeneration_delay, 0.0)
	_consumed_since_tick = true
	return true


func restore_stamina(amount: float) -> float:
	if not _valid_amount(amount):
		return 0.0
	var previous := _stamina
	_set_stamina(_stamina + minf(amount, max_stamina))
	return _stamina - previous


func apply_damage(amount: float) -> float:
	if not _valid_amount(amount) or _health <= 0.0:
		return 0.0
	var previous := _health
	_health = maxf(_health - minf(amount, max_health), 0.0)
	if previous != _health:
		health_changed.emit(_health, max_health)
		if _health == 0.0:
			died.emit()
	return previous - _health


func restore_health(amount: float) -> float:
	# Normal healing never revives. restore_all is the explicit reset path.
	if not _valid_amount(amount) or _health <= 0.0:
		return 0.0
	var previous := _health
	_health = minf(_health + minf(amount, max_health), max_health)
	if previous != _health:
		health_changed.emit(_health, max_health)
	return _health - previous


func restore_all() -> void:
	_health = max_health
	_stamina = max_stamina
	_delay_remaining = 0.0
	_consumed_since_tick = false
	_regeneration_blocks.clear()
	_regeneration_multipliers.clear()
	health_changed.emit(_health, max_health)
	stamina_changed.emit(_stamina, max_stamina)
	fully_restored.emit()


func set_regeneration_blocked(reason: StringName, blocked: bool) -> void:
	if blocked:
		_regeneration_blocks[reason] = true
	else:
		_regeneration_blocks.erase(reason)


func is_regeneration_blocked() -> bool:
	return _health <= 0.0 or not _regeneration_blocks.is_empty() or get_regeneration_multiplier() <= 0.0


func set_regeneration_multiplier(reason: StringName, value: float) -> void:
	if is_finite(value):
		_regeneration_multipliers[reason] = clampf(value,0.0,1.0)


func clear_regeneration_multiplier(reason: StringName) -> void:
	_regeneration_multipliers.erase(reason)


func get_regeneration_multiplier() -> float:
	var result := 1.0
	for value in _regeneration_multipliers.values():
		result *= float(value)
	return result


func restart_stamina_regeneration_delay() -> void:
	_delay_remaining = maxf(regeneration_delay, 0.0)
	_consumed_since_tick = true


func advance_regeneration(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	if _consumed_since_tick:
		_consumed_since_tick = false
		return
	# Only the part of this tick after the delay can regenerate.
	var waiting := minf(_delay_remaining, delta)
	_delay_remaining -= waiting
	var available_time := delta - waiting
	if not is_regeneration_blocked() and available_time > 0.0:
		restore_stamina(maxf(stamina_regeneration, 0.0) * available_time * get_regeneration_multiplier())


func _set_stamina(value: float) -> void:
	var bounded := clampf(value, 0.0, max_stamina)
	if bounded != _stamina:
		_stamina = bounded
		stamina_changed.emit(_stamina, max_stamina)


func _valid_amount(amount: float) -> bool:
	return is_finite(amount) and amount >= 0.0
