extends RefCounted
func start(tree: SceneTree) -> void:
	for part in ["a","b","c","keyboard"]:
		FileAccess.open("res://tests/hotfix/final_new_progress.json",FileAccess.WRITE).store_string(JSON.stringify({"current":part}))
		var script: GDScript = ResourceLoader.load("res://tests/hotfix/"+part+"_checks.gd","",ResourceLoader.CACHE_MODE_IGNORE)
		var suite: RefCounted = script.new()
		await suite.start(tree)
	FileAccess.open("res://tests/hotfix/final_new_progress.json",FileAccess.WRITE).store_string(JSON.stringify({"current":"complete"}))
