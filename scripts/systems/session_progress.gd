extends RefCounted
## Session-only progress survives scene changes; a new game process starts empty.
static func boss_is_defeated(tree: SceneTree, boss_id: StringName) -> bool:
	var defeated: Dictionary = tree.root.get_meta(&"defeated_bosses", {})
	return defeated.has(boss_id)

static func mark_boss_defeated(tree: SceneTree, boss_id: StringName) -> void:
	var defeated: Dictionary = tree.root.get_meta(&"defeated_bosses", {})
	defeated[boss_id] = true
	tree.root.set_meta(&"defeated_bosses", defeated)

static func reset_session(tree: SceneTree) -> void:
	# Only gameplay progress; preferences and MCP/test metadata are independent.
	for key in [&"defeated_bosses", &"tutorial_progress"]:
		if tree.root.has_meta(key): tree.root.remove_meta(key)
