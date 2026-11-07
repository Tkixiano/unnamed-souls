extends MarginContainer
@export var estus: Node
@onready var charges_label: Label = $Row/Charges

func _ready() -> void:
	if is_instance_valid(estus):
		estus.charges_changed.connect(_update_charges)
		_update_charges(estus.current_charges,estus.initial_charges)

func _update_charges(current: int, capacity: int) -> void:
	charges_label.text = "ESTUS  %d / %d" % [current,capacity]
