extends MarginContainer

const ActorAttributes = preload("res://scripts/systems/actor_attributes.gd")
@export var attributes: ActorAttributes

@onready var health_bar: ProgressBar = $Bars/HealthBar
@onready var stamina_bar: ProgressBar = $Bars/StaminaBar
@onready var health_label: Label = $Bars/HealthLabel
@onready var stamina_label: Label = $Bars/StaminaLabel


func _ready() -> void:
	if not is_instance_valid(attributes):
		return
	attributes.health_changed.connect(_on_health_changed)
	attributes.stamina_changed.connect(_on_stamina_changed)
	_on_health_changed(attributes.current_health, attributes.max_health)
	_on_stamina_changed(attributes.current_stamina, attributes.max_stamina)


func _on_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = "VIDA  %.0f / %.0f" % [current, maximum]


func _on_stamina_changed(current: float, maximum: float) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "STAMINA  %.0f / %.0f" % [current, maximum]
