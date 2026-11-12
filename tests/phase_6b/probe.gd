extends Node
func _ready() -> void:
	var data := {"executable":OS.get_executable_path(),"resource_root":ProjectSettings.globalize_path("res://"),"features":{"editor":OS.has_feature("editor"),"debug":OS.has_feature("debug"),"release":OS.has_feature("release")},"main":ProjectSettings.get_setting("application/run/main_scene"),"mcp_helper":get_tree().root.has_node("_mcp_game_helper"),"game_scene_available":ResourceLoader.exists("res://scenes/levels/main_level.tscn"),"source_tests_available":FileAccess.file_exists("res://tests/aggro_checks.gd")}
	FileAccess.open("C:/JUEGOs 3D/soul-game/tests/phase_6b/release_probe.json",FileAccess.WRITE).store_string(JSON.stringify(data,"\t"))
	get_tree().quit()
