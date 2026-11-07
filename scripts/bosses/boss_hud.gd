extends Control
@export var boss: CharacterBody3D
@onready var panel: Control = $Panel
@onready var bar: ProgressBar = $Panel/Rows/Health
@onready var title: Label = $Panel/Rows/Name
@onready var phase_label: Label = $Panel/Rows/Phase
@onready var victory_message: Label = $Victory

func _ready() -> void:
	boss.attributes.health_changed.connect(_on_health)
	boss.brain.encounter_started.connect(func() -> void: panel.visible = true)
	boss.brain.encounter_ended.connect(func(_reason: StringName) -> void: panel.visible = false)
	boss.brain.phase_changed.connect(_on_phase)
	boss.brain.state_changed.connect(_on_state)
	boss.brain.victory.connect(func() -> void:
		panel.visible = false
		victory_message.visible = true)
	panel.visible = boss.brain.encounter_active
	victory_message.visible = boss.boss_defeated_this_session
	title.text = boss.display_name
	_on_health(boss.attributes.current_health,boss.attributes.max_health)
	_on_phase(2 if boss.brain.phase_two else 1)

func _on_health(current: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = current

func _on_phase(phase: int) -> void:
	phase_label.text = "FASE %d" % phase
	if not boss.boss_defeated_this_session: victory_message.visible = false

func _on_state(_previous: int, current: int) -> void:
	if current == boss.brain.State.PHASE_TRANSITION:
		phase_label.text = "TRANSICIÓN A FASE 2"
