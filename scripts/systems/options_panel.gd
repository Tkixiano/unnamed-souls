extends Control
signal back_requested
var focusables: Array[Control] = []
var settings: RefCounted
@onready var rows: VBoxContainer = $Center/Panel/Margin/Rows
@onready var status: Label = $Center/Panel/Margin/Rows/Status

func bind_options(options: RefCounted) -> void:
	settings = options
	if not focusables.is_empty():
		refresh()
		return
	for spec in [["master","Volumen general",0,100],["music","Música",0,100],["effects","Efectos",0,100],["ambient","Ambiente",0,100],["horizontal","Cámara horizontal (°/s)",10,360],["vertical","Cámara vertical (°/s)",10,360]]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = spec[1]
		label.custom_minimum_size.x = 350
		label.add_theme_font_size_override("font_size",20)
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = spec[0]
		slider.custom_minimum_size = Vector2(220,34)
		slider.min_value = spec[2]
		slider.max_value = spec[3]
		slider.step = 5
		slider.value = options.values[spec[0]]
		slider.focus_mode = Control.FOCUS_ALL
		row.add_child(slider)
		var value := Label.new()
		value.custom_minimum_size.x = 65
		value.text = str(int(slider.value))
		row.add_child(value)
		slider.value_changed.connect(func(number: float) -> void:
			settings.set_value(spec[0],number)
			value.text = str(int(number)))
		rows.add_child(row)
		focusables.append(slider)
	for spec in [["invert_y","Invertir cámara vertical"],["fullscreen","Pantalla completa"]]:
		var check := CheckBox.new()
		check.name = spec[0]
		check.text = spec[1]
		check.button_pressed = options.values[spec[0]]
		check.toggled.connect(func(active: bool) -> void: settings.set_value(spec[0],active))
		rows.add_child(check)
		focusables.append(check)
	var back := Button.new()
	back.name = "Back"
	back.text = "Volver"
	back.custom_minimum_size.y = 48
	back.pressed.connect(func() -> void: back_requested.emit())
	rows.add_child(back)
	focusables.append(back)
	rows.move_child(status,rows.get_child_count()-1)

func refresh() -> void:
	for control in focusables:
		var key: String = str(control.name)
		if control is HSlider:
			control.set_value_no_signal(settings.values[key])
			control.get_parent().get_child(2).text = str(int(control.value))
		elif control is CheckBox: control.set_pressed_no_signal(settings.values[key])
	status.text = "Izquierda/derecha: ajustar · Confirmar: marcar · Cancelar: volver"

func focus_initial() -> void:
	if not focusables.is_empty(): focusables[0].grab_focus()
