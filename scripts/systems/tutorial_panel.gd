extends PanelContainer
@export var tutorial: Node
@export_range(0.05,1,0.05) var fade_seconds: float = 0.18
var _fade: Tween
func _ready() -> void:
	modulate.a = 0
	visible = false
	tutorial.instruction_changed.connect(_on_instruction)
	$Margin/Rows/Footer/Skip.pressed.connect(tutorial.skip_current)
	tutorial.call_deferred("refresh")
func _on_instruction(id: StringName, title: String, text: String, profile: String) -> void:
	if is_instance_valid(_fade): _fade.kill()
	if id.is_empty():
		_fade = create_tween()
		_fade.tween_property(self,"modulate:a",0.0,fade_seconds)
		_fade.tween_callback(hide)
		return
	$Margin/Rows/Title.text = title
	$Margin/Rows/Text.text = text
	$Margin/Rows/Footer/Device.text = {"keyboard":"Teclado / mouse", "xbox":"Distribución Xbox", "playstation":"Distribución PlayStation", "generic":"Mando: distribución desconocida"}.get(profile,"Mando")
	visible = true
	modulate.a = 0
	_fade = create_tween()
	_fade.tween_property(self,"modulate:a",1.0,fade_seconds)
