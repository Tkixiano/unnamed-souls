extends RefCounted
## Session-only progress survives scene changes; a new game process starts empty.
static func boss_is_defeated(tree: SceneTree, boss_id: StringName) -> bool:
	var defeated: Dictionary = tree.root.get_meta(&"defeated_bosses", {})
	return defeated.has(boss_id)

static func mark_boss_defeated(tree: SceneTree, boss_id: StringName) -> void:
	var defeated: Dictionary = tree.root.get_meta(&"defeated_bosses", {})
	defeated[boss_id] = true
	tree.root.set_meta(&"defeated_bosses", defeated)
