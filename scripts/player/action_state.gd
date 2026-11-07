extends Node
## Availability policy only. Placeholder states do not execute their mechanics.

enum State { FREE, ATTACKING, DODGING, BLOCKING, PARRYING, HEALING, STAGGERED, DEAD, SWITCHING_GRIP }

signal state_changed(previous: State, current: State)

var current_state: State:
	get:
		return _state
var _state: State = State.FREE
var _owner: Node


func can_transition_to(next_state: int) -> bool:
	if next_state < State.FREE or next_state > State.SWITCHING_GRIP or next_state == _state:
		return false
	if _state == State.DEAD:
		return false
	if is_instance_valid(_owner) and next_state != State.DEAD:
		return false
	# Busy states must complete to FREE; death may interrupt any state.
	return _state == State.FREE or next_state == State.FREE or next_state == State.DEAD


func transition_to(next_state: int) -> bool:
	if not can_transition_to(next_state):
		return false
	var previous := _state
	_owner = null
	_state = next_state as State
	state_changed.emit(previous, _state)
	return true


func can_move() -> bool:
	return _state == State.FREE


func can_sprint() -> bool:
	return _state == State.FREE


func blocks_regeneration() -> bool:
	return _state != State.FREE


func reset_to_free() -> void:
	# Explicit reset, never a normal gameplay transition out of DEAD.
	_owner = null
	if _state != State.FREE:
		var previous := _state
		_state = State.FREE
		state_changed.emit(previous, _state)


func claim_state(next_state: int, owner: Node) -> bool:
	if not is_instance_valid(owner) or next_state == State.FREE or next_state == State.DEAD:
		return false
	if not can_transition_to(next_state):
		return false
	var previous := _state
	_owner = owner
	_state = next_state as State
	state_changed.emit(previous, _state)
	return _state == next_state and _owner == owner


func complete_owned_state(owner: Node) -> bool:
	if not is_instance_valid(owner) or owner != _owner:
		return false
	_owner = null
	return transition_to(State.FREE)
