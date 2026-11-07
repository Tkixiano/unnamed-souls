extends RefCounted
## Interprets the shared button without consuming input events or executing dodges.
## Release is always reported, including a tap entirely between physics ticks.

signal released(held_seconds: float, was_long_press: bool)

var is_held: bool = false
var held_seconds: float = 0.0
var is_long_press: bool = false


func set_pressed(pressed: bool) -> void:
	if pressed == is_held:
		return
	if pressed:
		is_held = true
		held_seconds = 0.0
		is_long_press = false
	else:
		var duration := held_seconds
		var long_press := is_long_press
		cancel()
		released.emit(duration, long_press)


func advance(delta: float, hold_threshold: float) -> void:
	if is_held:
		held_seconds += delta
		is_long_press = is_long_press or held_seconds >= hold_threshold


func cancel() -> void:
	# Focus loss cancels the gesture rather than generating a future dodge.
	is_held = false
	held_seconds = 0.0
	is_long_press = false
