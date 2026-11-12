extends CanvasLayer
## Presentation/lifecycle adapter. CheckpointManager still owns death/respawn.
const Progress = preload("res://scripts/systems/session_progress.gd")
const Options = preload("res://scripts/systems/game_options.gd")
const MAIN_MENU = "res://scenes/ui/main_menu.tscn"
const LEVEL = "res://scenes/levels/main_level.tscn"
enum Screen { NONE, PAUSE, OPTIONS, CONFIRM_RESTART, VICTORY, TRANSITION }
var screen: Screen = Screen.NONE
var options: RefCounted = Options.new()
## Debug mechanical suites may isolate the automatic victory overlay explicitly.
var automatic_victory_screen: bool = true
var _options_origin: Screen = Screen.NONE
var _return_focus: Control
var _resume_pending: bool = false
var _transitioning: bool = false
var _confirm_held: bool = false
var _stick_latched: bool = false
var _choice_frame: int = -1
var _bound_scene: Node
@onready var overlay: Control = $Overlay
@onready var menu: Control = $Overlay/MenuScreen
@onready var options_panel: Control = $Overlay/OptionsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	options.initialize()
	options.changed.connect(_apply_camera)
	menu.chosen.connect(handle_choice)
	options_panel.back_requested.connect(close_options)
	get_tree().scene_changed.connect(_on_scene_changed)
	_on_scene_changed.call_deferred()

func _on_scene_changed() -> void:
	var scene: Node = get_tree().current_scene
	if scene == _bound_scene or scene == null: return
	_bound_scene = scene
	_apply_camera()
	var boss: Node = scene.get_node_or_null("Boss")
	if is_instance_valid(boss): boss.brain.victory.connect(_on_victory)
	if not _transitioning:
		get_tree().paused = false
		screen = Screen.NONE
		overlay.hide()
	if scene.scene_file_path == MAIN_MENU:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		scene.focus_initial.call_deferred()

func _apply_camera() -> void:
	var scene: Node = get_tree().current_scene
	if is_instance_valid(scene): options.apply_camera(scene.get_node_or_null("CameraRig"))

func active_view() -> Control:
	if screen == Screen.OPTIONS: return options_panel
	if screen in [Screen.PAUSE,Screen.CONFIRM_RESTART,Screen.VICTORY]: return menu
	var scene: Node = get_tree().current_scene
	return scene if is_instance_valid(scene) and scene.scene_file_path == MAIN_MENU else null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen") and not event.is_echo():
		options.set_value("fullscreen",not options.values.fullscreen)
		options.save_preferences()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause_game") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if screen == Screen.PAUSE: request_resume()
		elif screen == Screen.OPTIONS: close_options()
		elif screen == Screen.CONFIRM_RESTART: show_pause(&"restart")
		elif screen == Screen.NONE and active_view() == null: open_pause()
		return
	var view: Control = active_view()
	if view == null: return
	# Own semantic UI input once; native GUI must not confirm it a second time.
	if event.is_action("menu_confirm") or event.is_action("ui_accept"):
		if event.is_action_released("menu_confirm") or event.is_action_released("ui_accept"): _confirm_held = false
		elif not event.is_echo() and not _confirm_held:
			_confirm_held = true
			activate_focused()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("menu_cancel") and not event.is_echo():
		cancel()
		get_viewport().set_input_as_handled()
	elif not event is InputEventJoypadMotion:
		for action in ["ui_up","ui_down","ui_left","ui_right"]:
			if event.is_action_pressed(action):
				if not event.is_echo():
					if action == "ui_up": move_focus(-1)
					elif action == "ui_down": move_focus(1)
					else: adjust_focused(-1 if action == "ui_left" else 1)
				get_viewport().set_input_as_handled()
				break
	else:
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if not Input.is_action_pressed("menu_confirm") and not Input.is_action_pressed("ui_accept"): _confirm_held = false
	if _resume_pending and not _menu_buttons_held(): _finish_resume.call_deferred()
	if active_view() == null: return
	var axis: Vector2 = Input.get_vector("move_left","move_right","move_forward","move_backward",0.25)
	if axis.length() < 0.25: _stick_latched = false
	if _stick_latched or axis.length() < 0.6: return
	_stick_latched = true
	if absf(axis.y) >= absf(axis.x): move_focus(1 if axis.y > 0 else -1)
	else: adjust_focused(1 if axis.x > 0 else -1)

func move_focus(direction: int) -> void:
	var view: Control = active_view()
	if view == null or view.focusables.is_empty(): return
	var index: int = view.focusables.find(get_viewport().gui_get_focus_owner())
	view.focusables[posmod(index+direction,view.focusables.size())].grab_focus()

func adjust_focused(direction: int) -> void:
	var control: Control = get_viewport().gui_get_focus_owner()
	if control is HSlider: control.value += direction*control.step
	elif control is CheckBox: control.button_pressed = not control.button_pressed

func activate_focused() -> void:
	var control: Control = get_viewport().gui_get_focus_owner()
	if control is CheckBox: control.button_pressed = not control.button_pressed
	elif control is Button: control.pressed.emit()

func handle_choice(choice: StringName) -> void:
	if _transitioning or _choice_frame == Engine.get_process_frames(): return
	_choice_frame = Engine.get_process_frames()
	match choice:
		&"new_game", &"restart_yes": new_game.call_deferred()
		&"quit": get_tree().quit()
		&"resume": request_resume()
		&"restart": show_restart_confirmation()
		&"restart_no": show_pause(&"restart")
		&"options": open_options()
		&"main": return_to_main.call_deferred()

func open_pause() -> void:
	if _transitioning or screen != Screen.NONE: return
	var scene: Node = get_tree().current_scene
	if scene == null or not scene.has_node("Player"): return
	get_tree().paused = true
	show_pause()

func show_pause(focus_choice: StringName = &"resume") -> void:
	screen = Screen.PAUSE
	overlay.show()
	options_panel.hide()
	menu.show()
	menu.configure("PAUSA",[[&"resume","Continuar"],[&"restart","Reiniciar partida"],[&"options","Opciones"],[&"main","Menú principal"]],"La simulación está detenida")
	menu.focus_initial()
	for button in menu.focusables:
		if StringName(button.name) == focus_choice: button.grab_focus()

func show_restart_confirmation() -> void:
	screen = Screen.CONFIRM_RESTART
	menu.configure("¿REINICIAR?",[[&"restart_no","Cancelar"],[&"restart_yes","Sí, nueva partida"]],"Se perderá el progreso de esta sesión. Las opciones se conservan.")
	menu.focus_initial()

func request_resume() -> void:
	if screen != Screen.PAUSE: return
	_resume_pending = true
	# Keep every actor frozen until the UI confirmation/cancel/pause is released.
	# This avoids turning the same B/A press into a roll/interaction after resume.
	if not _menu_buttons_held(): _finish_resume.call_deferred()
	else: menu.message.text = "Soltá Confirmar / Cancelar / Menú para continuar."

func _menu_buttons_held() -> bool:
	return Input.is_action_pressed("menu_confirm") or Input.is_action_pressed("ui_accept") or Input.is_action_pressed("menu_cancel") or Input.is_action_pressed("pause_game")

func _finish_resume() -> void:
	if not _resume_pending: return
	_resume_pending = false
	screen = Screen.NONE
	overlay.hide()
	get_tree().paused = false

func open_options() -> void:
	_options_origin = screen
	_return_focus = get_viewport().gui_get_focus_owner()
	screen = Screen.OPTIONS
	overlay.show()
	menu.hide()
	options_panel.show()
	options_panel.bind_options(options)
	options_panel.refresh()
	options_panel.focus_initial()

func close_options() -> void:
	if screen != Screen.OPTIONS: return
	var error: int = options.save_preferences()
	if error != OK: options_panel.status.text = "No se pudieron guardar preferencias (error %d)." % error
	screen = _options_origin
	options_panel.hide()
	if screen == Screen.NONE: overlay.hide()
	else: menu.show()
	if is_instance_valid(_return_focus): _return_focus.grab_focus()

func cancel() -> void:
	match screen:
		Screen.OPTIONS: close_options()
		Screen.CONFIRM_RESTART: show_pause(&"restart")
		Screen.PAUSE: request_resume()

func new_game() -> void:
	if _transitioning: return
	_transitioning = true
	_resume_pending = false
	screen = Screen.TRANSITION
	overlay.hide()
	get_tree().paused = true
	Progress.reset_session(get_tree())
	var error: int = get_tree().change_scene_to_file(LEVEL)
	if error != OK:
		_transitioning = false
		get_tree().paused = false
		push_error("No se pudo abrir el nivel: %d" % error)
		return
	await get_tree().scene_changed
	var scene: Node = get_tree().current_scene
	scene.get_node("CheckpointManager").establish_initial_checkpoint()
	scene.get_node("Player").checkpoint_input_blocked = true
	_apply_camera()
	# No gameplay frame elapses while a UI confirm button is still held.
	while _menu_buttons_held(): await get_tree().process_frame
	_transitioning = false
	screen = Screen.NONE
	get_tree().paused = false

func return_to_main() -> void:
	if _transitioning: return
	_transitioning = true
	_resume_pending = false
	overlay.hide()
	screen = Screen.TRANSITION
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU)
	await get_tree().scene_changed
	_transitioning = false
	screen = Screen.NONE
	get_tree().current_scene.focus_initial()

func _on_victory() -> void:
	if not automatic_victory_screen: return
	show_victory.call_deferred()

func show_victory() -> void:
	if _transitioning: return
	_resume_pending = false
	screen = Screen.VICTORY
	get_tree().paused = true
	overlay.show()
	options_panel.hide()
	menu.show()
	menu.configure("VICTORIA",[[&"new_game","Nueva partida"],[&"main","Menú principal"]],"El Guardián de las Ruinas ha caído. Gracias por jugar.")
	menu.focus_initial()
