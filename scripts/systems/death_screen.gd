extends Control
@export var manager: Node

func _ready() -> void:
	manager.death_visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed(manager.is_death_visible())

func _on_visibility_changed(value: bool) -> void:
	visible = value
