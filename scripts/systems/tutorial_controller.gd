extends Node
## Passive observer: never claims an action, changes health or gates the level.
const Hints = preload("res://scripts/systems/tutorial_input_hints.gd")
@export var player: CharacterBody3D
@export var camera_rig: Node3D
@export var lock_controller: Node
@export var checkpoints: Node
@export var boss: CharacterBody3D
@export var gate: Node3D
@export var catalog: Resource
@export var session_id: StringName = &"forest_intro_v1"
@export var enabled: bool = true
@export_range(0.2,10,0.1) var movement_required: float = 2.0
@export_range(1,90,1) var camera_degrees_required: float = 15.0
@export var target_radius: float = 8.0
signal instruction_changed(id: StringName, title: String, text: String, profile: String)
signal lesson_completed(id: StringName)
signal lesson_skipped(id: StringName)
var completed: Dictionary = {}
var skipped: Dictionary = {}
var current_id: StringName = &""
var profile: String = "keyboard"
var active_device: int = -1
var _distance: float = 0
var _camera_travel: float = 0
var _last_position: Vector3
var _last_angles: Vector2
var _view_key: String = ""

func _ready() -> void:
	var progress: Dictionary = get_tree().root.get_meta(&"tutorial_progress",{})
	var saved: Dictionary = progress.get(session_id,{})
	completed = saved.get("completed",{}).duplicate()
	skipped = saved.get("skipped",{}).duplicate()
	_last_position = player.global_position
	_last_angles = camera_rig.get_orbit_angles()
	player.attack_controller.attack_started.connect(_on_attack)
	player.defense_controller.defense_event.connect(_on_defense)
	player.dodge_controller.dodge_started.connect(_on_dodge)
	player.estus_controller.used.connect(_on_estus)
	lock_controller.target_changed.connect(_on_target)
	checkpoints.checkpoint_activated.connect(_on_checkpoint)
	checkpoints.respawned.connect(_on_respawn)
	boss.brain.encounter_started.connect(_on_encounter)
	get_node("/root/ControllerRegistry").devices_changed.connect(_on_devices_changed)
	var devices: Array = Input.get_connected_joypads()
	if not devices.is_empty():
		active_device = devices[0]
		profile = Hints.profile_for_id(active_device)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8: skip_current()
		profile = "keyboard"
		active_device = -1
	elif event is InputEventMouseButton and event.pressed or event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT and event.relative.length() > 2:
		profile = "keyboard"
		active_device = -1
	elif event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > 0.3:
		active_device = event.device
		profile = Hints.profile_for_id(active_device)

func _physics_process(_delta: float) -> void:
	var at: Vector3 = player.global_position
	var angles: Vector2 = camera_rig.get_orbit_angles()
	if player.attributes.current_health > 0 and checkpoints.phase == 0:
		var delta_position: Vector3 = at-_last_position
		delta_position.y = 0
		# Ignore snaps, dodge displacement and movement that had no locomotion input.
		if delta_position.length() < 0.5 and not player.movement_input.is_zero_approx() and not player.dodge_controller.is_active():
			_distance += delta_position.length()
		if _distance >= movement_required: observe(&"move")
		if camera_rig.control_mode == 0:
			_camera_travel += absf(angle_difference(_last_angles.x,angles.x))+absf(angles.y-_last_angles.y)
		if _camera_travel >= deg_to_rad(camera_degrees_required): observe(&"camera")
	_last_position = at
	_last_angles = angles
	refresh()

func observe(event: StringName) -> void:
	if not enabled or player.attributes.current_health <= 0: return
	for lesson in catalog.lessons:
		if lesson.completion_event == event and not completed.has(lesson.id):
			completed[lesson.id] = true
			_save()
			lesson_completed.emit(lesson.id)

func skip_current() -> bool:
	for lesson in catalog.lessons:
		if lesson.id == current_id and lesson.skippable:
			skipped[lesson.id] = true
			_save()
			lesson_skipped.emit(lesson.id)
			refresh()
			return true
	return false

func is_completed(id: StringName) -> bool:
	return completed.has(id)

func is_skipped(id: StringName) -> bool:
	return skipped.has(id)

func _save() -> void:
	var progress: Dictionary = get_tree().root.get_meta(&"tutorial_progress",{})
	progress[session_id] = {"completed":completed.duplicate(),"skipped":skipped.duplicate()}
	get_tree().root.set_meta(&"tutorial_progress",progress)

func _context_valid(context: String) -> bool:
	match context:
		"always": return true
		"bonfire":
			for fire in get_tree().get_nodes_in_group("bonfires"):
				if fire.manager == checkpoints and fire.contains_player(player): return true
		"target", "combat":
			for target in get_tree().get_nodes_in_group("lockable_targets"):
				if not target.is_available() or target.global_position.distance_to(player.global_position) > target_radius: continue
				if context == "target" and lock_controller.can_acquire(target): return true
				if context == "combat" and lock_controller.has_line_of_sight(target): return true
		"wounded": return player.attributes.current_health < player.attributes.max_health and player.estus_controller.current_charges > 0
		"gate": return boss.attributes.current_health > 0 and player.global_position.distance_to(gate.global_position) < 12
	return false

func refresh() -> void:
	var chosen: Resource
	if enabled and player.attributes.current_health > 0 and checkpoints.phase == 0 and not boss.brain.encounter_active:
		for lesson in catalog.lessons:
			if not completed.has(lesson.id) and not skipped.has(lesson.id) and _context_valid(lesson.context):
				chosen = lesson
				break
	current_id = chosen.id if chosen != null else &""
	var title: String = chosen.title if chosen != null else ""
	var text: String = chosen.text.format(Hints.labels(profile)) if chosen != null else ""
	if current_id == &"block" and not player.grip_controller.shield_available(): text = "Escudo no disponible a dos manos. Volvé a una mano con {grip}; luego usá {block} mirando al rival.".format(Hints.labels(profile))
	var key: String = str(current_id)+profile+text
	if key != _view_key:
		_view_key = key
		instruction_changed.emit(current_id,title,text,profile)

func _on_attack(attack_name: StringName, _swing: int) -> void:
	if "HEAVY" in str(attack_name): observe(&"heavy")
	elif "LIGHT" in str(attack_name): observe(&"light")
func _on_defense(event: StringName) -> void:
	if event == &"shield_raised": observe(&"block")
func _on_dodge(_weight: StringName, _direction: Vector3, backstep: bool) -> void:
	if not backstep: observe(&"dodge")
func _on_estus(healed: float) -> void:
	if healed > 0: observe(&"estus")
func _on_target(target: Node3D) -> void:
	if is_instance_valid(target): observe(&"lock")
func _on_checkpoint(_id: StringName) -> void:
	observe(&"bonfire")
func _on_encounter() -> void:
	observe(&"entry")
	refresh()
func _on_respawn(_id: StringName) -> void:
	_last_position = player.global_position
	_last_angles = camera_rig.get_orbit_angles()
	refresh()
func _on_devices_changed() -> void:
	if active_device >= 0 and active_device not in Input.get_connected_joypads():
		profile = "keyboard"
		active_device = -1
	refresh()
