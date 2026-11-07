extends Node
const Actions = preload("res://scripts/player/action_state.gd")
enum Phase { NONE, PREPARATION, DRINKING, RECOVERY }
signal charges_changed(current: int, capacity: int)
signal phase_changed(phase: Phase)
signal used(healing_applied: float)
@export var player: CharacterBody3D
@export var flask: MeshInstance3D
@export var input_enabled: bool = true
@export_range(0,99) var initial_charges: int = 5
@export_range(0,1000,1) var healing_amount: float = 60.0
@export_range(0.0,3.0,0.01) var preparation: float = 0.45
@export_range(0.01,3.0,0.01) var use_time: float = 0.85
@export_range(0.1,5.0,0.01) var total_duration: float = 1.5
var current_charges: int = 0
var phase: Phase = Phase.NONE
var elapsed: float = 0.0
var _active: bool = false
var _consumed: bool = false
var _pending: bool = false
var _latched: bool = false
var _timing: Vector3
var _healing: float = 0.0

func initialize() -> void:
	player.action_states.state_changed.connect(_on_state_changed)
	player.attributes.fully_restored.connect(_reset)
	_reset()

func _input(event: InputEvent) -> void:
	if event.is_action("use_item") and not event.is_echo():
		var pressed := Input.is_action_pressed("use_item")
		if pressed and not _latched and input_enabled:
			_pending = true
		_latched = pressed

func process_request() -> void:
	if _pending:
		_pending = false
		try_use()

func try_use() -> bool:
	if not player.can_accept_action_input():
		return false
	if _active or current_charges <= 0 or player.attributes.current_health <= 0.0 \
		or player.attributes.current_health >= player.attributes.max_health or not player.is_on_floor() \
		or player.action_states.current_state != Actions.State.FREE:
		return false
	for value in [preparation,use_time,total_duration,healing_amount]:
		if not is_finite(value) or value < 0.0:
			return false
	if use_time < preparation or total_duration <= use_time:
		return false
	if not player.action_states.claim_state(Actions.State.HEALING,self):
		return false
	_timing = Vector3(preparation,use_time,total_duration)
	_healing = healing_amount
	_active = true
	_consumed = false
	elapsed = 0.0
	_set_phase(Phase.PREPARATION)
	flask.visible = true
	return true

func is_active() -> bool:
	return _active

func advance_clock(delta: float) -> void:
	if not _active:
		return
	elapsed += delta
	if not _consumed and elapsed + 0.0000001 >= _timing.y:
		# Latch and charge before signals, so callbacks cannot duplicate a drink.
		_consumed = true
		current_charges = maxi(current_charges-1,0)
		charges_changed.emit(current_charges,initial_charges)
		var restored: float = player.attributes.restore_health(_healing)
		used.emit(restored)
		if not _active:
			return
	if elapsed + 0.0000001 >= _timing.z:
		_cancel()
		player.attributes.restart_stamina_regeneration_delay()
		player.action_states.complete_owned_state(self)
	elif elapsed + 0.0000001 >= _timing.y:
		_set_phase(Phase.RECOVERY)
	elif elapsed + 0.0000001 >= _timing.x:
		_set_phase(Phase.DRINKING)

func interrupt_for_stagger() -> bool:
	# Explicit damage integration: ordinary hits do not all imply stagger.
	if not _active or player.action_states.current_state != Actions.State.HEALING:
		return false
	_cancel()
	if not player.action_states.complete_owned_state(self):
		return false
	return player.action_states.transition_to(Actions.State.STAGGERED)

func _cancel() -> void:
	_active = false
	_pending = false
	flask.visible = false
	_set_phase(Phase.NONE)

func _set_phase(value: Phase) -> void:
	if phase != value:
		phase = value
		phase_changed.emit(phase)

func _on_state_changed(_previous: int, current: int) -> void:
	if current != Actions.State.HEALING:
		_cancel()

func _reset() -> void:
	_cancel()
	current_charges = maxi(initial_charges,0)
	charges_changed.emit(current_charges,initial_charges)
