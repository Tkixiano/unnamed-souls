extends Control
signal chosen(id: StringName)
var focusables: Array[Control] = []
@onready var title: Label = $Center/Panel/Margin/Rows/Title
@onready var message: Label = $Center/Panel/Margin/Rows/Message
@onready var choices: VBoxContainer = $Center/Panel/Margin/Rows/Choices

func configure(caption: String, entries: Array, detail: String = "") -> void:
	title.text = caption
	message.text = detail
	message.visible = not detail.is_empty()
	for child in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	focusables.clear()
	for entry in entries:
		var button := Button.new()
		button.name = str(entry[0])
		button.text = entry[1]
		button.custom_minimum_size = Vector2(400,52)
		button.pressed.connect(func() -> void: chosen.emit(StringName(entry[0])))
		choices.add_child(button)
		focusables.append(button)

func focus_initial() -> void:
	if not focusables.is_empty(): focusables[0].grab_focus()
