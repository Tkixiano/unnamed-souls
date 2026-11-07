extends Node
const Actions = preload("res://scripts/player/action_state.gd")
enum Mode { ONE_HANDED, TWO_HANDED }
signal mode_changed(mode: Mode)
signal switching_changed(active: bool)
@export var player: CharacterBody3D
@export var sword: MeshInstance3D
@export var lowered_shield: MeshInstance3D
@export var second_hand: MeshInstance3D
@export var input_enabled: bool = true
@export_range(0.1,1.5,0.01) var switch_duration: float = 0.4
@export_range(0.0,1.5,0.01) var commit_time: float = 0.2
@export var two_hand_light_1: Resource
@export var two_hand_light_2: Resource
@export var two_hand_heavy_1: Resource
@export_range(1,3,0.05) var critical_damage_multiplier: float = 1.2
var mode: Mode = Mode.ONE_HANDED
var elapsed: float = 0.0
var _active: bool = false
var _committed: bool = false
var _latched: bool = false
var _pending: bool = false

func initialize() -> void:
	player.action_states.state_changed.connect(_on_state_changed)
	player.attributes.fully_restored.connect(_reset)
	sync_visual()

func _input(event: InputEvent) -> void:
	if event.is_action("two_hand_toggle") and not event.is_echo():
		var pressed := Input.is_action_pressed("two_hand_toggle")
		if pressed and not _latched and input_enabled:
			_pending = true
		_latched = pressed

func process_request() -> void:
	if _pending:
		_pending = false
		try_toggle()

func try_toggle() -> bool:
	if not player.can_accept_action_input():
		return false
	if _active or not player.is_on_floor() or player.attributes.current_health <= 0.0 \
		or player.action_states.current_state not in [Actions.State.FREE,Actions.State.BLOCKING]:
		return false
	if player.defense_controller.is_blocking():
		player.defense_controller.release_for_grip()
	if not player.action_states.claim_state(Actions.State.SWITCHING_GRIP,self):
		return false
	_active = true
	_committed = false
	elapsed = 0.0
	switching_changed.emit(true)
	return true

func is_switching() -> bool:
	return _active

func shield_available() -> bool:
	return mode == Mode.ONE_HANDED and not _active

func get_critical_multiplier() -> float:
	return critical_damage_multiplier if mode == Mode.TWO_HANDED else 1.0

func get_attack_profile(kind: int) -> Resource:
	if mode != Mode.TWO_HANDED or kind < 0 or kind > 2:
		return null
	return [two_hand_light_1,two_hand_light_2,two_hand_heavy_1][kind]

func advance_clock(delta: float) -> void:
	if not _active:
		return
	elapsed += delta
	if not _committed and elapsed + 0.0000001 >= clampf(commit_time,0.0,switch_duration):
		_committed = true
		mode = Mode.TWO_HANDED if mode == Mode.ONE_HANDED else Mode.ONE_HANDED
		mode_changed.emit(mode)
	if elapsed + 0.0000001 >= switch_duration:
		_cancel()
		player.action_states.complete_owned_state(self)

func sync_visual() -> void:
	sword.position = Vector3(0.0 if mode == Mode.TWO_HANDED else 0.45,1.0,-0.8)
	second_hand.visible = mode == Mode.TWO_HANDED and player.attributes.current_health > 0.0
	lowered_shield.visible = mode == Mode.ONE_HANDED and not _active and player.attributes.current_health > 0.0 \
		and player.defense_controller.mode == 0 and player.action_states.current_state == Actions.State.FREE

func _cancel() -> void:
	_active = false
	_pending = false
	switching_changed.emit(false)

func _on_state_changed(_previous: int, current: int) -> void:
	if current != Actions.State.SWITCHING_GRIP:
		_cancel()

func _reset() -> void:
	_cancel()
	mode = Mode.ONE_HANDED
	mode_changed.emit(mode)
	sync_visual()
